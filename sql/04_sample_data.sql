/*
Sample seed data so the schema can be explored immediately after setup.
All names, addresses and balances below are fictional.
*/

SET SEARCH_PATH TO bookstore, public;

INSERT INTO book (bno, title, author, category, price) VALUES
    (100001, 'Lord of the Rings',   'JRR Tolkien',      'Leisure',  14.99),
    (100002, 'Pride and Prejudice', 'Jane Austen',      'Leisure',  12.99),
    (100003, 'His Dark Materials',  'Philip Pullman',   'Leisure',  10.99),
    (100004, 'Northern Lights',     'Philippa Gregory', 'Leisure',   7.99),
    (100005, 'To Kill a Mockingbird','Harper Lee',       'Leisure',  10.99),
    (100006, 'Advanced Biology',    'Phillip E. Pack',  'Science',  35.00),
    (100007, 'Guide to Everything', 'John R. Gribbin',  'Science',  40.00),
    (100008, 'Alpha and Omega',     'Charles Seife',     'Science', 17.99),
    (100009, 'Annals of the World', 'John A. McPhee',    'Science', 15.99),
    (100010, 'Purple Hearts',       'Nina Berman',       'Arts',    17.99),
    (100011, 'Design of Dissent',   'R Glaser',          'Arts',    19.99),
    (100012, 'Changing the Earth',  'Diana Bletter',     'Arts',    22.00),
    (100013, '59 Seconds',          'Richard Wiseman',   'Lifestyle', 14.99),
    (100014, 'Talk to Anyone',      'Leil Lowndes',      'Lifestyle', 12.99);

INSERT INTO customer (cno, name, address) VALUES
    (100001, 'Allan Brooke',     '1 The Meadows, Norwich, Norfolk'),
    (100002, 'Ralph Morston',    '12 Plain Drive, Lowestoft'),
    (100003, 'Marion Jones',     'The Cottage, Dunston'),
    (100004, 'James Olivier',    '5 Livingstone Square, Birmingham'),
    (100005, 'Moira Stewart',    '7 The Meadows, Manchester'),
    (100006, 'Jonathan Bircham', '20 Oxford Street, London'),
    (100007, 'Paula Newman',     '25 Mill Hill, London'),
    (100008, 'David Jones',      '11 St Georges, London'),
    (100009, 'Patricia Lewis',   '101 High Street, Glasgow'),
    (100010, 'Martha Bramley',   '12 Catton Grove, Norwich');

-- NOTE: one INSERT statement per order, deliberately. sales_trigger and
-- balance_trigger are STATEMENT-level triggers (see 02_functions_and_triggers.sql)
-- that look up the single most recent bookOrder_log row, so a multi-row
-- INSERT would only update book.sales / customer.balance for the last row
-- in that statement. This matches how the application actually places
-- orders (db_client.place_order issues one INSERT per order), but it does
-- mean bulk-loading orders needs one statement per row, not a batch VALUES
-- list. See the "Known limitations" section of the README.
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100001, 100007, '2024-03-04 13:00:03', 4);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100001, 100006, CURRENT_TIMESTAMP,     3);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100003, 100007, CURRENT_TIMESTAMP,     2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100008, 100005, CURRENT_TIMESTAMP,     2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100009, 100003, '2024-04-04 13:00:03', 3);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100010, 100007, '2024-04-08 12:00:03', 1);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100004, 100004, '2024-05-09 12:00:03', 10);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100007, 100010, '2024-04-09 16:00:03', 5);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100007, 100003, '2024-04-09 16:00:03', 5);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100006, 100005, '2024-04-09 16:00:03', 3);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100006, 100010, '2024-05-03 15:00:00', 4);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100006, 100002, '2024-06-03 11:00:00', 2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100003, 100002, '2024-08-03 11:00:00', 3);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100009, 100002, '2024-08-05 11:00:00', 2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100008, 100001, '2024-08-05 11:00:00', 2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100004, 100012, '2024-08-05 11:00:00', 2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100006, 100013, '2024-08-05 11:00:00', 1);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100009, 100001, '2024-08-05 11:00:00', 2);
INSERT INTO bookOrder (cno, bno, orderTime, qty) VALUES (100001, 100008, '2024-08-05 11:00:00', 2);

-- A couple of example payments so payment_log / balance updates are visible immediately.
SELECT payment_function(100001, 50.00);
SELECT payment_function(100007, 20.00);
