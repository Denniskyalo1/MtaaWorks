"""Scoring-service tests. Run from the ml-service folder:
    python -m pytest tests -v
(requires: python -m pip install pytest httpx)"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from src.api import app, META

client = TestClient(app)

# A typical mid-range borrower, and two clearly different profiles.
TYPICAL = {
    "avg_monthly_inflow": 15000, "inflow_volatility": 0.3, "outflow_to_inflow_ratio": 0.77,
    "fuliza_usage_frequency": 4, "loan_repayment_regularity": 0.74, "savings_deposit_frequency": 2,
    "bill_payment_consistency": 0.76, "account_age_months": 30, "transaction_count_monthly": 35,
}
STRONG = {**TYPICAL, "loan_repayment_regularity": 0.98, "bill_payment_consistency": 0.97,
          "inflow_volatility": 0.1, "outflow_to_inflow_ratio": 0.5, "fuliza_usage_frequency": 0}
WEAK = {**TYPICAL, "loan_repayment_regularity": 0.2, "bill_payment_consistency": 0.25,
        "inflow_volatility": 0.7, "outflow_to_inflow_ratio": 1.2, "fuliza_usage_frequency": 12}


def test_health():  # TC-S01
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_valid_request_returns_complete_result():  # TC-S02
    r = client.post("/score", json=TYPICAL)
    assert r.status_code == 200
    body = r.json()
    assert 0 <= body["probability_of_default"] <= 1
    assert 0 <= body["score"] <= 100
    assert body["tier"] in ("Tier 1", "Tier 2", "Tier 3")
    assert len(body["top_drivers"]) == 3


def test_score_consistent_with_probability_and_tier():  # TC-S03
    body = client.post("/score", json=TYPICAL).json()
    assert abs(body["score"] - round((1 - body["probability_of_default"]) * 100, 1)) <= 0.1
    s = body["score"]
    expected = ("Tier 1" if s >= META["tier_1_cutoff"]
                else "Tier 2" if s >= META["tier_2_cutoff"] else "Tier 3")
    assert body["tier"] == expected


def test_strong_profile_scores_higher_than_weak():  # TC-S04
    strong = client.post("/score", json=STRONG).json()
    weak = client.post("/score", json=WEAK).json()
    assert strong["score"] > weak["score"]
    assert strong["probability_of_default"] < weak["probability_of_default"]


def test_missing_feature_is_rejected():  # TC-S05
    bad = {k: v for k, v in TYPICAL.items() if k != "loan_repayment_regularity"}
    assert client.post("/score", json=bad).status_code == 422


def test_negative_and_out_of_bounds_values_are_rejected():  # TC-S06
    assert client.post("/score", json={**TYPICAL, "avg_monthly_inflow": -1}).status_code == 422
    assert client.post("/score", json={**TYPICAL, "loan_repayment_regularity": 1.5}).status_code == 422


def test_wrong_type_is_rejected():  # TC-S07
    assert client.post("/score", json={**TYPICAL, "account_age_months": "abc"}).status_code == 422


def test_value_outside_training_range_is_flagged():  # TC-S08
    r = client.post("/score", json={**TYPICAL, "avg_monthly_inflow": 5_000_000})
    assert r.status_code == 200
    assert "avg_monthly_inflow" in r.json()["out_of_range_features"]
