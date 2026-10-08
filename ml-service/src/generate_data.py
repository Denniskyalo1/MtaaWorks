import numpy as np
import pandas as pd

np.random.seed(42)
N = 5000  # synthetic borrowers

def generate_dataset(n=N):
    df = pd.DataFrame()

    
    reliability = np.random.beta(2, 2, n)

    df["avg_monthly_inflow"] = np.random.lognormal(mean=9.5, sigma=0.6, size=n)
    df["inflow_volatility"] = np.clip(np.random.normal(0.4, 0.15, n) - 0.2 * reliability, 0.02, 1.5)
    df["outflow_to_inflow_ratio"] = np.clip(np.random.normal(0.85, 0.15, n) - 0.15 * reliability, 0.2, 1.4)
    df["fuliza_usage_frequency"] = np.clip(np.random.poisson(4, n) * (1.5 - reliability), 0, None)
    df["loan_repayment_regularity"] = np.clip(np.random.normal(0.6, 0.2, n) + 0.3 * reliability, 0, 1)
    df["savings_deposit_frequency"] = np.clip(np.random.poisson(2, n) * (0.5 + reliability), 0, None)
    df["bill_payment_consistency"] = np.clip(np.random.normal(0.65, 0.2, n) + 0.25 * reliability, 0, 1)
    df["account_age_months"] = np.random.randint(3, 60, n)
    df["transaction_count_monthly"] = np.random.poisson(35, n)

   
    default_logit = (
        0.1
        + 1.6 * df["inflow_volatility"]
        + 1.3 * df["outflow_to_inflow_ratio"]
        + 0.08 * df["fuliza_usage_frequency"]
        - 2.8 * df["loan_repayment_regularity"]
        - 1.6 * df["bill_payment_consistency"]
        - 0.01 * df["account_age_months"]
        + np.random.normal(0, 0.3, n)  # irreducible noise
    )
    default_prob = 1 / (1 + np.exp(-default_logit))
    df["defaulted"] = np.random.binomial(1, default_prob)

    return df

if __name__ == "__main__":
    df = generate_dataset()
    df.to_csv("data/synthetic_training_data.csv", index=False)
    print(df["defaulted"].value_counts(normalize=True))