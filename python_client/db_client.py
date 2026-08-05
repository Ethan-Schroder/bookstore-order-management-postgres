"""
db_client.py

Data-access layer for the bookstore order management database, built
around a single class, BookstoreClient, that owns one open connection
and exposes one method per business transaction.

All SQL is parameterised -- no query is ever built by formatting user
input directly into a string -- so this module is safe to point at
untrusted input. Connection details are read from environment variables
(see .env.example) rather than being hardcoded, so credentials never end
up in source control.
"""

import os
import warnings

import pandas as pd
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# pandas warns that a raw psycopg2 connection isn't a SQLAlchemy connectable.
# It still works correctly (psycopg2 is a supported DBAPI2 driver) -- this
# just silences the noise so script output stays readable.
warnings.filterwarnings("ignore", message=".*only supports SQLAlchemy connectable.*")


class BookstoreClient(object):
    """Owns a single database connection and exposes one method per
    business transaction (insert/delete book, insert/delete customer,
    place an order, log a payment, and run the four reporting queries).

    Connection details are taken from the constructor arguments if
    given, otherwise from the DB_HOST / DB_PORT / DB_NAME / DB_USER /
    DB_PASSWORD environment variables. Supports the context manager
    protocol so the connection is always closed:

        with BookstoreClient() as db:
            db.insert_book(234567, "Python Crash Course", "Matthes E.", "Science", 24.22)
            print(db.book_sales_report())
    """

    SCHEMA = "bookstore"

    def __init__(self, host=None, port=None, dbname=None, user=None, password=None):
        self.host = host or os.environ.get("DB_HOST")
        self.port = port or os.environ.get("DB_PORT", "5432")
        self.dbname = dbname or os.environ.get("DB_NAME")
        self.user = user or os.environ.get("DB_USER")
        self.password = password or os.environ.get("DB_PASSWORD")

        required = {
            "DB_HOST": self.host,
            "DB_NAME": self.dbname,
            "DB_USER": self.user,
            "DB_PASSWORD": self.password,
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise RuntimeError(
                "Missing required connection value(s): %s. Copy .env.example "
                "to .env and fill in your own values, or pass them directly "
                "to BookstoreClient()." % ", ".join(missing)
            )

        self.conn = psycopg2.connect(
            host=self.host,
            port=self.port,
            dbname=self.dbname,
            user=self.user,
            password=self.password,
        )
        self.conn.autocommit = True
        self._set_search_path()

    # -- connection lifecycle -------------------------------------------

    def _set_search_path(self):
        with self.conn.cursor() as cur:
            cur.execute("SET SEARCH_PATH TO %s, public;" % self.SCHEMA)

    def close(self):
        """Close the underlying connection."""
        self.conn.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    # -- books --------------------------------------------------------------

    def insert_book(self, bno, title, author, category, price):
        """Insert a new book and return its row."""
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute(
                "INSERT INTO book (bno, title, author, category, price) VALUES (%s, %s, %s, %s, %s);",
                (bno, title, author, category, price),
            )
        return pd.read_sql_query("SELECT * FROM book WHERE bno = %s;", self.conn, params=(bno,))

    def delete_book(self, bno):
        """Delete a book by number and return the remaining catalogue."""
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute("DELETE FROM book WHERE bno = %s;", (bno,))
        return pd.read_sql_query("SELECT * FROM book;", self.conn)

    # -- customers ------------------------------------------------------------

    def insert_customer(self, cno, name, address):
        """Insert a new customer and return their row."""
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute(
                "INSERT INTO customer (cno, name, address) VALUES (%s, %s, %s);",
                (cno, name, address),
            )
        return pd.read_sql_query("SELECT * FROM customer WHERE cno = %s;", self.conn, params=(cno,))

    def delete_customer(self, cno):
        """Delete a customer by number and return the remaining customer list."""
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute("DELETE FROM customer WHERE cno = %s;", (cno,))
        return pd.read_sql_query("SELECT * FROM customer;", self.conn)

    # -- orders and payments ----------------------------------------------------

    def place_order(self, cno, bno, qty):
        """Place an order for a customer and return that order line.

        book.sales and customer.balance are updated automatically by the
        sales_trigger / balance_trigger triggers defined in
        sql/02_functions_and_triggers.sql -- this method does not touch
        them directly.
        """
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute(
                "INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (%s, %s, CURRENT_TIMESTAMP, %s);",
                (cno, bno, qty),
            )
        return pd.read_sql_query(
            "SELECT * FROM bookOrder WHERE cno = %s AND bno = %s;", self.conn, params=(cno, bno)
        )

    def make_payment(self, cno, amount):
        """Log a payment for a customer via payment_function.

        customer.balance is reduced automatically by payment_trigger.
        """
        with self.conn.cursor() as cur:
            self._set_search_path()
            cur.execute("SELECT payment_function(%s, %s);", (cno, amount))
            result = cur.fetchone()
        return result[0] if result else "No response from payment_function"

    # -- reports ------------------------------------------------------------

    def search_orders_by_title(self, title_fragment):
        """Find customers with a current order for a book whose title contains the given fragment."""
        self._set_search_path()
        query = "SELECT * FROM current_orders WHERE title LIKE %s ORDER BY title, name;"
        return pd.read_sql_query(query, self.conn, params=("%" + title_fragment + "%",))

    def customer_order_history(self, cno):
        """List the books a given customer has ordered."""
        self._set_search_path()
        query = (
            "SELECT customer_bookorders.* FROM customer, customer_bookorders "
            "WHERE customer_bookorders.name = customer.name AND customer.cno = %s;"
        )
        return pd.read_sql_query(query, self.conn, params=(cno,))

    def book_sales_report(self):
        """Total copies sold and total sales value per book category."""
        self._set_search_path()
        return pd.read_sql_query("SELECT * FROM book_report;", self.conn)

    def customer_summary_report(self):
        """Total number of books ordered per customer, in customer number order."""
        self._set_search_path()
        return pd.read_sql_query("SELECT * FROM customer_report;", self.conn)
