"""Privacy-safe structure check for an M-Pesa statement PDF.

Prints ONLY aggregate information (counts, column layout, generic transaction
wording seen at least 3 times). It never prints names, phone numbers, receipt
numbers, amounts or balances. The password is typed at a prompt and never saved.

Usage (from the ml-service folder, venv active):
    python -m pip install pdfplumber
    python tools\\inspect_statement.py "C:\\path\\to\\statement.pdf"
"""
import re
import sys
import getpass
from collections import Counter

import pdfplumber

RECEIPT = re.compile(r"^[A-Z0-9]{10}$")
TIME = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")


def clean(cell):
    return (cell or "").replace("\n", " ").strip()


def prefix(details, n=3):
    words = re.sub(r"[^A-Za-z ]", " ", details).split()
    return " ".join(words[:n]).lower()


def main(path):
    password = getpass.getpass("Statement password (not saved): ")
    rows, pages, text_pages, header_seen, bad_rows = [], 0, 0, None, 0
    with pdfplumber.open(path, password=password) as pdf:
        pages = len(pdf.pages)
        for page in pdf.pages:
            if page.extract_text():
                text_pages += 1
            for table in page.extract_tables():
                for r in table:
                    cells = [clean(c) for c in r]
                    if header_seen is None and cells and cells[0].lower().startswith("receipt"):
                        header_seen = cells
                    if len(cells) == 7 and RECEIPT.match(cells[0]) and TIME.match(cells[1]):
                        rows.append(cells)
                    elif len(cells) >= 5 and RECEIPT.match(cells[0]):
                        bad_rows += 1
    print("\n=== STRUCTURE ===")
    print("pages:", pages, "| pages with extractable text:", text_pages)
    print("column headers:", header_seen)
    print("transaction rows parsed (7 columns):", len(rows), "| rows with other layout:", bad_rows)
    if not rows:
        print("No transaction rows parsed. Tell me the lines above and I will adjust the method.")
        return
    months = Counter(r[1][:7] for r in rows)
    print("months covered:", min(months), "to", max(months), "| months with data:", len(months))
    print("rows per month (min / median / max):",
          min(months.values()), sorted(months.values())[len(months)//2], max(months.values()))
    print("statuses:", dict(Counter(r[3] for r in rows)))
    paid_in = sum(1 for r in rows if r[4])
    paid_out = sum(1 for r in rows if r[5])
    neg_out = sum(1 for r in rows if r[5].startswith("-"))
    print("rows with Paid In:", paid_in, "| rows with Withdrawn:", paid_out, "| Withdrawn shown with a minus sign:", neg_out)
    both = sum(1 for r in rows if r[4] and r[5])
    print("rows with both Paid In and Withdrawn filled:", both)
    order = [r[1] for r in rows]
    print("order:", "newest first" if order[0] > order[-1] else "oldest first")
    pre = Counter(prefix(r[2]) for r in rows)
    common = [(p, c) for p, c in pre.most_common() if c >= 3]
    other = sum(c for p, c in pre.items() if c < 3)
    print("\n=== GENERIC TRANSACTION WORDING (first 3 words, seen 3+ times) ===")
    for p, c in common:
        print(f"{c:6d}  {p}")
    print(f"{other:6d}  (rarer wording, not shown)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python tools\\inspect_statement.py <statement.pdf>")
    main(sys.argv[1])