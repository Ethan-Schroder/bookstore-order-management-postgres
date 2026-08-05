/*
Business logic implemented at the database layer: whenever an order is
placed or a payment is logged, these triggers keep book.sales and
customer.balance correct automatically, and keep an audit trail of order
activity. Keeping this logic in the database (rather than in application
code) means it holds no matter which client writes to the tables.
*/

SET SEARCH_PATH TO bookstore, public;

/*
log_bookOrder_function / log_bookOrder_trigger
-----------------------------------------------
Fires after every INSERT, UPDATE or DELETE on bookOrder and writes a
matching row to bookOrder_log, tagged with which operation occurred.
This is the single source of truth the sales and balance triggers below
read from.
*/
CREATE OR REPLACE FUNCTION log_bookOrder_function()
RETURNS TRIGGER AS $BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO bookOrder_log (bno, cno, orderTime, qty, action)
        VALUES (NEW.bno, NEW.cno, NEW.orderTime, NEW.qty, 'INSERT');
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO bookOrder_log (bno, cno, orderTime, qty, action)
        VALUES (NEW.bno, NEW.cno, NEW.orderTime, NEW.qty, 'UPDATE');
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO bookOrder_log (bno, cno, orderTime, qty, action)
        VALUES (OLD.bno, OLD.cno, CURRENT_TIMESTAMP, OLD.qty, 'DELETE');
    END IF;
    RETURN NEW;
END; $BODY$ LANGUAGE plpgsql;

CREATE TRIGGER log_bookOrders_trigger
AFTER INSERT OR UPDATE OR DELETE
ON bookOrder
FOR EACH ROW
EXECUTE FUNCTION log_bookOrder_function();

/*
sales_function / sales_trigger
-------------------------------
Fires after every INSERT on bookOrder. Reads the most recent insert from
bookOrder_log and adds its quantity onto book.sales, so the running sales
count never needs to be updated by hand.
*/
CREATE OR REPLACE FUNCTION sales_function()
RETURNS TRIGGER AS $BODY$
BEGIN
    CREATE TEMPORARY TABLE sales_temp AS
    SELECT book.bno, bookOrder_log.qty AS modified_sales
    FROM book, bookOrder_log
    WHERE book.bno = bookOrder_log.bno
      AND bookOrder_log.action = 'INSERT'
      AND bookOrder_log.bookOrder_logid = (SELECT MAX(bookOrder_log.bookOrder_logid) FROM bookOrder_log);

    UPDATE book SET sales = sales + sales_temp.modified_sales
    FROM sales_temp
    WHERE book.bno = sales_temp.bno;

    DROP TABLE sales_temp;
    RETURN NEW;
END; $BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER sales_trigger
AFTER INSERT ON bookOrder
EXECUTE PROCEDURE sales_function();

/*
balance_function / balance_trigger
------------------------------------
Fires after every INSERT on bookOrder. Works out what's owed for the new
order line (qty * current book price) and adds it to the customer's
balance.
*/
CREATE OR REPLACE FUNCTION balance_function()
RETURNS TRIGGER AS $BODY$
BEGIN
    CREATE TEMPORARY TABLE balance_temp AS
    SELECT bookOrder_log.cno, bookOrder_log.qty * book.price AS due
    FROM book, bookOrder_log
    WHERE book.bno = bookOrder_log.bno
      AND bookOrder_log.bookOrder_logid = (SELECT MAX(bookOrder_log.bookOrder_logid) FROM bookOrder_log)
      AND bookOrder_log.action = 'INSERT';

    UPDATE customer SET balance = balance + balance_temp.due
    FROM balance_temp
    WHERE customer.cno = balance_temp.cno;

    DROP TABLE balance_temp;
    RETURN NEW;
END; $BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER balance_trigger
AFTER INSERT ON bookOrder
EXECUTE PROCEDURE balance_function();

/*
payment_function
-----------------
Callable directly (SELECT payment_function(cno, amount)) to log a payment
against a customer's account. Validates that the customer exists before
logging anything. Deliberately has no trigger of its own — logging the
payment is what triggers update_balance_function below.
*/
CREATE OR REPLACE FUNCTION payment_function(IN INTEGER, IN DECIMAL(8, 2))
RETURNS VARCHAR AS $BODY$
DECLARE
    cno_value     INTEGER := $1;
    payment_value DECIMAL(8, 2) := $2;
BEGIN
    IF cno_value IN (SELECT cno FROM customer) THEN
        INSERT INTO payment_log (cno, amount, paymentTime)
        VALUES (cno_value, payment_value, CURRENT_TIMESTAMP);
        RETURN 'Successful payment';
    ELSE
        RAISE NOTICE 'Error: customer does not exist';
    END IF;
END;
$BODY$ LANGUAGE plpgsql;

/*
update_balance_function / payment_trigger
-------------------------------------------
Fires after every INSERT on payment_log (i.e. every time payment_function
successfully logs a payment) and subtracts the payment amount from the
customer's balance.

Like sales_trigger / balance_trigger, this is a statement-level trigger
that looks up the single most recent payment_log row rather than
referencing NEW directly (statement-level triggers don't have row
bindings). Without the payment_logID filter below, a customer with more
than one row in payment_log would have an arbitrary one of their past
payments re-subtracted on every new payment instead of the new one --
this matches the same one-insert-per-statement assumption documented in
the README's Known limitations section.
*/
CREATE OR REPLACE FUNCTION update_balance_function()
RETURNS TRIGGER AS $BODY$
BEGIN
    UPDATE customer SET balance = balance - payment_log.amount
    FROM payment_log
    WHERE customer.cno = payment_log.cno
      AND payment_log.payment_logID = (SELECT MAX(payment_logID) FROM payment_log);
    RETURN NEW;
END; $BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER payment_trigger
AFTER INSERT ON payment_log
EXECUTE PROCEDURE update_balance_function();

/*
Housekeeping: clear out order lines more than a month old. This is a
one-off maintenance statement rather than a trigger — in a production
setup it would be scheduled (e.g. via pg_cron or pgAgent) to run monthly
instead of being run by hand.
*/
DELETE FROM bookOrder
WHERE EXTRACT(MONTH FROM orderTime) < EXTRACT(MONTH FROM CURRENT_TIMESTAMP)
  AND EXTRACT(YEAR FROM orderTime) <= EXTRACT(YEAR FROM CURRENT_TIMESTAMP);
