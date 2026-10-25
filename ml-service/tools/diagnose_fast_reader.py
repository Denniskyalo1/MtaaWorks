"""Find out where the fast statement reader and the pdfplumber reader disagree, page by page.
Run from the ml-service folder:   python tools\\diagnose_fast_reader.py path\\to\\statement.pdf
The output has page numbers, counts and layout shapes only (letters become A or a, digits become 9),
so it contains no names, phone numbers, receipts or amounts. The password is not saved."""
import getpass
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import pymupdf
from src import pdf_rows


def shape(text):
    return re.sub(r"[a-z]", "a", re.sub(r"[A-Z]", "A", re.sub(r"\d", "9", text)))


def main(path):
    password = getpass.getpass("Statement password (not saved): ")
    data = Path(path).read_bytes()
    doc = pymupdf.open(stream=data, filetype="pdf")
    if doc.needs_pass and not doc.authenticate(password):
        sys.exit("Wrong password.")
    bad = shown = 0
    for i, page in enumerate(doc):
        slow, _ = pdf_rows._plumber_pages(data, password, i, i + 1)
        one = pymupdf.open()
        one.insert_pdf(doc, from_page=i, to_page=i)
        try:
            fast, _ = pdf_rows.read_fast(one.tobytes(), "")
            note = ""
        except pdf_rows.FastReaderUnavailable as exc:
            fast, note = [], f"fast reader declined: {exc}"
        if fast == slow:
            continue
        bad += 1
        differs = sum(1 for a, b in zip(fast, slow) if a != b)
        print(f"page {i + 1}: reliable {len(slow)} rows, fast {len(fast)} rows, differing rows {differs} {note}")
        if shown < 2 and slow:
            shown += 1
            edges, rules = pdf_rows._grid(page)
            print("   column edges:", edges)
            print("   horizontal rules (first 8):", [round(r, 1) for r in (rules or [])[:8]])
            fast_receipts = {r[0] for r in fast}
            target = next((r for r in slow if r[0] not in fast_receipts), slow[0])
            anchor = next((w for w in page.get_text("words") if w[4] == target[0]), None)
            if anchor:
                print("   words around the first affected row (shape, x0, x1, y0, y1):")
                for w in sorted(page.get_text("words"), key=lambda w: (round(w[1]), w[0])):
                    if abs((w[1] + w[3]) / 2 - (anchor[1] + anchor[3]) / 2) < 22:
                        print(f"     {shape(w[4]):22s} {w[0]:6.1f} {w[2]:6.1f} {w[1]:6.1f} {w[3]:6.1f}")
    print(f"\n{bad} of {len(doc)} pages differ.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python tools\\diagnose_fast_reader.py statement.pdf")
    main(sys.argv[1])
