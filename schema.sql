-- Drop public schema
DROP SCHEMA IF EXISTS public CASCADE;

-- ============================================================
-- Create schemas if they do not already exist
-- ============================================================
CREATE SCHEMA IF NOT EXISTS oltp;
CREATE SCHEMA IF NOT EXISTS olap;

-- ============================================================
-- OLTP Tables
-- ============================================================

-- Creating the independent tables first
CREATE TABLE IF NOT EXISTS oltp.customers (
    customer_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    CONSTRAINT uq_customer_name UNIQUE (customer_name)
);

CREATE TABLE IF NOT EXISTS oltp.locations (
    location_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city        VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL,
    CONSTRAINT uq_city_state UNIQUE (city, state)
);

CREATE TABLE IF NOT EXISTS oltp.products (
    product_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category     VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    CONSTRAINT uq_category_sub UNIQUE (category, sub_category)
);

CREATE TABLE IF NOT EXISTS oltp.payment_methods (
    payment_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_mode VARCHAR(50) NOT NULL,
    CONSTRAINT uq_payment_mode UNIQUE (payment_mode)
);

-- Orders depends on customers, locations, payment_methods
CREATE TABLE IF NOT EXISTS oltp.orders (
    order_pk    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    VARCHAR(50) NOT NULL,
    customer_id INT         NOT NULL REFERENCES oltp.customers(customer_id),
    order_date  DATE        NOT NULL,
    location_id INT         NOT NULL REFERENCES oltp.locations(location_id),
    payment_id  INT         NOT NULL REFERENCES oltp.payment_methods(payment_id)
);

-- Order items depends on orders and products
CREATE TABLE IF NOT EXISTS oltp.order_items (
    order_item_id INT            GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_pk      INT            NOT NULL REFERENCES oltp.orders(order_pk),
    product_id    INT            NOT NULL REFERENCES oltp.products(product_id),
    quantity      INT            NOT NULL CHECK (quantity > 0),
    amount        NUMERIC(12, 2) NOT NULL,
    profit        NUMERIC(12, 2) NOT NULL
);

-- ============================================================
-- OLAP Tables
-- ============================================================

-- Dimension tables first
CREATE TABLE IF NOT EXISTS olap.dim_customer (
    customer_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    CONSTRAINT uq_dim_customer UNIQUE (customer_name)
);

CREATE TABLE IF NOT EXISTS olap.dim_location (
    location_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city        VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_location UNIQUE (city, state)
);

CREATE TABLE IF NOT EXISTS olap.dim_product (
    product_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category     VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_product UNIQUE (category, sub_category)
);

CREATE TABLE IF NOT EXISTS olap.dim_payment (
    payment_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_mode VARCHAR(50) NOT NULL,
    CONSTRAINT uq_dim_payment UNIQUE (payment_mode)
);

CREATE TABLE IF NOT EXISTS olap.dim_date (
    date_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_date  DATE       NOT NULL,
    year_month  VARCHAR(7) NOT NULL,
    month       SMALLINT   NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name  VARCHAR(9) NOT NULL,
    quarter     SMALLINT   NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    year        SMALLINT   NOT NULL,
    day_of_week SMALLINT   NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    is_weekend  BOOLEAN    NOT NULL,
    CONSTRAINT uq_dim_date UNIQUE (order_date)
);

-- Fact table last
CREATE TABLE IF NOT EXISTS olap.fact_order_items (
    order_item_id INT            GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   INT            NOT NULL REFERENCES olap.dim_customer(customer_id),
    location_id   INT            NOT NULL REFERENCES olap.dim_location(location_id),
    product_id    INT            NOT NULL REFERENCES olap.dim_product(product_id),
    payment_id    INT            NOT NULL REFERENCES olap.dim_payment(payment_id),
    date_id       INT            NOT NULL REFERENCES olap.dim_date(date_id),
    quantity      INT            NOT NULL CHECK (quantity > 0),
    amount        NUMERIC(12, 2) NOT NULL,
    profit        NUMERIC(12, 2) NOT NULL
);