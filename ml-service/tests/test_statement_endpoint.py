"""
Tests for POST /score-statement. The PDF reader is replaced by a stub that returns a small
synthetic statement, so no real statement is needed. Run from the ml-service folder:
    python -m pytest tests -v"""
import sys
from pathlib import Path

import pandas as pd
import pytest
from pdfminer.pdfdocument import PDFPasswordIncorrect

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
import src.api as api
from src.statement_parser import classify

client = TestClient(api.app)


def synthetic_statement(months=8):
    """A consistent statement: each month has income, spending, a fee, a bill and a savings deposit."""
    rows, balance = [], 1000.0
    for m in range(1, months + 1):
        for day, details, inn, out in [(5, "Funds received from - X", 3000.0, 0.0),
                                       (10, "Customer Transfer to - X", 0.0, 500.0),
                                       (10, "Customer Transfer of Funds Charge", 0.0, 7.0),
                                       (15, "Pay Bill Online to 000000 - BILLER Acc. 1", 0.0, 200.0),
                                       (20, "M-Shwari Deposit", 0.0, 100.0)]:
            balance += inn - out
            rows.append([f"R{len(rows):09d}", pd.Timestamp(2026, m, day, 10, 0, 0), details, "Completed", inn, out, balance])
    df = pd.DataFrame(rows, columns=["receipt", "time", "details", "status", "paid_in", "withdrawn", "balance"])
    df["kind"] = [classify(d, i, w) for d, i, w in zip(df["details"], df["paid_in"], df["withdrawn"])]
    df = df.iloc[::-1].reset_index(drop=True)  # newest first, like the real statement
    summary = {"paid_in": df["paid_in"].sum(), "paid_out": df["withdrawn"].sum()}
    return df, summary


def post(monkeypatch, reader):
    monkeypatch.setattr(api, "read_statement", reader)
    return client.post("/score-statement", files={"file": ("s.pdf", b"%PDF-stub", "application/pdf")},
                       data={"password": "secret"})


def test_valid_statement_returns_score_features_and_validation(monkeypatch):  # TC-S09
    r = post(monkeypatch, lambda f, p: synthetic_statement())
    assert r.status_code == 200
    body = r.json()
    assert body["result"]["tier"] in ("Tier 1", "Tier 2", "Tier 3")
    assert set(body["features"]) == set(api.FEATURES)
    assert body["validation"]["totals_match"] is True and body["validation"]["rows_read"] == 40
    assert body["full_months_used"] == 6 and "loan_repayment_regularity" in body["imputed_features"]


def test_response_contains_no_transaction_details(monkeypatch):  # TC-S10
    text = post(monkeypatch, lambda f, p: synthetic_statement()).text
    for leaked in ("Funds received", "Customer Transfer", "BILLER", "secret"):
        assert leaked not in text


def test_wrong_password_is_rejected(monkeypatch):  # TC-S11
    def reader(f, p):
        raise PDFPasswordIncorrect()
    r = post(monkeypatch, reader)
    assert r.status_code == 400 and "password" in r.json()["detail"]


def test_wrapped_wrong_password_is_rejected(monkeypatch):  # TC-S11b
    from pdfplumber.utils.exceptions import PdfminerException

    def reader(f, p):
        raise PdfminerException(PDFPasswordIncorrect())  # what pdfplumber really raises
    r = post(monkeypatch, reader)
    assert r.status_code == 400 and "password" in r.json()["detail"]


def test_unreadable_file_is_rejected(monkeypatch):  # TC-S12
    def reader(f, p):
        raise ValueError("not a pdf")
    assert post(monkeypatch, reader).status_code == 400


def test_empty_statement_is_rejected(monkeypatch):  # TC-S13
    empty = pd.DataFrame(columns=["receipt", "time", "details", "status", "paid_in", "withdrawn", "balance", "kind"])
    assert post(monkeypatch, lambda f, p: (empty, None)).status_code == 422


def test_totals_mismatch_is_not_scored(monkeypatch):  # TC-S14
    def reader(f, p):
        df, summary = synthetic_statement()
        summary["paid_in"] += 10
        return df, summary
    r = post(monkeypatch, reader)
    assert r.status_code == 422 and "totals" in r.json()["detail"]


def test_too_little_history_is_rejected(monkeypatch):  # TC-S15
    assert post(monkeypatch, lambda f, p: synthetic_statement(months=4)).status_code == 422


def test_missing_password_is_rejected():  # TC-S16
    r = client.post("/score-statement", files={"file": ("s.pdf", b"x", "application/pdf")})
    assert r.status_code == 422