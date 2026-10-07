"""Parse a password-protected M-Pesa statement, validate it and print the nine
scoring features. Prints no names, numbers, receipts or transaction details.

Usage (from the ml-service folder, venv active):
    python tools\\run_parser.py "C:\\path\\to\\statement.pdf"
"""
import getpass
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.statement_parser import read_statement, validate, compute_features, features_for_scoring


def main(path):
    password = getpass.getpass("Statement password (not saved): ")
    df, summary = read_statement(path, password)
    v = validate(df, summary)
    print("\n=== VALIDATION ===")
    print("rows read:", v.rows, "| period:", v.first_time[:10], "to", v.last_time[:10])
    print("summary totals found:", v.totals_checked)
    print("Paid In total matches summary:", v.paid_in_matches)
    print("Withdrawn total matches summary:", v.paid_out_matches)
    print("balance continuity breaks:", v.balance_breaks)
    for note in v.notes:
        print("note:", note)
    print("RESULT:", "PASS" if v.passed else "CHECK NEEDED")
    if df.empty:
        return
    features, info = compute_features(df)
    scoring, imputed = features_for_scoring(features)
    print("\n=== ROW TYPES ===")
    for k, c in info["row_kinds"].items():
        print(f"{c:6d}  {k}")
    print("\n=== FEATURES ===")
    print("months in statement:", info["months_in_statement"], "| full months used:", info["months_used"])
    for k, val in scoring.items():
        print(f"{k:28s} {val}")
    print("imputed (could not be computed):", imputed or "none")
    print("\n=== JSON FOR /score ===")
    print(json.dumps(scoring, indent=2))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python tools\\run_parser.py <statement.pdf>")
    main(sys.argv[1])