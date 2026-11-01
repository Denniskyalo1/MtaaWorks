"""Shows how the customer block at the top of a statement is laid out, without showing who it belongs to.
Run from the ml-service folder:   python tools\\inspect_statement_header.py path\\to\\statement.pdf
Every letter is printed as A or a and every digit as 9, so the output holds no names or numbers. The password is not saved."""
import getpass
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import pymupdf
from src.identity import KNOWN_LABELS, parse_identity


def shape(text):
    return re.sub(r"[a-z]", "a", re.sub(r"[A-Z]", "A", re.sub(r"\d", "9", text)))


def main(path):
    password = getpass.getpass("Statement password (not saved): ")
    doc = pymupdf.open(path)
    if doc.needs_pass and not doc.authenticate(password):
        sys.exit("Wrong password.")
    lines = [l.strip() for l in doc[0].get_text().splitlines() if l.strip()][:30]
    print("First lines of page 1 (labels shown, values replaced by shapes):")
    for i, l in enumerate(lines):
        low = l.lower()
        is_label = low.endswith(":") or any(low.startswith(k) for k in KNOWN_LABELS)
        print(f"{i:2d}  {l if is_label and len(l) < 40 and not re.search(r'\d', l) else shape(l)}")
    found = parse_identity(doc[0].get_text())
    print("\nName found:", "yes, " + shape(found["name"]) if found["name"] else "no")
    print("Number found:", "yes, " + shape(found["phone"]) if found["phone"] else "no")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python tools\\inspect_statement_header.py statement.pdf")
    main(sys.argv[1])
