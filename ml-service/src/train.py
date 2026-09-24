import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold, cross_val_score
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import (
    classification_report, roc_auc_score, confusion_matrix,
    brier_score_loss, accuracy_score, f1_score
)
import joblib
import os
os.makedirs("models", exist_ok=True)

# 1. Load the data we generated
df = pd.read_csv("data/synthetic_training_data.csv")
X = df.drop(columns=["defaulted"])
y = df["defaulted"]

# 2. Split into train / validation / test (70 / 15 / 15), preserving the
#    default-rate proportion in each split (stratified sampling per Ch.3.2.2)
X_train, X_temp, y_train, y_temp = train_test_split(
    X, y, test_size=0.3, stratify=y, random_state=42
)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, stratify=y_temp, random_state=42
)
print(f"Train size: {len(X_train)}, Validation size: {len(X_val)}, Test size: {len(X_test)}")

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

# 3 & 4. Three candidate algorithms (Ch.3.2.3 documents Random Forest and
# Gradient Boosting; Logistic Regression is added here as a correctly-
# specified baseline since the synthetic generator builds default
# probability as a linear combination of features through a sigmoid).
# Each gets its own SMOTE-inside-pipeline (SMOTE re-runs fresh per CV fold,
# not before the split, so there's no leakage into validation/test folds).

# --- Candidate A: Random Forest ---
# class_weight is included as a grid option here (Ch.3.2.3: "class weights
# will be employed during training to further reduce any remaining class
# imbalance") stacked on top of the SMOTE oversampling from 3.2.2.
rf_pipeline = ImbPipeline([
    ("smote", SMOTE(random_state=42)),
    ("classifier", RandomForestClassifier(random_state=42)),
])
rf_param_grid = {
    "classifier__n_estimators": [100, 200, 300],
    "classifier__max_depth": [3, 5, None],
    "classifier__class_weight": [None, "balanced"],
}
rf_grid = GridSearchCV(rf_pipeline, rf_param_grid, scoring="f1", cv=cv, n_jobs=-1)
rf_grid.fit(X_train, y_train)

# --- Candidate B: Gradient Boosting ---
# Note: sklearn's GradientBoostingClassifier has no class_weight parameter,
# so this candidate relies on SMOTE alone for imbalance correction.
gb_pipeline = ImbPipeline([
    ("smote", SMOTE(random_state=42)),
    ("classifier", GradientBoostingClassifier(random_state=42)),
])
gb_param_grid = {
    "classifier__n_estimators": [100, 200, 300],
    "classifier__max_depth": [2, 3, 4],
    "classifier__learning_rate": [0.01, 0.05, 0.1],
}
gb_grid = GridSearchCV(gb_pipeline, gb_param_grid, scoring="f1", cv=cv, n_jobs=-1)
gb_grid.fit(X_train, y_train)

# --- Candidate C: Logistic Regression ---
# The synthetic generator builds default probability as a linear
# combination of features passed through a sigmoid — exactly logistic
# regression's form. Included as a correctly-specified baseline: if it
# outperforms the tree ensembles here, that's expected given the data's
# true structure, not a sign the ensembles are broken. Scaling is added
# since LR is scale-sensitive, unlike the tree-based candidates.
lr_pipeline = ImbPipeline([
    ("smote", SMOTE(random_state=42)),
    ("scaler", StandardScaler()),
    ("classifier", LogisticRegression(max_iter=1000, random_state=42)),
])
lr_param_grid = {
    "classifier__C": [0.01, 0.1, 1.0, 10.0],
    "classifier__class_weight": [None, "balanced"],
}
lr_grid = GridSearchCV(lr_pipeline, lr_param_grid, scoring="f1", cv=cv, n_jobs=-1)
lr_grid.fit(X_train, y_train)

# 5. Select the winner by F1-score on the VALIDATION set (Ch.3.2.3:
# "the model with the best F1-score on the validation set will be chosen").
rf_val_f1 = f1_score(y_val, rf_grid.best_estimator_.predict(X_val))
gb_val_f1 = f1_score(y_val, gb_grid.best_estimator_.predict(X_val))
lr_val_f1 = f1_score(y_val, lr_grid.best_estimator_.predict(X_val))

print(f"\nRandom Forest — best params: {rf_grid.best_params_}, validation F1: {rf_val_f1:.4f}")
print(f"Gradient Boosting — best params: {gb_grid.best_params_}, validation F1: {gb_val_f1:.4f}")
print(f"Logistic Regression — best params: {lr_grid.best_params_}, validation F1: {lr_val_f1:.4f}")

candidates = {
    "Random Forest": (rf_val_f1, rf_grid.best_estimator_),
    "Gradient Boosting": (gb_val_f1, gb_grid.best_estimator_),
    "Logistic Regression": (lr_val_f1, lr_grid.best_estimator_),
}
winner_name = max(candidates, key=lambda name: candidates[name][0])
best_model = candidates[winner_name][1]

print(f"\nSelected model: {winner_name}")

# Feature importance (tree models only) — sanity-checks whether the model
# is reasoning off the features it should be (e.g. repayment regularity,
# bill consistency) rather than something spurious.
if winner_name in ("Random Forest", "Gradient Boosting"):
    importances = best_model.named_steps["classifier"].feature_importances_
    importance_df = pd.DataFrame({
        "feature": X.columns,
        "importance": importances
    }).sort_values("importance", ascending=False).reset_index(drop=True)
    print(f"\nFeature importances ({winner_name}):")
    print(importance_df.to_string(index=False))
    print("(note: impurity-based importance is biased toward high-cardinality")
    print(" features like account_age_months — treat rankings with some caution)")

# Coefficient comparison against the generator's true logit coefficients —
# printed regardless of which model wins, since it's a validation check on
# whether the pipeline recovers the true underlying signal, not just a
# property of the winning model.
true_coefficients = {
    "inflow_volatility": 1.6,
    "outflow_to_inflow_ratio": 1.3,
    "fuliza_usage_frequency": 0.08,
    "loan_repayment_regularity": -2.8,
    "bill_payment_consistency": -1.6,
    "account_age_months": -0.01,
    "avg_monthly_inflow": 0.0,
    "savings_deposit_frequency": 0.0,
    "transaction_count_monthly": 0.0,
}
lr_coefs = lr_grid.best_estimator_.named_steps["classifier"].coef_[0]
coef_df = pd.DataFrame({
    "feature": X.columns,
    "true_coefficient": [true_coefficients[f] for f in X.columns],
    "fitted_lr_coefficient": lr_coefs,
}).sort_values("true_coefficient", key=abs, ascending=False).reset_index(drop=True)
print("\nLogistic Regression coefficients vs. true generator coefficients:")
print("(note: fitted coefficients are on STANDARDIZED features, so magnitudes")
print(" aren't directly comparable to the true values — compare SIGN and")
print(" RELATIVE ranking, not raw magnitude)")
print(coef_df.to_string(index=False))

# 6. Stability check (Ch.3.2.4): stratified k-fold cross-validation on the
# winning pipeline, reported separately from the hyperparameter search above,
# to check how stable performance is across different data partitions.
stability_scores = cross_val_score(best_model, X_train, y_train, cv=cv, scoring="f1", n_jobs=-1)
print(f"\nStability check ({winner_name}, 5-fold stratified F1): "
      f"{stability_scores.mean():.4f} ± {stability_scores.std():.4f}")

# 7. Calibrate the model's probability outputs
calibrated_model = CalibratedClassifierCV(best_model, method="isotonic", cv=5)
calibrated_model.fit(X_train, y_train)

# 7b. Threshold tuning (Ch.3.2.3: "preference for balanced precision and
# recall... instead of raw accuracy"). The default 0.5 cutoff is unsuitable
# for an ~18% base rate — it collapses recall on the minority class even
# when the model's ranking ability (AUC-ROC) is sound. Sweep thresholds on
# the VALIDATION set and pick the one that maximizes F1; the test set stays
# untouched until the final evaluation below.
val_proba_for_threshold = calibrated_model.predict_proba(X_val)[:, 1]
thresholds = np.arange(0.01, 1.00, 0.01)
threshold_f1s = [
    f1_score(y_val, (val_proba_for_threshold >= t).astype(int))
    for t in thresholds
]
best_threshold = thresholds[np.argmax(threshold_f1s)]
print(f"\nTuned decision threshold (max F1 on validation set): {best_threshold:.2f} "
      f"(validation F1 at this threshold: {max(threshold_f1s):.4f})")

# 8. Evaluate on the untouched test set — this is the honest grade
y_proba = calibrated_model.predict_proba(X_test)[:, 1]
y_pred = (y_proba >= best_threshold).astype(int)

print("\n--- Evaluation on test set ---")
print(f"Model: {winner_name}")
print(f"Decision threshold: {best_threshold:.2f} (tuned on validation set, not 0.5)")
print("Accuracy:", accuracy_score(y_test, y_pred))
print(classification_report(y_test, y_pred))
print("AUC-ROC:", roc_auc_score(y_test, y_proba))
print("Brier score (lower is better):", brier_score_loss(y_test, y_proba))
print("Confusion matrix:\n", confusion_matrix(y_test, y_pred))

# 9. Save the trained model for later use
joblib.dump(calibrated_model, "models/credit_model.pkl")
print("\nModel saved to models/credit_model.pkl")

# 10. Convert calibrated probabilities into Tier 1/2/3, using the
#     VALIDATION set to set cutoffs (test set stays untouched for final grading)
val_proba = calibrated_model.predict_proba(X_val)[:, 1]
val_scores = (1 - val_proba) * 100  # higher score = safer

tier_1_cutoff = np.percentile(val_scores, 66)
tier_2_cutoff = np.percentile(val_scores, 33)
print(f"\nTier 1 (safest): score >= {tier_1_cutoff:.1f}")
print(f"Tier 2: {tier_2_cutoff:.1f} <= score < {tier_1_cutoff:.1f}")
print(f"Tier 3 (riskiest): score < {tier_2_cutoff:.1f}")

# Sanity check: what's the REAL observed default rate inside each tier,
# measured on the untouched test set? This is the number you'd show a lender.
test_scores = (1 - y_proba) * 100
test_results = pd.DataFrame({"score": test_scores, "actual_default": y_test.values})

def assign_tier(score):
    if score >= tier_1_cutoff: return "Tier 1"
    elif score >= tier_2_cutoff: return "Tier 2"
    else: return "Tier 3"

test_results["tier"] = test_results["score"].apply(assign_tier)
print("\nObserved default rate by tier (test set):")
print(test_results.groupby("tier")["actual_default"].agg(["mean", "count"]))