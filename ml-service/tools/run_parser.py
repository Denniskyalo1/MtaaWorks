"""Parse a password-protected M-Pesa statement, validate it and print the nine
scoring features. Prints no names, numbers, receipts or transaction details.

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
    print("balance breaks, row by row:", v.balance_breaks)
    print("balance breaks, per completion time (tolerates the order of rows sharing a time):", v.group_breaks)
    if v.group_breaks:
        common = [(w, c) for w, c in v.group_break_wording.items() if c >= 3]
        rare = sum(c for w, c in v.group_break_wording.items() if c < 3)
        print("  rows in the groups that still do not follow (generic wording, 3+ times):")
        for w, c in common:
            print(f"  {c:6d}  {w}")
        print(f"  {rare:6d}  (rarer wording, not shown)")
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