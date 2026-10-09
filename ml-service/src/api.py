"""MtaaWorks scoring service (FastAPI).

Run from the ml-service folder:
    python -m uvicorn src.api:app --reload --port 8000
Interactive docs: http://127.0.0.1:8000/docs

Endpoints
    GET  /health           service status
    POST /score            nine behavioural features -> score, tier, top drivers
    POST /score-statement  password-protected M-Pesa statement PDF -> features -> score

Privacy: an uploaded statement is read in memory, is never written to disk, and neither the
file, the password nor any transaction detail is logged or returned. Only summary features
and validation counts leave the service. Use HTTPS if this is ever deployed beyond localhost.
"""
import io
import json
from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from pdfminer.pdfdocument import PDFPasswordIncorrect
from pydantic import BaseModel, Field
from scalar_fastapi import add_scalar_reference

from src.statement_parser import read_statement, validate, compute_features, features_for_scoring

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
MAX_UPLOAD_BYTES = 25 * 1024 * 1024   # a 180-page statement is a few MB
MIN_FULL_MONTHS = 3                   # fewer full months give unstable monthly averages

# Loaded once at start-up. All three files are written by src/train.py.
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
                "three score drivers for one borrower's M-Pesa-derived features, either supplied "
                "directly or extracted from a consented M-Pesa statement.",
    version=META["model_version"],
    docs_url=None,
    redoc_url=None,
)

add_scalar_reference(app, route="/docs")


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


class StatementValidation(BaseModel):
    rows_read: int
    period_start: str
    period_end: str
    totals_checked: bool
    totals_match: bool
    balance_breaks_by_completion_time: int


class StatementScoreResponse(BaseModel):
    result: ScoreResponse
    features: dict[str, float]
    imputed_features: list[str]
    months_in_statement: int
    full_months_used: int
    validation: StatementValidation


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


def score_values(values: dict) -> ScoreResponse:
    row = pd.DataFrame([values], columns=FEATURES)
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


@app.get("/health")
def health():
    return {"status": "ok", "model_version": META["model_version"], "model": META["model_name"]}


@app.post("/score", response_model=ScoreResponse)
def score(features: BorrowerFeatures):
    return score_values(features.model_dump())


@app.post("/score-statement", response_model=StatementScoreResponse)
async def score_statement(file: UploadFile = File(...), password: str = Form(...)):
    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="The file is too large.")
    try:
        df, summary = read_statement(io.BytesIO(data), password)
    except Exception as exc:
        # pdfplumber wraps pdfminer errors, so look inside the exception as well as at it
        if isinstance(exc, PDFPasswordIncorrect) or any(isinstance(a, PDFPasswordIncorrect) for a in exc.args):
            raise HTTPException(status_code=400, detail="The statement password is incorrect.")
        raise HTTPException(status_code=400, detail="The file could not be read as an M-Pesa statement PDF.")
    if df.empty:
        raise HTTPException(status_code=422, detail="No transactions were found in the statement.")
    v = validate(df, summary)
    if v.totals_checked and not (v.paid_in_matches and v.paid_out_matches):
        raise HTTPException(status_code=422, detail="The transactions read do not match the statement's own "
                                                    "totals, so the statement was not scored.")
    features, info = compute_features(df)
    if info["months_used"] < MIN_FULL_MONTHS:
        raise HTTPException(status_code=422, detail=f"At least {MIN_FULL_MONTHS} full calendar months of "
                                                    f"history are needed to score a statement.")
    values, imputed = features_for_scoring(features)
    return StatementScoreResponse(
        result=score_values(values),
        features=values,
        imputed_features=imputed,
        months_in_statement=info["months_in_statement"],
        full_months_used=info["months_used"],
        validation=StatementValidation(
            rows_read=v.rows, period_start=v.first_time[:10], period_end=v.last_time[:10],
            totals_checked=v.totals_checked, totals_match=bool(v.paid_in_matches and v.paid_out_matches),
            balance_breaks_by_completion_time=v.group_breaks),
    )