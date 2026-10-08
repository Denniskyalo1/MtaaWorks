"""M-Pesa statement parser.
Reads the transaction table from a password-protected M-Pesa statement PDF,
checks it against the statement's own summary totals, and turns it into the
nine behavioural features used by the credit scoring model.
"""
import re
from dataclasses import dataclass, field

import numpy as np
import pandas as pd
import pdfplumber

RECEIPT = re.compile(r"^[A-Z0-9]{10}$")
TIME = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")

FEATURES = [
    "avg_monthly_inflow", "inflow_volatility", "outflow_to_inflow_ratio", "fuliza_usage_frequency",
    "loan_repayment_regularity", "savings_deposit_frequency", "bill_payment_consistency",
    "account_age_months", "transaction_count_monthly",
]
# Used only when a feature is undefined for a borrower (see compute_features).
TRAINING_MEANS = {"inflow_volatility": 0.302, "loan_repayment_regularity": 0.738}


def _num(text):
    text = (text or "").replace(",", "").strip()
    return float(text) if text not in ("", "-") else 0.0


def _clean(cell):
    return (cell or "").replace("\n", " ").strip()


def read_statement(path, password):
    """Return (transactions DataFrame, summary totals dict or None)."""
    rows, summary = [], None
    with pdfplumber.open(path, password=password) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                for r in table:
                    cells = [_clean(c) for c in r]
                    if len(cells) == 7 and RECEIPT.match(cells[0]) and TIME.match(cells[1]):
                        rows.append(cells)
                    elif summary is None and len(cells) >= 3 and cells[0].upper().startswith("TOTAL"):
                        summary = {"paid_in": _num(cells[1]), "paid_out": _num(cells[2])}
    df = pd.DataFrame(rows, columns=["receipt", "time", "details", "status", "paid_in", "withdrawn", "balance"])
    df["time"] = pd.to_datetime(df["time"])
    df["paid_in"] = df["paid_in"].map(_num)
    df["withdrawn"] = df["withdrawn"].map(_num).abs()
    df["balance"] = df["balance"].map(_num)
    df["kind"] = [classify(d, i, w) for d, i, w in zip(df["details"], df["paid_in"], df["withdrawn"])]
    return df, summary


def _wording(details, n=3):
    """First few generic words of a Details text (letters only), used for privacy-safe summaries."""
    return " ".join(re.sub(r"[^a-z ]", " ", (details or "").lower()).split()[:n])


def classify(details, paid_in, withdrawn):
    """Label a row using the generic wording at the start of its Details text."""
    norm = " ".join(re.sub(r"[^a-z ]", " ", (details or "").lower()).split())
    if "charge" in norm[:45] and not re.search(r"\d{4,}", details or ""):
        return "charge"
    if "reversal" in norm[:40]:
        return "reversal"
    if re.search(r"od loan repayment|loan repayment|fuliza.*repay", norm[:60]):
        return "loan_repayment"
    if paid_in > 0 and re.search(r"loan disburse", norm[:60]):
        return "loan_disbursement"
    if norm.startswith("overdraft of credit party"):
        return "fuliza_draw"
    if withdrawn > 0 and (norm.startswith("m shwari deposit") or norm.startswith("m shwari lock")
                          or norm.startswith("unit trust invest") or norm.startswith("savings contribution")):
        return "savings_deposit"
    if paid_in > 0 and (norm.startswith("m shwari withdraw") or norm.startswith("m shwari lock")):
        return "savings_withdrawal"
    if withdrawn > 0 and (norm.startswith("pay bill online to") or norm.startswith("pay bill to")
                          or norm.startswith("card pay bill")):
        return "bill_payment"
    if paid_in > 0:
        return "income"
    if withdrawn > 0:
        return "spending"
    return "other"


@dataclass
class Validation:
    rows: int = 0
    first_time: str = ""
    last_time: str = ""
    totals_checked: bool = False
    paid_in_matches: bool = False
    paid_out_matches: bool = False
    balance_breaks: int = 0
    break_wording: dict = field(default_factory=dict)
    group_breaks: int = 0
    group_break_wording: dict = field(default_factory=dict)
    notes: list = field(default_factory=list)

    @property
    def passed(self):
        return self.rows > 0 and self.totals_checked and self.paid_in_matches and self.paid_out_matches


def _group_breaks(ordered):
    """Balance check per completion time, tolerant of the order of rows that share a time.
    Returns (number of failing groups, details of the rows in failing groups)."""
    groups = [(g["balance"].iloc[0], g["balance"].iloc[-1], g["paid_in"].sum(), g["withdrawn"].sum(),
               g["details"].tolist()) for _, g in ordered.groupby("time", sort=False)]
    failing, details = 0, []
    for i in range(len(groups) - 1):
        first, last, money_in, money_out, rows = groups[i]
        older = groups[i + 1]
        expected = [b + money_in - money_out for b in (older[0], older[1])]
        if not any(abs(e - b) <= 0.01 for e in expected for b in (first, last)):
            failing += 1
            details += rows
    return failing, details


def validate(df, summary):
    v = Validation(rows=len(df))
    if df.empty:
        v.notes.append("No transaction rows were read.")
        return v
    v.first_time, v.last_time = str(df["time"].min()), str(df["time"].max())
    if summary:
        v.totals_checked = True
        v.paid_in_matches = abs(df["paid_in"].sum() - summary["paid_in"]) < 0.01
        v.paid_out_matches = abs(df["withdrawn"].sum() - summary["paid_out"]) < 0.01
    else:
        v.notes.append("Summary TOTAL row not found, so totals were not checked.")
    # balance continuity: newest first, so balance[i] = balance[i+1] + paid_in[i] - withdrawn[i]
    ordered = df.sort_values("time", ascending=False, kind="stable").reset_index(drop=True)
    expected = ordered["balance"].shift(-1) + ordered["paid_in"] - ordered["withdrawn"]
    broken = ((expected - ordered["balance"]).abs() > 0.01)
    broken.iloc[-1] = False  # the oldest row has nothing before it to compare with
    v.balance_breaks = int(broken.sum())
    wording = ordered.loc[broken, "details"].map(_wording)
    v.break_wording = wording.value_counts().to_dict()
    # Rows with the same completion time (a payment and its fee, for example) can appear in
    # either order, so also check the balance once per completion time.
    v.group_breaks, group_details = _group_breaks(ordered)
    v.group_break_wording = pd.Series(group_details).map(_wording).value_counts().to_dict() if group_details else {}
    return v


def compute_features(df):
    """Return (features dict with None where undefined, info dict)."""
    d = df.copy()
    d["ym"] = d["time"].dt.to_period("M")
    months = sorted(d["ym"].unique())
    use = months[1:-1] if len(months) >= 3 else months
    sub = d[d["ym"].isin(use)]
    n = len(use)

    def per_month(mask, col=None):
        s = sub[mask]
        g = s.groupby("ym")[col].sum() if col else s.groupby("ym").size()
        return g.reindex(use, fill_value=0)

    inflow = per_month(sub["kind"] == "income", "paid_in")
    outflow_total = sub.loc[~sub["kind"].isin(["savings_deposit"]), "withdrawn"].sum()
    mean_in = inflow.mean()
    f = {
        "avg_monthly_inflow": float(mean_in),
        "inflow_volatility": float(inflow.std(ddof=0) / mean_in) if mean_in > 0 else None,
        "outflow_to_inflow_ratio": float(outflow_total / inflow.sum()) if inflow.sum() > 0 else None,
        "fuliza_usage_frequency": float((sub["kind"] == "fuliza_draw").sum() / n),
        "savings_deposit_frequency": float((sub["kind"] == "savings_deposit").sum() / n),
        "bill_payment_consistency": float((per_month(sub["kind"] == "bill_payment") > 0).mean()),
        "account_age_months": float((d["time"].max() - d["time"].min()).days / 30.44),
        "transaction_count_monthly": float((sub["kind"] != "charge").sum() / n),
    }
    has_loans = bool(d["kind"].isin(["loan_repayment", "loan_disbursement", "fuliza_draw"]).any())
    f["loan_repayment_regularity"] = (
        float((per_month(sub["kind"] == "loan_repayment") > 0).mean()) if has_loans else None)
    info = {"months_in_statement": len(months), "months_used": n,
            "first_month": str(months[0]), "last_month": str(months[-1]),
            "row_kinds": d["kind"].value_counts().to_dict()}
    return {k: f[k] for k in FEATURES}, info


def features_for_scoring(features):
    """Replace undefined features with training averages; report which were replaced."""
    out, imputed = {}, []
    for k, v in features.items():
        if v is None:
            out[k] = TRAINING_MEANS[k]
            imputed.append(k)
        else:
            out[k] = round(v, 4)
    return out, imputed