"""MtaaWorks scoring service (FastAPI).

Run from the ml-service folder:
    python -m uvicorn src.api:app --reload --port 8000
Interactive docs: http://127.0.0.1:8000/docs

Endpoints
    GET  /health           service status
    POST /score            (needs X-Service-Key) nine features -> score, tier, top drivers
    POST /score-statement  (needs X-Service-Key) statement PDF -> features -> score

Privacy: an uploaded statement is read in memory, is never written to disk, and neither the
file, the password nor any transaction detail is logged or returned. Only summary features
and validation counts leave the service. Use HTTPS if this is ever deployed beyond localhost.
"""
import io
import json
import os
import hmac
import time
from typing import Optional
from pathlib import Path
import joblib
import pandas as pd
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from pdfminer.pdfdocument import PDFPasswordIncorrect
from pydantic import BaseModel, Field
from scalar_fastapi import add_scalar_reference
from src.identity import check_identity, identities_agree, identity_check_enabled
from src.pdf_rows import read_identity
from src.statement_parser import (read_statement, validate, compute_features, features_for_scoring,
                                  last_read_method)

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
MAX_UPLOAD_BYTES = 25 * 1024 * 1024   # a 180-page statement is a few MB
MIN_FULL_MONTHS = 3                   # fewer full months give unstable monthly averages
MAX_FILES = 6                         # statements accepted in one scoring request
MAX_TOTAL_BYTES = 60 * 1024 * 1024

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
    files_read: int = 1
    duplicate_rows_removed: int = 0
    parser: str = "unknown"
    parse_seconds: float = 0.0
    identity_checked: bool = False
    name_matched: Optional[bool] = None
    phone_matched: Optional[bool] = None


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

def require_service_key(x_service_key: str = Header(default="")):
    expected = os.environ.get("SCORING_SERVICE_KEY", "")
    if not expected or not hmac.compare_digest(x_service_key.encode(), expected.encode()):
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.post("/score", response_model=ScoreResponse, dependencies=[Depends(require_service_key)])
def score(features: BorrowerFeatures):
    return score_values(features.model_dump())


def _read_one(data: bytes, password: str, label: str, expected_name: str = "", expected_phone: str = "", need_identity: bool = False):
    """Read one statement PDF. Errors name the statement when several were uploaded."""
    prefix = f"{label}: " if label else ""
    started = time.perf_counter()
    try:
        df, summary = read_statement(io.BytesIO(data), password)
    except Exception as exc:
        # pdfplumber wraps pdfminer errors, so look inside the exception as well as at it
        if isinstance(exc, PDFPasswordIncorrect) or any(isinstance(a, PDFPasswordIncorrect) for a in exc.args):
            raise HTTPException(status_code=400, detail=f"{prefix}The statement password is incorrect.")
        raise HTTPException(status_code=400, detail=f"{prefix}The file could not be read as an M-Pesa statement PDF.")
    seconds = time.perf_counter() - started
    if df.empty:
        raise HTTPException(status_code=422, detail=f"{prefix}No transactions were found in the statement.")
    v = validate(df, summary)
    if v.totals_checked and not (v.paid_in_matches and v.paid_out_matches):
        raise HTTPException(status_code=422, detail=f"{prefix}The transactions read do not match the statement's own "
                                                    "totals, so the statement was not scored.")
    method = last_read_method() or "unknown"

    # Who is the statement for? The name and number printed on it are compared with the account, and are not kept.
    found, identity = {}, {"checked": False, "name_matched": None, "phone_matched": None}
    if identity_check_enabled() and (expected_name or expected_phone or need_identity):
        try:
            found = read_identity(data, password)
        except Exception:
            found = {}
        identity = check_identity(found, expected_name, expected_phone)
        if identity["mismatch"]:
            if identity["name_matched"] is False:
                raise HTTPException(status_code=422, detail=f"{prefix}The customer name on the statement does not match the name on your "
                                    "MtaaWorks account. Update your name in your profile if it is spelt differently, or upload your own statement.")
            raise HTTPException(status_code=422, detail=f"{prefix}The mobile number on the statement does not match the verified phone "
                                "number on your MtaaWorks account.")
    return df, v, seconds, method, found, identity


def _score_frame(df, v, files_read, duplicates, seconds, parser_name, identity=None):
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
            balance_breaks_by_completion_time=v.group_breaks,
            files_read=files_read, duplicate_rows_removed=duplicates,
            parser=parser_name, parse_seconds=round(seconds, 2),
            identity_checked=bool((identity or {}).get("checked")),
            name_matched=(identity or {}).get("name_matched"),
            phone_matched=(identity or {}).get("phone_matched")),
    )


# These are plain functions (not async) so FastAPI runs them in its thread pool; reading a PDF is
# CPU work and would otherwise block every other request, including /health, while it ran.
@app.post("/score-statement", response_model=StatementScoreResponse, dependencies=[Depends(require_service_key)])
def score_statement(file: UploadFile = File(...), password: str = Form(...), expected_name: str = Form(""), expected_phone: str = Form("")):
    data = file.file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="The file is too large.")
    df, v, seconds, parser_name, _, identity = _read_one(data, password, "", expected_name, expected_phone)
    return _score_frame(df, v, 1, 0, seconds, parser_name, identity)


@app.post("/score-statements", response_model=StatementScoreResponse, dependencies=[Depends(require_service_key)])
def score_statements(files: list[UploadFile] = File(...), passwords: str = Form(...), expected_name: str = Form(""), expected_phone: str = Form("")):
    """Score several statements of one borrower together (for example two 3-month statements).
    `passwords` is a JSON list with one password per file, in the same order as the files."""
    if not 1 <= len(files) <= MAX_FILES:
        raise HTTPException(status_code=422, detail=f"Upload between 1 and {MAX_FILES} statements.")
    try:
        password_list = json.loads(passwords)
        if not (isinstance(password_list, list) and all(isinstance(p, str) for p in password_list)):
            raise ValueError
    except ValueError:
        raise HTTPException(status_code=422, detail="The passwords must be a JSON list of strings.")
    if len(password_list) != len(files):
        raise HTTPException(status_code=422, detail="Supply one password for each statement.")
    blobs = [f.file.read() for f in files]
    if any(len(b) > MAX_UPLOAD_BYTES for b in blobs) or sum(len(b) for b in blobs) > MAX_TOTAL_BYTES:
        raise HTTPException(status_code=413, detail="The files are too large.")

    frames, seconds_total, methods, seen, duplicates = [], 0.0, [], set(), 0
    totals_ok, breaks_each = True, 0
    first_found, identity_result = None, {"checked": False, "name_matched": None, "phone_matched": None}
    for n, (data, password) in enumerate(zip(blobs, password_list), start=1):
        label = f"Statement {n}" if len(blobs) > 1 else ""
        df, v, seconds, parser_name, found, identity = _read_one(data, password, label, expected_name, expected_phone, need_identity=len(blobs) > 1)
        identity_result = {
            "checked": identity["checked"] or identity_result["checked"],
            "name_matched": identity["name_matched"] if identity["name_matched"] is not None else identity_result["name_matched"],
            "phone_matched": identity["phone_matched"] if identity["phone_matched"] is not None else identity_result["phone_matched"],
        }
        if first_found is None:
            first_found = found
        elif identity_check_enabled() and identities_agree(first_found, found) is False:
            raise HTTPException(status_code=422, detail="These statements show different customer names or mobile numbers, so they do not "
                                "appear to belong to the same M-Pesa account. Upload statements from one account only.")
        seconds_total += seconds
        methods.append(parser_name)
        totals_ok = totals_ok and v.totals_checked
        breaks_each += v.group_breaks
        keys = list(zip(df["receipt"], df["time"], df["details"], df["paid_in"], df["withdrawn"], df["balance"]))
        keep = [k not in seen for k in keys]          # drop rows already read from an earlier statement
        duplicates += keep.count(False)
        seen.update(k for k, kept in zip(keys, keep) if kept)
        frames.append(df[keep])
    merged = pd.concat(frames, ignore_index=True)
    merged = merged.sort_values("time", ascending=False, kind="stable").reset_index(drop=True)

    if len(frames) > 1:
        present = set(merged["time"].dt.to_period("M"))
        every = pd.period_range(min(present), max(present), freq="M")
        missing = [str(m) for m in every if m not in present]
        if missing:
            raise HTTPException(status_code=422, detail="The statements do not cover a continuous period. "
                                "No transactions were found for " + ", ".join(missing) + ".")
    v = validate(merged, None)
    # Statements of one account follow on from each other, so joining them can add at most one
    # balance break per join. Many more means the rows come from different accounts.
    if len(frames) > 1 and v.group_breaks > breaks_each + (len(frames) - 1):
        raise HTTPException(status_code=422, detail="These statements do not appear to belong to the same "
                            "M-Pesa account: their balances do not follow on from one another. "
                            "Upload statements from one account only.")
    v.totals_checked = totals_ok                      # each statement was checked against its own TOTAL row
    v.paid_in_matches = v.paid_out_matches = totals_ok
    parser_name = methods[0] if len(set(methods)) == 1 else "mixed"
    return _score_frame(merged, v, len(frames), duplicates, seconds_total, parser_name, identity_result)

from src.report_api import make_router  # noqa: E402
app.include_router(make_router(require_service_key))
