"""
load_to_db.py
-------------
Loads cleaned CSV tables into PostgreSQL using a single database
with separate schemas for OLTP and OLAP.

Usage:
    python load_to_db.py
"""


import os
import logging
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError


# ___ Logging configuration ______________________________

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)


# ___ Database connections  ______________________________

load_dotenv()

DB_HOST     = os.getenv('DB_HOST')
DB_PORT     = os.getenv('DB_PORT')
DB_USER     = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME     = os.getenv('DB_NAME')

DB_URL = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}'


# ___ Table definitions  ______________________________

BASE_PATH = 'data'

# OLTP tables - independent tables first, dependent tables last
OLTP_TABLES = [
    ('oltp.customers',       f'{BASE_PATH}/oltp/customers.csv'),
    ('oltp.locations',       f'{BASE_PATH}/oltp/locations.csv'),
    ('oltp.products',        f'{BASE_PATH}/oltp/products.csv'),
    ('oltp.payment_methods', f'{BASE_PATH}/oltp/payment_methods.csv'),
    ('oltp.orders',          f'{BASE_PATH}/oltp/orders.csv'),
    ('oltp.order_items',     f'{BASE_PATH}/oltp/order_items.csv'),
]

# OLAP tables - dimension tables first, fact table last
OLAP_TABLES = [
    ('olap.dim_customer',     f'{BASE_PATH}/olap/dim_customer.csv'),
    ('olap.dim_location',     f'{BASE_PATH}/olap/dim_location.csv'),
    ('olap.dim_product',      f'{BASE_PATH}/olap/dim_product.csv'),
    ('olap.dim_payment',      f'{BASE_PATH}/olap/dim_payment.csv'),
    ('olap.dim_date',         f'{BASE_PATH}/olap/dim_date.csv'),
    ('olap.fact_order_items', f'{BASE_PATH}/olap/fact_order_items.csv'),
]


# ___ Identity columns  ______________________________
IDENTITY_COLS = {
    'customers':        'customer_id',
    'locations':        'location_id',
    'products':         'product_id',
    'payment_methods':  'payment_id',
    'orders':           'order_pk',
    'order_items':      'order_item_id',
    'dim_customer':     'customer_id',
    'dim_location':     'location_id',
    'dim_product':      'product_id',
    'dim_payment':      'payment_id',
    'dim_date':         'date_id',
    'fact_order_items': 'order_item_id',
}


# ___ Helper functions  ______________________________

# reading the CSV and applying type conversion
def read_csv(csv_path: str) -> pd.DataFrame:
    """
    Read a CSV file and apply necessary type conversions.
    """

    df = pd.read_csv(csv_path)

    # Parse date columns
    if 'order_date' in df.columns:
        df['order_date'] = pd.to_datetime(df['order_date'])

    # Parse boolean columns
    if 'is_weekend' in df.columns:
        df['is_weekend'] = df['is_weekend'].astype(bool)

    return df


# truncate a table to prevent data duplication in the event of multiple runs
def truncate_table(con, table_name: str) -> None:
    """
    Truncate a table and reset its identity counter.
    """

    con.execute(text(f'TRUNCATE TABLE {table_name} RESTART IDENTITY CASCADE'))
    log.info('Truncated %s', table_name)


# loading tables one at a time to ensure failure of one does not affect the others
def load_table(engine, table_name: str, csv_path: str) -> None:
    """
    Load a single CSV file into a database table.
    """
    
    df = read_csv(csv_path)

    schema = table_name.split('.')[0]
    table  = table_name.split('.')[-1]

    # Debug - print columns before drop
    log.info('Columns before drop: %s', df.columns.tolist())

    # Drop identity column before loading
    id_col = IDENTITY_COLS.get(table)
    log.info('Identity column to drop: %s', id_col)

    if id_col and id_col in df.columns:
        df = df.drop(columns=[id_col])
        log.info('Dropped identity column %s from %s', id_col, table_name)
    else:
        log.info('No identity column dropped for %s', table_name)

    # Debug - print columns after drop
    log.info('Columns after drop: %s', df.columns.tolist())

    with engine.begin() as con:
        truncate_table(con, table_name)

    df.to_sql(
        table,
        engine,
        schema=schema,
        if_exists='append',
        index=False,
        method='multi'
    )

    log.info('Loaded %d rows into %s', len(df), table_name)


# function to load a list of tables
# Loging the start and end of each loading phase to easily identify where a failure occurred.
def load_tables(engine, tables: list) -> None:
    """
    Load a list of tables in order.
    """
    for table_name, csv_path in tables:
        try:
            load_table(engine, table_name, csv_path)
        except SQLAlchemyError as e:
            # Loging the specific table that failed and re-raising the error 
            # so the calling function can handle it
            log.error('Failed to load %s: %s', table_name, e)
            raise


def verify_load(engine, tables: list) -> None:
    """
    Verify row counts after loading to confirm that the 
    data loaded correctly
    """
    log.info('Verifying row counts...')
    with engine.connect() as con:
        for table_name, _ in tables:
            result = con.execute(text(f'SELECT COUNT(*) FROM {table_name}'))
            count = result.scalar()
            log.info('%s: %d rows', table_name, count)


# ___ Entry point  ______________________________

def run() -> None:
    """
    Main function to load all OLTP and OLAP tables.

    Validating environment variables before attempting to connect 
    in order to get a clear error message if anything is missing.
    """
    # Validating environment variables
    missing = [var for var, val in {
        'DB_HOST':     DB_HOST,
        'DB_PORT':     DB_PORT,
        'DB_USER':     DB_USER,
        'DB_PASSWORD': DB_PASSWORD,
        'DB_NAME':     DB_NAME,
    }.items() if not val]

    if missing:
        raise ValueError(f'Missing environment variables: {", ".join(missing)}')

    engine = create_engine(DB_URL)
    log.info('Connected to database: %s', DB_NAME)

    try:
        log.info('Loading OLTP tables...')
        load_tables(engine, OLTP_TABLES)
        verify_load(engine, OLTP_TABLES)
        log.info('OLTP loading complete.')

        log.info('Loading OLAP tables...')
        load_tables(engine, OLAP_TABLES)
        verify_load(engine, OLAP_TABLES)
        log.info('OLAP loading complete.')

    except SQLAlchemyError as e:
        log.error('Loading failed: %s', e)
        raise

    finally:
        engine.dispose()
        log.info('Database connection closed.')


if __name__ == '__main__':
    run()