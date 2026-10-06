"""MtaaWorks scoring service (FastAPI).

Run from the ml-service folder:
    python -m uvicorn src.api:app --reload --port 8000
Interactive docs: http://127.0.0.1:8000/docs
"""
import json
from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel, Field

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"

# Loaded once at start-up. Both files are written by src/train.py.
calibrated_model = joblib.load(MODELS_DIR / "credit_model.pkl")
lr_pipeline = joblib.load(MODELS_DIR / "lr_pipeline.pkl")
with open(MODELS_DIR / "model_meta.json") as fh:
    META = json.load(fh)

FEATURES = META["feature_names"]
TIER_1_CUTOFF = META["tier_1_cutoff"]
TIER_2_CUTOFF = META["tier_2_cutoff"]
THRESHOLD = META["decision_threshold"]
RANGES = META["training_ranges"]

app = FastAPI(
    title="MtaaWorks Scoring Service",
    description="Returns a probability of default, a 0-100 score, a risk tier and the top "
                "three score drivers for one borrower's M-Pesa-derived features.",
    version=META["model_version"],
)


class BorrowerFeatures(BaseModel):
    avg_monthly_inflow: float = Field(ge=0)
    inflow_volatility: float = Field(ge=0)
    outflow_to_inflow_ratio: float = Field(ge=0)
    fuliza_usage_frequency: float = Field(ge=0)
    loan_repayment_regularity: float = Field(ge=0, le=1)
    savings_deposit_frequency: float = Field(ge=0)
    bill_payment_consistency: float = Field(ge=0, le=1)
    account_age_months: float = Field(ge=0)
    transaction_count_monthly: float = Field(ge=0)


class Driver(BaseModel):
    feature: str
    contribution: float
    effect: str


class ScoreResponse(BaseModel):
    probability_of_default: float
    score: float
    tier: str
    flagged_high_risk: bool
    top_drivers: list[Driver]
    out_of_range_features: list[str]
    model_version: str


def assign_tier(score: float) -> str:
    if score >= TIER_1_CUTOFF:
        return "Tier 1"
    if score >= TIER_2_CUTOFF:
        return "Tier 2"
    return "Tier 3"


def explain(row: pd.DataFrame) -> list[Driver]:
    """Coefficient x standardised value for each feature (the contribution to the
    log-odds of default relative to the training average). For a linear model with
    independent features this equals the SHAP value. It is computed from the plain
    Logistic Regression pipeline, so it approximates the calibrated score's drivers."""
    scaler = lr_pipeline.named_steps["scaler"]
    clf = lr_pipeline.named_steps["classifier"]
    contributions = clf.coef_[0] * scaler.transform(row)[0]
    ranked = sorted(zip(FEATURES, contributions), key=lambda fc: abs(fc[1]), reverse=True)[:3]
    return [
        Driver(
            feature=f,
            contribution=round(float(c), 4),
            effect="increases default risk" if c > 0 else "reduces default risk",
        )
        for f, c in ranked
    ]


@app.get("/health")
def health():
    return {"status": "ok", "model_version": META["model_version"], "model": META["model_name"]}


@app.post("/score", response_model=ScoreResponse)
def score(features: BorrowerFeatures):
    row = pd.DataFrame([features.model_dump()], columns=FEATURES)
    p = float(calibrated_model.predict_proba(row)[0, 1])
    score_value = round((1 - p) * 100, 1)
    out_of_range = [
        f for f in FEATURES
        if not (RANGES[f][0] <= float(row[f].iloc[0]) <= RANGES[f][1])
    ]
    return ScoreResponse(
        probability_of_default=round(p, 4),
        score=score_value,
        tier=assign_tier((1 - p) * 100),
        flagged_high_risk=p >= THRESHOLD,
        top_drivers=explain(row),
        out_of_range_features=out_of_range,
        model_version=META["model_version"],
    )
