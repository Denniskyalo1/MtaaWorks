import numpy as np, pandas as pd, joblib
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, roc_curve

df = pd.read_csv("data/synthetic_training_data.csv")
X, y = df.drop(columns=["defaulted"]), df["defaulted"]
Xtr, Xtmp, ytr, ytmp = train_test_split(X, y, test_size=0.3, stratify=y, random_state=42)
Xva, Xte, yva, yte = train_test_split(Xtmp, ytmp, test_size=0.5, stratify=ytmp, random_state=42)
m = joblib.load("models/credit_model.pkl")
ptr, pva, pte = (m.predict_proba(a)[:, 1] for a in (Xtr, Xva, Xte))

auc = roc_auc_score(yte, pte)
fpr, tpr, _ = roc_curve(yte, pte)
rng, yt, bs = np.random.default_rng(0), yte.values, []
for _ in range(2000):
    i = rng.integers(0, len(yt), len(yt))
    if yt[i].min() != yt[i].max():
        bs.append(roc_auc_score(yt[i], pte[i]))
lo, hi = np.percentile(bs, [2.5, 97.5])

def psi(a, b, bins=10):
    q = np.percentile(a, np.linspace(0, 100, bins + 1)); q[0], q[-1] = -1e9, 1e9
    pa = np.clip(np.histogram(a, q)[0] / len(a), 1e-4, None)
    pb = np.clip(np.histogram(b, q)[0] / len(b), 1e-4, None)
    return float(((pb - pa) * np.log(pb / pa)).sum())

print(f"AUC train {roc_auc_score(ytr, ptr):.3f} | val {roc_auc_score(yva, pva):.3f} | test {auc:.3f}")
print(f"Gini {2 * auc - 1:.3f}  (95% CI {2 * lo - 1:.2f} to {2 * hi - 1:.2f})")
print(f"KS {(tpr - fpr).max():.3f}")
print(f"PSI train->test {psi((1 - ptr) * 100, (1 - pte) * 100):.3f}")