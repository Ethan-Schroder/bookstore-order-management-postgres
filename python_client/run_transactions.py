"""
run_transactions.py

Reads a small transaction-script format (one command per line, fields
separated by '#') and runs each command against the database through a
BookstoreClient, writing a readable log of what happened to an output
file.

Command reference
------------------
A#bno#title#author#category#price   Insert a book
B#bno                               Delete a book
C#cno#name#address                  Insert a customer
D#cno                               Delete a customer
E#cno#bno#qty                       Place an order
F#cno#amount                        Log a payment
G#title_fragment                    Find current orders for books matching a title fragment
H#cno                                Show a customer's order history
I                                    Show the book sales report
J                                    Show the customer summary report
X                                    Stop processing

Usage:
    python run_transactions.py sample_transactions.txt output.txt
"""

import sys

from db_client import BookstoreClient


class TransactionRunner(object):
    """Parses the letter-coded transaction format and drives a BookstoreClient.

    Each command code is dispatched to a small handler method that
    converts the raw string fields to the right types and calls the
    matching BookstoreClient method. Results (DataFrames or plain
    strings) are collected into a text log written out by run().
    """

    def __init__(self, client):
        self.client = client
        self.log_lines = []
        self.handlers = {
            "A": self._insert_book,
            "B": self._delete_book,
            "C": self._insert_customer,
            "D": self._delete_customer,
            "E": self._place_order,
            "F": self._make_payment,
            "G": self._search_orders_by_title,
            "H": self._customer_order_history,
            "I": self._book_sales_report,
            "J": self._customer_summary_report,
        }

    def run(self, input_path, output_path):
        with open(input_path, "r") as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line:
                    continue

                code, fields = self._split_line(line)

                if code == "X":
                    self.log_lines.append("Exit program!")
                    break

                handler = self.handlers.get(code)
                if handler is None:
                    self._log(code, "Unrecognised command code: %r" % code)
                    continue

                try:
                    result = handler(fields)
                except Exception as exc:
                    result = "Error: %s" % exc

                self._log(code, result)

        with open(output_path, "w") as f:
            f.write("\n".join(self.log_lines))

        print("Wrote %d lines to %s" % (len(self.log_lines), output_path))

    # -- internals ------------------------------------------------------------

    @staticmethod
    def _split_line(line):
        code, _, rest = line.partition("#")
        fields = rest.split("#") if rest or "#" in line else []
        return code, fields

    def _log(self, code, result):
        self.log_lines.append("TASK %s" % code)
        if hasattr(result, "to_string"):
            self.log_lines.append(result.to_string())
        else:
            self.log_lines.append(str(result))
        self.log_lines.append("")

    # -- command handlers -------------------------------------------------------

    def _insert_book(self, fields):
        bno, title, author, category, price = fields
        return self.client.insert_book(int(bno), title, author, category, float(price))

    def _delete_book(self, fields):
        (bno,) = fields
        return self.client.delete_book(int(bno))

    def _insert_customer(self, fields):
        cno, name, address = fields
        return self.client.insert_customer(int(cno), name, address)

    def _delete_customer(self, fields):
        (cno,) = fields
        return self.client.delete_customer(int(cno))

    def _place_order(self, fields):
        cno, bno, qty = fields
        return self.client.place_order(int(cno), int(bno), int(qty))

    def _make_payment(self, fields):
        cno, amount = fields
        return self.client.make_payment(int(cno), float(amount))

    def _search_orders_by_title(self, fields):
        (title_fragment,) = fields
        return self.client.search_orders_by_title(title_fragment)

    def _customer_order_history(self, fields):
        (cno,) = fields
        return self.client.customer_order_history(int(cno))

    def _book_sales_report(self, fields):
        return self.client.book_sales_report()

    def _customer_summary_report(self, fields):
        return self.client.customer_summary_report()


def main():
    if len(sys.argv) != 3:
        print("Usage: python run_transactions.py <input_file> <output_file>")
        sys.exit(1)

    with BookstoreClient() as client:
        runner = TransactionRunner(client)
        runner.run(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
