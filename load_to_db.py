"""
load_to_db.py
-------------
Loads cleaned CSV tables into PostgreSQL for both OLTP and OLAP databases.

Usage:
    python load_to_db.py
"""

import os
from dotenv import load_dotenv

import pandas as pd
from sqlalchemy import create_engine, text
import logging


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)


# Database connections

load_dotenv()

DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
OLTP_DB = os.getenv('OLTP_DB')
OLAP_DB = os.getenv('OLAP_DB')

OLTP_URL = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{OLTP_DB}'
OLAP_URL = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{OLAP_DB}'

# OLTP Loader Function

def load_oltp():
    engine = create_engine(OLTP_URL)
    log.info('Loading OLTP tables...')

    # Loading tables in dependency order
    tables = [
        ('customers',        'data/oltp/customers.csv'),
        ('locations',        'data/oltp/locations.csv'),
        ('products',         'data/oltp/products.csv'),
        ('payment_methods',  'data/oltp/payment_methods.csv'),
        ('orders',           'data/oltp/orders.csv'),
        ('order_items',      'data/oltp/order_items.csv'),
    ]

    for table_name, csv_path in tables:
        df = pd.read_csv(csv_path)

        # Parse date columns where needed
        if 'order_date' in df.columns:
            df['order_date'] = pd.to_datetime(df['order_date'])

        with engine.begin() as con:
            con.execute(text(f'TRUNCATE TABLE {table_name} RESTART IDENTITY CASCADE'))

        df.to_sql(table_name, engine, if_exists='append', index=False, method='multi')
        log.info('Loaded %d rows into %s', len(df), table_name)

    log.info('OLTP loading complete.')


# OLAP Loader Function

def load_olap():
    engine = create_engine(OLAP_URL)
    log.info('Loading OLAP tables...')

    # Loading dimension tables first, then fact table last
    tables = [
        ('dim_customer',     'data/olap/dim_customer.csv'),
        ('dim_location',     'data/olap/dim_location.csv'),
        ('dim_product',      'data/olap/dim_product.csv'),
        ('dim_payment',      'data/olap/dim_payment.csv'),
        ('dim_date',         'data/olap/dim_date.csv'),
        ('fact_order_items', 'data/olap/fact_order_items.csv'),
    ]

    for table_name, csv_path in tables:
        df = pd.read_csv(csv_path)

        # Parse date columns where needed
        if 'order_date' in df.columns:
            df['order_date'] = pd.to_datetime(df['order_date'])

        # Convert boolean column for dim_date
        if 'is_weekend' in df.columns:
            df['is_weekend'] = df['is_weekend'].astype(bool)

        with engine.begin() as con:
            con.execute(text(f'TRUNCATE TABLE {table_name} RESTART IDENTITY CASCADE'))

        df.to_sql(table_name, engine, if_exists='append', index=False, method='multi')
        log.info('Loaded %d rows into %s', len(df), table_name)

    log.info('OLAP loading complete.')


# Running the script

if __name__ == '__main__':
    load_oltp()
    load_olap()