# MtaaWorks API

MtaaWorks turns a borrower's consented M-Pesa statement into a credit risk score, a risk tier and a short explanation. This API serves the MtaaWorks mobile app.

> **Status: version 0.1, borrower features only.** Lender access is planned for a later version (see the end of this page). Edit this text whenever the behaviour changes.

## How it works

1. A borrower registers and logs in.
2. The borrower gives consent for their M-Pesa data to be analysed.
3. The borrower uploads their password-protected M-Pesa statement (PDF) together with its password.
4. The backend sends the statement to the MtaaWorks scoring service, which reads it, checks it and returns a score.
5. The borrower views the score, the tier and the main factors behind it.

## Base URL and format

- Requests and responses use JSON, except the statement upload, which uses `multipart/form-data`.
- Send `Accept: application/json` with every request.

## Authentication

The API uses bearer tokens (Laravel Sanctum). Register or log in to receive a token, then send it with every other request:

```
Authorization: Bearer <token>
```

A token is tied to one user and stops working after logout.

## Consent and privacy

- A statement can only be uploaded after the borrower has given consent. Without active consent the upload is refused.
- The statement file and its password are used once, in memory, to produce the score. **They are not stored and not logged.**
- Only summary figures are kept: nine behavioural features, the score, the tier and validation counts. Individual transactions, names and phone numbers from the statement are never stored.
- A borrower can withdraw consent at any time.

## Reading a score

| Field | Meaning |
|---|---|
| `score` | From 0 to 100. Higher means lower risk. It equals 100 x (1 - probability of default). |
| `tier` | Tier 1 is the lowest risk and Tier 3 the highest. |
| `top_drivers` | The three features that moved the score most, each marked as increasing or reducing risk. |
| `out_of_range_features` | Features whose values lie outside the range the model was trained on. Treat the score as less reliable when this list is not empty. |
| `imputed_features` | Features that could not be computed from the statement and were replaced by an average. |

**Important:** the scoring model was trained and tested on synthetic data. A score demonstrates how the system works. It is not a lending decision and must not be presented as one.

## Errors

| Status | Meaning |
|---|---|
| 401 | Missing or invalid token |
| 403 | Not allowed, for example consent has not been given |
| 422 | Validation failed, for example the statement does not match its own totals or covers too little history |
| 400 | The statement password is wrong, or the file is not a readable statement |
| 413 | The file is too large |

Validation errors list each failing field.

## Limits and timing

- Scoring a long statement can take one to two minutes. Use a long request timeout.
- A statement needs at least three full calendar months of history.
- Statements must be PDF files of up to 25 MB.

## Not yet available

Lender accounts, access requests and portfolio analytics are planned for a later version.