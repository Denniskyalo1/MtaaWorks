"""Check the fast statement reader against the original pdfplumber reader on one statement.
Run from the ml-service folder:   python tools/compare_readers.py path\\to\\statement.pdf
Prints timings and whether both readers produced identical rows. No names, numbers, receipts
or transaction details are printed, and the password is not saved."""
import getpass
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.statement_parser import read_statement, validate


def main(path):
    password = getpass.getpass("Statement password (not saved): ")
    results = {}
    for method in ("fast", "reliable"):
        started = time.perf_counter()
        try:
            results[method] = read_statement(path, password, method=method)
        except Exception as exc:
            print(f"{method:9s} FAILED: {type(exc).__name__}: {exc}")
            if method == "reliable":
                return
            print("The fast reader could not read this statement. The service will use the reliable reader for it.")
            continue
        print(f"{method:9s} {time.perf_counter() - started:7.2f} s   rows: {len(results[method][0])}")
    if "fast" not in results:
        return
    (fast, fast_summary), (slow, slow_summary) = results["fast"], results["reliable"]
    same = fast.reset_index(drop=True).equals(slow.reset_index(drop=True))
    print("identical rows and row labels:", same)
    print("summary totals equal:", fast_summary == slow_summary)
    v = validate(fast, fast_summary)
    print("fast reader totals match the statement's own TOTAL row:", v.paid_in_matches and v.paid_out_matches)
    if not same:
        print("The readers disagree. Keep STATEMENT_PARSER=reliable and tell the developer.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python tools/compare_readers.py statement.pdf")
    main(sys.argv[1])
