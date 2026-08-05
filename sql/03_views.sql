/*
Reporting views used by the Python client's search / report commands
(see python_client/db_client.py). Pulling these into named views keeps
the reporting queries reusable from psql directly, not just from the
application.
*/

SET SEARCH_PATH TO bookstore, public;

/*
current_orders
--------------
One row per order line, showing the book title and the customer who
ordered it. Used to answer "which customers currently have an order in
for a book matching this title fragment?" (see search_orders_by_title in
db_client.py).
*/
CREATE OR REPLACE VIEW current_orders AS
SELECT book.title, customer.name, customer.address
FROM book, customer, bookOrder
WHERE book.bno = bookOrder.bno
  AND bookOrder.cno = customer.cno;

/*
book_report
------------
Total copies sold and total sales value per book category. Sales value
uses the book's current price, so any historical price changes are not
reflected retroactively.
*/
CREATE OR REPLACE VIEW book_report AS
SELECT category,
       SUM(sales)       AS number_of_sales,
       SUM(sales*price) AS total_value
FROM book
GROUP BY category;

/*
customer_report
----------------
One row per customer with a running count of copies ordered across all
their orders (0 if they have never ordered), sorted by customer number.
*/
CREATE OR REPLACE VIEW customer_report AS
SELECT customer.cno,
       customer.name,
       CASE WHEN SUM(bookOrder.qty) IS NULL THEN 0 ELSE SUM(bookOrder.qty) END AS number_of_books
FROM bookOrder
RIGHT OUTER JOIN customer ON customer.cno = bookOrder.cno
GROUP BY customer.cno
ORDER BY customer.cno;

/*
customer_bookorders
--------------------
One row per order line showing which books a given customer has ordered,
sorted by book number. Used to answer "what has this customer ordered?"
(see customer_order_history in db_client.py).
*/
CREATE OR REPLACE VIEW customer_bookorders AS
SELECT customer.name, book.bno, book.title, book.author
FROM book, customer, bookOrder
WHERE customer.cno = bookOrder.cno
  AND book.bno = bookOrder.bno
ORDER BY book.bno;
