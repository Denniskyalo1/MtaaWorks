"""Reads the transaction rows of a password-protected M-Pesa statement PDF.

Two readers return the same thing, a list of 7-cell rows and the statement's own TOTAL row:

* read_fast       PyMuPDF words placed into the columns of the table grid. About 40 times faster.
* read_reliable   pdfplumber table extraction, the original reader. It can share the pages
                  between worker processes when the machine has several cores.

This module imports only light libraries so that worker processes start quickly.
Nothing is written to disk and nothing is logged.
"""
import bisect
import os
import re
from concurrent.futures import ProcessPoolExecutor

RECEIPT = re.compile(r"^[A-Z0-9]{10}$")
TIME = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
COLUMNS = 7
AMOUNT = re.compile(r"^-?\d[\d,]*(\.\d+)?$")
PARALLEL_MIN_PAGES = 8   # below this, starting worker processes costs more than it saves


class WrongPassword(Exception):
    """The statement password was not accepted."""


class FastReaderUnavailable(Exception):
    """PyMuPDF is missing or the page layout was not recognised; use the reliable reader."""


def _num(text):
    text = (text or "").replace(",", "").strip()
    return float(text) if text not in ("", "-") else 0.0


def _clean(cell):
    return (cell or "").replace("\n", " ").strip()


# ---------------------------------------------------------------- fast reader (PyMuPDF)

def _grid(page):
    """Vertical grid lines (COLUMNS + 1 x positions) and the y positions of the horizontal rules.

    Row boundaries come from the rules drawn between rows, because text can be centred in a cell
    or wrapped onto several lines, so the position of the receipt number alone does not say
    where a row starts or ends. Returns (None, None) when the grid is not recognised."""
    vertical, horizontal = {}, {}
    for drawing in page.get_drawings():
        for item in drawing["items"]:
            if item[0] == "l":
                p, q = item[1], item[2]
                if abs(p.x - q.x) < 0.5 and abs(p.y - q.y) > 6:
                    vertical[round(p.x)] = vertical.get(round(p.x), 0) + abs(p.y - q.y)
                elif abs(p.y - q.y) < 0.5 and abs(p.x - q.x) > 50:
                    horizontal[round(p.y, 1)] = 1
            elif item[0] == "re":
                r = item[1]
                if r.height > 6:
                    for x in (r.x0, r.x1):
                        vertical[round(x)] = vertical.get(round(x), 0) + r.height
                if r.width > 50:
                    for y in (r.y0, r.y1):
                        horizontal[round(y, 1)] = 1
    if len(vertical) < COLUMNS + 1:
        return None, None
    edges = sorted(sorted(vertical, key=vertical.get, reverse=True)[:COLUMNS + 1])
    if any(b - a < 5 for a, b in zip(edges, edges[1:])):
        return None, None
    rules = []
    for y in sorted(horizontal):                      # merge rules closer than 1 point
        if not rules or y - rules[-1] > 1.0:
            rules.append(y)
    return edges, rules


def read_fast(data, password):
    try:
        import pymupdf
    except ImportError as exc:
        raise FastReaderUnavailable("PyMuPDF is not installed") from exc
    try:
        doc = pymupdf.open(stream=data, filetype="pdf")
    except Exception as exc:
        raise FastReaderUnavailable("PyMuPDF could not open the file") from exc
    if doc.needs_pass and not doc.authenticate(password):
        raise WrongPassword()
    rows, summary = [], None
    for page in doc:
        words = page.get_text("words")          # x0, y0, x1, y1, text, ...
        if summary is None:
            # the TOTAL row of the summary table; other lines may also contain the word TOTAL
            for w in words:
                if w[4].upper().rstrip(":").startswith("TOTAL"):
                    same_line = sorted((x for x in words if abs(x[1] - w[1]) < 3 and x[0] > w[2]),
                                       key=lambda x: x[0])
                    amounts = [x[4] for x in same_line if AMOUNT.match(x[4])]
                    if len(amounts) >= 2:
                        summary = {"paid_in": _num(amounts[0]), "paid_out": _num(amounts[1])}
                        break
        receipts = [w for w in words if RECEIPT.match(w[4])]
        edges, rules = _grid(page)
        if edges is None:
            if receipts:
                raise FastReaderUnavailable("the table grid was not recognised on a page with transactions")
            continue
        anchors = [w for w in receipts if edges[0] - 2 <= (w[0] + w[2]) / 2 <= edges[1]]
        band_of = {}
        for a in anchors:
            centre = (a[1] + a[3]) / 2
            k = bisect.bisect_right(rules, centre) - 1
            if k < 0 or k + 1 >= len(rules) or k in band_of:
                # not between two rules, or two receipts between the same rules
                raise FastReaderUnavailable("rows are not separated by rules on this page")
            band_of[k] = a
        for k, a in sorted(band_of.items(), key=lambda kv: kv[1][1]):
            lo, hi = rules[k], rules[k + 1]
            cells = [[] for _ in range(COLUMNS)]
            for w in words:
                if lo <= (w[1] + w[3]) / 2 < hi:
                    centre = (w[0] + w[2]) / 2
                    for c in range(COLUMNS):
                        if edges[c] <= centre < edges[c + 1]:
                            cells[c].append(w)
                            break
            row = [" ".join(x[4] for x in sorted(c, key=lambda x: (round(x[1]), x[0]))) for c in cells]
            if RECEIPT.match(row[0]) and TIME.match(row[1]):
                rows.append(row)
    return rows, summary


# ---------------------------------------------------------------- reliable reader (pdfplumber)

def _plumber_pages(data, password, start, stop):
    import io
    import pdfplumber
    from pdfminer.pdfdocument import PDFPasswordIncorrect
    rows, summary = [], None
    try:
        with pdfplumber.open(io.BytesIO(data), password=password) as pdf:
            for page in pdf.pages[start:stop]:
                for table in page.extract_tables():
                    for r in table:
                        cells = [_clean(c) for c in r]
                        if len(cells) == COLUMNS and RECEIPT.match(cells[0]) and TIME.match(cells[1]):
                            rows.append(cells)
                        elif summary is None and len(cells) >= 3 and cells[0].upper().startswith("TOTAL"):
                            summary = {"paid_in": _num(cells[1]), "paid_out": _num(cells[2])}
                page.flush_cache()
    except Exception as exc:
        if isinstance(exc, PDFPasswordIncorrect) or any(isinstance(a, PDFPasswordIncorrect) for a in exc.args):
            raise WrongPassword() from exc
        raise
    return rows, summary


def _page_count(data, password):
    import io
    import pdfplumber
    from pdfminer.pdfdocument import PDFPasswordIncorrect
    try:
        with pdfplumber.open(io.BytesIO(data), password=password) as pdf:
            return len(pdf.pages)
    except Exception as exc:
        if isinstance(exc, PDFPasswordIncorrect) or any(isinstance(a, PDFPasswordIncorrect) for a in exc.args):
            raise WrongPassword() from exc
        raise


def worker_count():
    return max(1, min(4, (os.cpu_count() or 1) - 1))


def read_reliable(data, password, workers=None):
    workers = worker_count() if workers is None else workers
    pages = _page_count(data, password)
    if workers <= 1 or pages < PARALLEL_MIN_PAGES:
        return _plumber_pages(data, password, 0, pages)
    size = -(-pages // workers)                      # pages per worker, rounded up
    spans = [(s, min(s + size, pages)) for s in range(0, pages, size)]
    rows, summary = [], None
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(_plumber_pages, data, password, s, e) for s, e in spans]
        for future in futures:                       # keep page order
            r, s = future.result()
            rows += r
            summary = summary or s
    return rows, summary


# ---------------------------------------------------------------- customer name and number (first page)

def read_identity(data, password):
    """The customer name and mobile number printed on the first page, as {"name": ..., "phone": ...}."""
    from src.identity import parse_identity
    text = ""
    try:
        import pymupdf
        doc = pymupdf.open(stream=data, filetype="pdf")
        if doc.needs_pass and not doc.authenticate(password):
            raise WrongPassword()
        text = doc[0].get_text() if len(doc) else ""
    except ImportError:
        import io
        import pdfplumber
        from pdfminer.pdfdocument import PDFPasswordIncorrect
        try:
            with pdfplumber.open(io.BytesIO(data), password=password) as pdf:
                text = (pdf.pages[0].extract_text() or "") if pdf.pages else ""
        except Exception as exc:
            if isinstance(exc, PDFPasswordIncorrect) or any(isinstance(a, PDFPasswordIncorrect) for a in exc.args):
                raise WrongPassword() from exc
            raise
    return parse_identity(text)

