"""Baseline comparison for the MtaaWorks credit model.

Rebuilds the exact train / validation / test split used by train.py
(same file, same proportions, same random_state) and compares the saved,
calibrated model with two simple baselines on the same held-out test set:

  1. Majority class: always predicts "no default" (probability = training
     default rate). This is the "no skill" reference.
  2. One-feature rule: logistic regression on loan_repayment_regularity
     alone, the feature with the largest true effect in the generator.
     Its decision threshold is tuned on the validation set in the same way
     as the final model's.

Nothing in models/ is written or changed. Run from the ml-service folder:
    python src/baseline.py
"""

import json

import joblib
import numpy as np
import pandas as pd
from sklearn.dummy import DummyClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, brier_score_loss, f1_score,
                             precision_score, recall_score, roc_auc_score)
from sklearn.model_selection import train_test_split

DATA = "data/synthetic_training_data.csv"
ONE_FEATURE = "loan_repayment_regularity"

# Same split as train.py
df = pd.read_csv(DATA)
X = df.drop(columns=["defaulted"])
y = df["defaulted"]
X_train, X_temp, y_train, y_temp = train_test_split(
    X, y, test_size=0.3, stratify=y, random_state=42
)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, stratify=y_temp, random_state=42
)
print(f"Train {len(X_train)}, validation {len(X_val)}, test {len(X_test)} "
      f"(test defaulters: {int(y_test.sum())})")


def tune_threshold(y_true, proba):
    """Threshold with the highest F1 on the validation set, as in train.py."""
    thresholds = np.arange(0.01, 1.00, 0.01)
    f1s = [f1_score(y_true, (proba >= t).astype(int), zero_division=0)
           for t in thresholds]
    return float(thresholds[int(np.argmax(f1s))])


def evaluate(name, proba, threshold):
    pred = (proba >= threshold).astype(int)
    auc = roc_auc_score(y_test, proba) if len(np.unique(proba)) > 1 else 0.5
    return {
        "Model": name,
        "Threshold": round(threshold, 2),
        "AUC-ROC": round(auc, 4),
        "Brier": round(brier_score_loss(y_test, proba), 4),
        "Accuracy": round(accuracy_score(y_test, pred), 4),
        "Precision (default)": round(precision_score(y_test, pred, zero_division=0), 4),
        "Recall (default)": round(recall_score(y_test, pred, zero_division=0), 4),
        "F1 (default)": round(f1_score(y_test, pred, zero_division=0), 4),
    }


rows = []

# 1. Majority class
dummy = DummyClassifier(strategy="prior").fit(X_train, y_train)
rows.append(evaluate("Majority class (always 'no default')",
                     dummy.predict_proba(X_test)[:, 1], 0.5))

# 2. One-feature logistic regression
one = LogisticRegression(max_iter=1000).fit(X_train[[ONE_FEATURE]], y_train)
one_threshold = tune_threshold(y_val, one.predict_proba(X_val[[ONE_FEATURE]])[:, 1])
rows.append(evaluate(f"One feature ({ONE_FEATURE})",
                     one.predict_proba(X_test[[ONE_FEATURE]])[:, 1], one_threshold))

# 3. The saved final model, with its saved threshold
model = joblib.load("models/credit_model.pkl")
with open("models/model_meta.json") as fh:
    meta = json.load(fh)
rows.append(evaluate(f"Final model ({meta['model_name']}, calibrated)",
                     model.predict_proba(X_test)[:, 1],
                     float(meta["decision_threshold"])))

table = pd.DataFrame(rows)
pd.set_option("display.width", 200)
print("\nBaseline comparison on the held-out test set:")
print(table.to_string(index=False))

import os
os.makedirs("figures", exist_ok=True)

table.to_csv("figures/baseline_comparison.csv", index=False)
print("\nSaved to figures/baseline_comparison.csv")
