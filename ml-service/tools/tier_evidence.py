"""Reproduces the tier, boundary, calibration and alert-threshold figures quoted in the report.
Run from ml-service after generate_data.py:  python tools/tier_evidence.py"""
import json
import numpy as np, pandas as pd, joblib
from scipy.stats import fisher_exact
from sklearn.model_selection import train_test_split

df = pd.read_csv("data/synthetic_training_data.csv")
X, y = df.drop(columns=["defaulted"]), df["defaulted"]
Xtr, Xtmp, ytr, ytmp = train_test_split(X, y, test_size=0.3, stratify=y, random_state=42)
Xva, Xte, yva, yte = train_test_split(Xtmp, ytmp, test_size=0.5, stratify=ytmp, random_state=42)
model = joblib.load("models/credit_model.pkl")
meta = json.load(open("models/model_meta.json"))
t1, t2, thr = meta["tier_1_cutoff"], meta["tier_2_cutoff"], meta["decision_threshold"]

def scores(a):
    return np.round((1 - model.predict_proba(a)[:, 1]) * 100, 1)

s_va, s_te = scores(Xva), scores(Xte)
s_all, y_all = np.r_[s_va, s_te], np.r_[yva.values, yte.values]

def tier_table(s, yy, label):
    print(f"\nObserved default rate by tier ({label}, n={len(s)}), cut-offs {t1} and {t2}")
    for name, mask in [("Tier 1", s >= t1), ("Tier 2", (s >= t2) & (s < t1)), ("Tier 3", s < t2)]:
        n, r = mask.sum(), yy[mask].mean()
        print(f"  {name}: n={n} ({n / len(s) * 100:.1f}%)  default {r * 100:.1f}%  (+/-{196 * np.sqrt(r * (1 - r) / n):.1f})")

tier_table(s_te, yte.values, "test")
tier_table(s_all, y_all, "validation + test")

print("\nPooled validation and test: default rate either side of each cut-off")
for lo1, hi1, lo2, hi2 in [(t1 - 2, t1 - 0.1, t1, t1 + 1.9), (t2 - 2, t2 - 0.1, t2, t2 + 1.9)]:
    a, b = (s_all >= lo1) & (s_all <= hi1), (s_all >= lo2) & (s_all <= hi2)
    da, db = y_all[a].sum(), y_all[b].sum()
    p = fisher_exact([[da, a.sum() - da], [db, b.sum() - db]])[1]
    print(f"  {lo1:.1f}-{hi1:.1f}: n={a.sum()} default {da / a.sum() * 100:.1f}% | "
          f"{lo2:.1f}-{hi2:.1f}: n={b.sum()} default {db / b.sum() * 100:.1f}% | Fisher p = {p:.2f}")

print("\nCalibration by 5-point score band (validation + test)")
bands = [0, 60, 65, 70, 75, 80, 85, 90, 95, 100.01]
cut = pd.cut(s_all, bands, right=False)
g = pd.DataFrame({"band": cut, "y": y_all, "s": s_all}).groupby("band", observed=True).agg(
    n=("y", "size"), observed=("y", "mean"), predicted=("s", lambda v: (100 - v).mean() / 100))
print((g.assign(observed=(g.observed * 100).round(1), predicted=(g.predicted * 100).round(1))).to_string())

print("\nAlert cut-off comparison (class 'default')")
for name, a, yy in [("validation", Xva, yva.values), ("test", Xte, yte.values)]:
    p = model.predict_proba(a)[:, 1]
    for t in (0.20, thr, 0.30):
        f = p >= t
        tp = (f & (yy == 1)).sum()
        pr, rc = tp / f.sum(), tp / yy.sum()
        print(f"  {name} cut-off {t:.2f}: flagged {f.mean() * 100:.1f}%  precision {pr * 100:.1f}%  "
              f"recall {rc * 100:.1f}%  F1 {2 * pr * rc / (pr + rc):.3f}")