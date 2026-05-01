-- Dimension tables first
CREATE TABLE dim_customer (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    CONSTRAINT uq_customer_name UNIQUE (customer_name)
);

CREATE TABLE dim_location (
    location_id SERIAL PRIMARY KEY,
    city        VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL,
    CONSTRAINT uq_city_state UNIQUE (city, state)
);

CREATE TABLE dim_product (
    product_id   SERIAL PRIMARY KEY,
    category     VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    CONSTRAINT uq_category_sub UNIQUE (category, sub_category)
);

CREATE TABLE dim_payment (
    payment_id   SERIAL PRIMARY KEY,
    payment_mode VARCHAR(50) NOT NULL,
    CONSTRAINT uq_payment_mode UNIQUE (payment_mode)
);

CREATE TABLE dim_date (
    date_id     SERIAL PRIMARY KEY,
    order_date  DATE        NOT NULL,
    year_month  VARCHAR(7)  NOT NULL,
    month       SMALLINT    NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name  VARCHAR(9)  NOT NULL,
    quarter     SMALLINT    NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    year        SMALLINT    NOT NULL,
    day_of_week SMALLINT    NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    is_weekend  BOOLEAN     NOT NULL,
    CONSTRAINT uq_order_date UNIQUE (order_date)
);

-- Fact table last
CREATE TABLE fact_order_items (
    order_item_id SERIAL         PRIMARY KEY,
    customer_id   INT            NOT NULL REFERENCES dim_customer(customer_id),
    location_id   INT            NOT NULL REFERENCES dim_location(location_id),
    product_id    INT            NOT NULL REFERENCES dim_product(product_id),
    payment_id    INT            NOT NULL REFERENCES dim_payment(payment_id),
    date_id       INT            NOT NULL REFERENCES dim_date(date_id),
    quantity      INT            NOT NULL CHECK (quantity > 0),
    amount        NUMERIC(12, 2) NOT NULL,
    profit        NUMERIC(12, 2) NOT NULL
);
