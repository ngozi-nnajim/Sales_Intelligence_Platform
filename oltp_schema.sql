-- Creating the independent tables first
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    CONSTRAINT uq_customer_name UNIQUE (customer_name)
);

CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    city        VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL,
    CONSTRAINT uq_city_state UNIQUE (city, state)
);

CREATE TABLE products (
    product_id   SERIAL PRIMARY KEY,
    category     VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    CONSTRAINT uq_category_sub UNIQUE (category, sub_category)
);

CREATE TABLE payment_methods (
    payment_id   SERIAL PRIMARY KEY,
    payment_mode VARCHAR(50) NOT NULL,
    CONSTRAINT uq_payment_mode UNIQUE (payment_mode)
);

-- Orders depends on customers, locations, payment_methods
CREATE TABLE orders (
    order_pk    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    VARCHAR(50)  NOT NULL,
    customer_id INT          NOT NULL REFERENCES customers(customer_id),
    order_date  DATE         NOT NULL,
    location_id INT          NOT NULL REFERENCES locations(location_id),
    payment_id  INT          NOT NULL REFERENCES payment_methods(payment_id),
    CONSTRAINT uq_order UNIQUE (order_id, customer_id, order_date)
);

-- Order items depends on orders and products
CREATE TABLE order_items (
    order_item_id INT            GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_pk      INT            NOT NULL REFERENCES orders(order_pk),
    product_id    INT            NOT NULL REFERENCES products(product_id),
    quantity      INT            NOT NULL CHECK (quantity > 0),
    amount        NUMERIC(12, 2) NOT NULL,
    profit        NUMERIC(12, 2) NOT NULL
);
