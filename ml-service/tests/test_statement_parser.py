"""Unit tests for the statement parser's classification and feature rules.
They use small hand-made tables, so no real statement is needed.
Run from the ml-service folder:  python -m pytest tests -v"""
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.statement_parser import classify, compute_features, features_for_scoring, validate


def test_classify_known_wording():  # TC-P01
    assert classify("Customer Transfer of Funds Charge", 0, 5) == "charge"
    assert classify("Pay Bill Charge", 0, 5) == "charge"
    assert classify("Pay Bill Online to 000000 - TEST BILLER C2B Acc. X1", 0, 100) == "bill_payment"
    assert classify("Funds received from - 254700***000 TEST PERSON", 500, 0) == "income"
    assert classify("M-Shwari Deposit", 0, 200) == "savings_deposit"
    assert classify("M-Shwari Withdraw", 300, 0) == "savings_withdrawal"
    assert classify("Customer Transfer to - 254700***000 TEST PERSON", 0, 50) == "spending"
    assert classify("Send Money Reversal", 50, 0) == "reversal"
    assert classify("OverDraft of Credit Party", 100, 0) == "fuliza_draw"
    assert classify("OD Loan Repayment to 000000 - Overdraft", 0, 100) == "loan_repayment"
    assert classify("M-Shwari Lock Savings Deposit", 0, 100) == "savings_deposit"
    assert classify("Term Loan Disbursement", 5000, 0) == "loan_disbursement"
    assert classify("M-Shwari Loan Repayment", 0, 300) == "loan_repayment"
    assert classify("Pay Utility Reversal", 80, 0) == "reversal"
    assert classify("Merchant Payment Fuliza M-Pesa to 000000 - TEST SHOP", 0, 80) == "spending"


def _statement(rows):
    df = pd.DataFrame(rows, columns=["time", "details", "paid_in", "withdrawn"])
    df["time"] = pd.to_datetime(df["time"])
    df["kind"] = [classify(d, i, w) for d, i, w in zip(df["details"], df["paid_in"], df["withdrawn"])]
    return df


FOUR_MONTHS = [  # first and last months are partial and must be ignored
    ("2026-01-31 10:00:00", "Funds received from - X", 9999, 0),
    ("2026-02-05 10:00:00", "Funds received from - X", 1000, 0),
    ("2026-02-06 10:00:00", "Customer Transfer to - X", 0, 400),
    ("2026-02-07 10:00:00", "Customer Transfer of Funds Charge", 0, 10),
    ("2026-02-10 10:00:00", "Pay Bill Online to 000000 - BILLER Acc. 1", 0, 100),
    ("2026-02-12 10:00:00", "M-Shwari Deposit", 0, 50),
    ("2026-03-05 10:00:00", "Funds received from - X", 3000, 0),
    ("2026-03-06 10:00:00", "Customer Transfer to - X", 0, 600),
    ("2026-04-30 10:00:00", "Funds received from - X", 9999, 0),
]


def test_features_use_full_months_only():  # TC-P02
    f, info = compute_features(_statement(FOUR_MONTHS))
    assert info["months_used"] == 2 and info["first_month"] == "2026-01"
    assert f["avg_monthly_inflow"] == 2000          # (1000 + 3000) / 2
    assert abs(f["inflow_volatility"] - 0.5) < 1e-9  # std 1000 / mean 2000
    assert abs(f["outflow_to_inflow_ratio"] - (400 + 10 + 100 + 600) / 4000) < 1e-9  # savings excluded
    assert f["transaction_count_monthly"] == 3.0     # 6 non-charge rows over 2 full months


def test_charges_and_savings_rules():  # TC-P03
    f, _ = compute_features(_statement(FOUR_MONTHS))
    assert f["savings_deposit_frequency"] == 0.5     # 1 deposit over 2 months
    assert f["bill_payment_consistency"] == 0.5      # bill in Feb only


def test_missing_loan_history_is_imputed_not_invented():  # TC-P04
    f, _ = compute_features(_statement(FOUR_MONTHS))
    assert f["fuliza_usage_frequency"] == 0.0        # a true zero
    assert f["loan_repayment_regularity"] is None    # undefined without loans
    scoring, imputed = features_for_scoring(f)
    assert imputed == ["loan_repayment_regularity"] and scoring["loan_repayment_regularity"] == 0.738


def test_validate_flags_total_mismatch():  # TC-P05
    df = _statement(FOUR_MONTHS)
    df["balance"] = 0.0
    ok = validate(df, {"paid_in": df["paid_in"].sum(), "paid_out": df["withdrawn"].sum()})
    bad = validate(df, {"paid_in": df["paid_in"].sum() + 5, "paid_out": df["withdrawn"].sum()})
    assert ok.paid_in_matches and ok.paid_out_matches and not bad.paid_in_matches and not bad.passed


LOAN_MONTHS = [  # Fuliza draws every month, repayment in only 2 of the 3 full months
    ("2026-01-15 09:00:00", "Funds received from - X", 100, 0),
    ("2026-02-02 09:00:00", "OverDraft of Credit Party", 200, 0),
    ("2026-02-03 09:00:00", "OverDraft of Credit Party", 200, 0),
    ("2026-02-20 09:00:00", "OD Loan Repayment to 000000 - Overdraft", 0, 400),
    ("2026-03-04 09:00:00", "OverDraft of Credit Party", 150, 0),
    ("2026-03-21 09:00:00", "Funds received from - X", 1000, 0),
    ("2026-04-05 09:00:00", "OverDraft of Credit Party", 100, 0),
    ("2026-04-25 09:00:00", "OD Loan Repayment to 000000 - Overdraft", 0, 100),
    ("2026-05-10 09:00:00", "Funds received from - X", 100, 0),
]


def test_fuliza_and_loan_features():  # TC-P06
    f, info = compute_features(_statement(LOAN_MONTHS))
    assert info["months_used"] == 3                       # Feb, Mar, Apr
    assert abs(f["fuliza_usage_frequency"] - 4 / 3) < 1e-9   # 4 draws over 3 full months
    assert abs(f["loan_repayment_regularity"] - 2 / 3) < 1e-9  # repaid in Feb and Apr only
    assert f["avg_monthly_inflow"] == 1000 / 3           # Fuliza draws are not income