/*
Schema and table definitions for the bookstore order management database.

The schema keeps all objects for this project namespaced away from other
work on the same Postgres instance.
*/

DROP SCHEMA IF EXISTS bookstore CASCADE;
CREATE SCHEMA bookstore;
SET SEARCH_PATH TO bookstore, public;

/*
book
----
Holds catalogue data for each book, plus a running count of copies sold.

- bno is the primary key and is constrained to a fixed 6-digit range so IDs
  are predictable and easy to generate for testing.
- category is restricted to a fixed set of values so downstream reports
  (see 03_views.sql) can group on it safely.
- price defaults are not set on purpose: every book must be entered with a
  real price.
- sales defaults to 0 and is maintained automatically by sales_trigger
  (see 02_functions_and_triggers.sql) whenever an order is placed.
*/
CREATE TABLE book (
    bno      INTEGER CHECK (bno >= 100000 AND bno <= 999999) PRIMARY KEY,
    title    VARCHAR(100) NOT NULL,
    author   VARCHAR(60) NOT NULL,
    category CHAR(10) NOT NULL CHECK (category IN ('Science', 'Lifestyle', 'Arts', 'Leisure')),
    price    DECIMAL(6, 2) NOT NULL,
    sales    INTEGER DEFAULT 0
);

/*
customer
--------
Holds customer contact details and their running account balance.

- cno is the primary key, constrained to the same 6-digit range as bno so
  the two ID spaces are easy to tell apart in sample data (customers use
  the 900000+ range in 04_sample_data.sql, books use 100000+).
- balance defaults to 0 and is maintained automatically by balance_trigger
  and payment_trigger whenever an order is placed or a payment is logged.
*/
CREATE TABLE customer (
    cno     INTEGER CHECK (cno >= 100000 AND cno <= 999999) PRIMARY KEY,
    name    VARCHAR(60) NOT NULL,
    address VARCHAR(80) NOT NULL,
    balance DECIMAL(8, 2) DEFAULT 0
);

/*
bookOrder
---------
Holds one row per order line: a customer, a book, when it was ordered and
how many copies. Foreign keys cascade on delete/update so removing a book
or customer cleans up their order history rather than leaving orphan rows.
*/
CREATE TABLE bookOrder (
    cno       INTEGER NOT NULL,
    bno       INTEGER NOT NULL,
    orderTime TIMESTAMP,
    qty       INTEGER NOT NULL CHECK (qty >= 1),
    FOREIGN KEY (cno) REFERENCES customer (cno) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (bno) REFERENCES book (bno) ON DELETE CASCADE ON UPDATE CASCADE
);

/*
bookOrder_log
-------------
Append-only audit trail of every INSERT / UPDATE / DELETE made against
bookOrder, populated by log_bookOrder_trigger. This is what sales_trigger
and balance_trigger read from to work out what just changed, rather than
re-deriving it from bookOrder directly.
*/
CREATE SEQUENCE bookOrder_logID_seq;
CREATE TABLE bookOrder_log (
    bookOrder_logID INTEGER DEFAULT nextval('bookOrder_logID_seq') PRIMARY KEY,
    cno             INTEGER NOT NULL,
    bno             INTEGER NOT NULL,
    orderTime       TIMESTAMP,
    qty             INTEGER NOT NULL CHECK (qty >= 1),
    action          VARCHAR
);

/*
payment_log
-----------
Append-only record of payments made against a customer's balance, created
by payment_function and consumed by payment_trigger to reduce the
customer's outstanding balance.
*/
CREATE SEQUENCE payment_logID_seq;
CREATE TABLE payment_log (
    payment_logID INTEGER DEFAULT nextval('payment_logID_seq') PRIMARY KEY,
    cno           INTEGER NOT NULL,
    amount        DECIMAL(8, 2),
    paymentTime   TIMESTAMP
);
