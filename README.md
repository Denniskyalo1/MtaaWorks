# MtaaWorks

Machine learning credit scoring for informal-sector borrowers in Kenya (final-year project, Strathmore University).

A borrower consents to share a password-protected M-Pesa statement, receives a score out of 100 and a risk tier (Tier 1 is the strongest) with the main reasons behind it, and then chooses which lender may see it. A lender sees only what the borrower approved, for 30 days.

**Important limitation.** The model was trained and tested on 5,000 *synthetic* borrower records, because no real labelled M-Pesa data was available. The results show that the pipeline works. They do not show how accurate the scores are for real borrowers.

## What is in this repository

| Folder | What it is | Technology |
|---|---|---|
| `ml-service` | Scoring service: statement reader, model, credit report PDF | Python, FastAPI, scikit-learn |
| `laravel` | Backend API: accounts, consent, roles, lender access, loan requests, reports | Laravel 13, Sanctum, MySQL or SQLite |
| `mobile` | Borrower app (Android emulator or phone) | Flutter |
| `mobile/mtaaworks_lender_portal` | Lender and admin web portal | Flutter web |

```
Borrower app ──────┐                         ┌── Scoring service (port 8000)
                   ├──> Laravel API (8001) ──┤    reads the statement, scores it
Lender/admin portal┘                         └── Database
 (port 5000)
```

## What is implemented

- Synthetic data generator, model training and evaluation (Logistic Regression, AUC-ROC 0.746 on the held-out test set).
- Statement reader with a fast reader and a fall-back reader, a check of its output against the statement's own totals, scoring of up to six statements of one account together, and a check that the name and phone number on the statement match the signed-in borrower.
- Registration, sign-in (including Google), email and phone verification (also from the profile), a set-password option for Google sign-ups, consent, and account deletion.
- An optional rule that a borrower must verify their phone before scoring (`REQUIRE_PHONE_VERIFICATION`).
- Score history, a record of who opened the score, and scores stored encrypted.
- Lender requests, loan requests, and a lender portfolio summary.
- A PDF credit report with a verification code and QR code that a lender can check in the portal, and that the borrower can withdraw.
- Role checks (borrower, lender, admin) and server-side logout for every role.
- Admin pages in the portal: dashboard counts (no individual scores), adding lenders, suspending and reactivating them, a user list with masked phone and ID numbers, switching an account between borrower and admin, and an audit log of admin actions and lender score views.

Not implemented: automatic statement retrieval through the Daraja API, a hosted deployment with a real certificate, a usability study with real users, and an independent security review. Everything was tested on one development machine.

## What you need installed

| Tool | Version | Used for |
|---|---|---|
| Python | 3.11 or newer (tested on 3.13 and 3.14) | Scoring service |
| PHP | **8.4 or newer** (developed on 8.5) | Backend. `composer.lock` needs 8.4.1 or newer. |
| Composer | 2.x | Backend dependencies |
| Flutter | Dart SDK `^3.13.5` | Borrower app and lender portal |
| Android Studio emulator | any recent device | Running the borrower app |
| Chrome | any recent | Running the lender portal |
| MySQL | optional | The project was developed on MySQL, but SQLite works and needs nothing installed |

The commands below are for Windows PowerShell, which the project was developed on. The scoring service and the backend also run on Linux and macOS; use `source venv/bin/activate` instead of `venv\Scripts\Activate.ps1` and `export NAME=value` instead of `$env:NAME = "value"`.

## Run it from scratch

Use four terminals, one for each running part. Start from the repository root.

### 1. Scoring service (terminal 1)

```powershell
cd ml-service
python -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt

$env:SCORING_SERVICE_KEY = "choose-a-long-random-string"   # the backend must use the same value
$env:OPENBLAS_NUM_THREADS = "1"                            # avoids a memory error on some machines
python -m uvicorn src.api:app --host 127.0.0.1 --port 8000
```

Check it at http://127.0.0.1:8000/health (it should answer `status: ok`). Interactive documentation is at http://127.0.0.1:8000/docs.

The trained model files are already in `ml-service/models`, so nothing needs training. To retrain from scratch (optional, it overwrites the model files):

```powershell
python src\generate_data.py   # writes data\synthetic_training_data.csv
python src\train.py           # writes models\credit_model.pkl, lr_pipeline.pkl, model_meta.json
```

### 2. Backend (terminal 2)

```powershell
cd laravel
composer install
copy .env.example .env
php artisan key:generate
```

Open `laravel\.env` and set:

| Setting | Value |
|---|---|
| `SCORING_SERVICE_KEY` | The same string you used in step 1 |
| `APP_URL` | `http://127.0.0.1:8001`. Links in emails are built from it. |
| `ADMIN_EMAIL` and `ADMIN_PASSWORD` | The administrator account you want to create |
| `DB_CONNECTION` | Leave as `sqlite`, or switch to the MySQL block and create an empty database first |

Then create the tables and the administrator, and start the server:

```powershell
php artisan migrate        # answer "yes" if it offers to create the SQLite file
php artisan db:seed --class=AdminSeeder
php artisan serve --port=8001
```

Emails (verification, password reset, lender set-password links) are written to `laravel\storage\logs\laravel.log` because `MAIL_MAILER=log`. Open that file to read any link the system "sends". To receive real test emails instead, put Mailtrap or SMTP details in the `MAIL_` settings.

API documentation: http://localhost:8001/docs/api

### 3. Create a lender account (once)

Lenders cannot register themselves. The administrator creates them.

**In the portal (easiest).** Start the portal (step 4), sign in with `ADMIN_EMAIL` and `ADMIN_PASSWORD`, open **Lenders** and choose **Add lender**. The admin pages also let you suspend or reactivate a lender, manage roles under **Users**, and read the **Audit log**.

**Or through the API:**

```powershell
$login = Invoke-RestMethod -Method Post -Uri http://localhost:8001/api/login -ContentType "application/json" `
  -Body '{"email":"YOUR_ADMIN_EMAIL","password":"YOUR_ADMIN_PASSWORD"}'

Invoke-RestMethod -Method Post -Uri http://localhost:8001/api/admin/lenders `
  -Headers @{ Authorization = "Bearer $($login.access_token)"; Accept = "application/json" } `
  -ContentType "application/json" `
  -Body '{"name":"Demo SACCO","type":"sacco","licence_number":"DEMO-001","contact_name":"Demo Lender","contact_email":"lender@example.com"}'
```

`type` is one of `sacco`, `mfi` or `digital_lender`. The set-password link for the lender is written to `laravel\storage\logs\laravel.log`. It opens the lender portal (step 4), so start the portal first and then open the link.

### 4. Lender portal (terminal 3)

```powershell
cd mobile\mtaaworks_lender_portal
flutter pub get
flutter run -d chrome --web-port=5000
```

The port matters: the backend builds the links in lender emails and report QR codes from `PORTAL_URL`, which is `http://localhost:5000` by default. The portal talks to the backend at `http://127.0.0.1:8001/api` (`lib/api_service.dart`).

The same portal serves lenders and admins: after sign-in, an admin account opens the admin pages and a lender account opens the lender dashboard. Borrower accounts are refused and pointed to the mobile app.

### 5. Borrower app (terminal 4)

Start an Android emulator first, then:

```powershell
cd mobile
copy .env.example .env      # the file is required by the build; it can stay empty
flutter pub get
flutter run
```

The app reaches the backend at `http://10.0.2.2:8001/api`, which is how the Android emulator sees the computer's `localhost` (`lib/services/api_service.dart`). On a physical phone, change `baseUrl` in that file to `http://<your-computer's-LAN-IP>:8001/api` and keep both on the same Wi-Fi.

## Try it with a statement

Real M-Pesa statements contain personal data and are not in the repository. A synthetic statement generator is included. It makes a password-protected PDF of about six months of transactions with no real data:

```powershell
cd ml-service
venv\Scripts\Activate.ps1
python tools\make_synthetic_statement.py demo_statement.pdf 123456 2026-01-01 6 7
```

The arguments are the output file, the PDF password, the start date, the number of months and a random seed. Then, in the borrower app:

1. Register (the verification email is in `laravel\storage\logs\laravel.log`) and sign in.
2. Give consent when asked.
3. Choose **Score a statement**, select `demo_statement.pdf` and enter the password `123456`.
4. Read the score, tier and reasons. Try **Score history**, **Who viewed**, and **Credit report (PDF)**.
5. As the lender (portal), sign in, send an access request for the borrower's score, and approve it in the app; the lender can then open the score. Use **Verify report** in the portal with the code on the PDF report.

If `REQUIRE_PHONE_VERIFICATION=true` in `laravel\.env`, the borrower must verify their phone first (Profile → **Verify phone number**). With Africa's Talking in sandbox mode the code appears in the Africa's Talking simulator, not on a real phone, so leave the setting `false` when other people test the system.

A statement needs at least three full calendar months with no missing month in between, and it must be a PDF of up to 25 MB. The synthetic statement has no customer name, so the name check is skipped for it; on a real statement the name and phone number must match the signed-in borrower.

## Run the tests

Scoring service (68 tests, about 80 seconds):

```powershell
cd ml-service
python -m pytest tests
```

Backend (50 tests):

```powershell
cd laravel
New-Item mtaaworks_test -ItemType File   # empty SQLite file the tests use; it is not stored in the repository
php artisan test
```

The scoring-service result was checked on a fresh clone of this repository. The backend result (50 passed) was recorded on the development machine with PHP 8.5. The admin pages, the phone-verification rule and the set-password option for Google sign-ups have no automated tests yet; they were tested by hand through the portal and the app.

## HTTPS test (optional)

The system runs over HTTP on `localhost`. Encryption in transit was tested through a temporary tunnel, not on a hosted server:

```powershell
cloudflared tunnel --url http://localhost:8001
```

Use the `https://...trycloudflare.com` address it prints, with `/api` added, as `baseUrl` in `mobile/lib/services/api_service.dart`. Put the line back to `http://10.0.2.2:8001/api` afterwards, and keep `APP_DEBUG=false` in `laravel\.env`.

## Settings reference

| Where | Setting | Purpose |
|---|---|---|
| Scoring service (environment) | `SCORING_SERVICE_KEY` | Shared secret. Without it the service refuses every scoring request. |
| Scoring service (environment) | `STATEMENT_PARSER` | `auto` (default), `fast` or `reliable` |
| Scoring service (environment) | `STATEMENT_IDENTITY_CHECK` | Set to `off` to skip the name and phone check |
| `laravel\.env` | `SCORING_SERVICE_URL`, `SCORING_SERVICE_KEY` | Where the scoring service is and its shared secret |
| `laravel\.env` | `APP_URL` | The backend's own address; links in emails (such as email verification) are built from it |
| `laravel\.env` | `PORTAL_URL` | Where the lender portal runs (default `http://localhost:5000`) |
| `laravel\.env` | `REQUIRE_PHONE_VERIFICATION` | `true` refuses scoring until the borrower's phone is verified (default `false`). Run `php artisan config:clear` after changing it. |
| `laravel\.env` | `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Used by `AdminSeeder` |
| `laravel\.env` | `GOOGLE_CLIENT_ID` | Optional, for Google sign-in |
| `laravel\.env` | `AT_USERNAME`, `AT_API_KEY`, `AT_SANDBOX`, `AT_SENDER_ID` | Optional, SMS for phone verification (Africa's Talking) |
| `mobile\.env` | `GOOGLE_CLIENT_ID` | Optional, for Google sign-in |

Do not commit `.env` files. Only the `.env.example` files are stored in the repository.

## Troubleshooting

| Problem | Fix |
|---|---|
| The scoring service stops with a memory allocation (OpenBLAS) error | Set `$env:OPENBLAS_NUM_THREADS = "1"` before starting it, and close other memory-heavy programs |
| `composer install` says the lock file is not compatible | PHP is older than 8.4. Install PHP 8.4 or newer. |
| Scoring returns "The scoring service is unavailable" | The scoring service is not running, or `SCORING_SERVICE_KEY` differs between the two |
| `php artisan test` says the database file does not exist | Create the empty file: `New-Item laravel\mtaaworks_test -ItemType File` |
| `flutter run` cannot find `.env` | Copy `mobile\.env.example` to `mobile\.env` |
| The borrower app shows "route could not be found" | `baseUrl` in `lib/services/api_service.dart` is missing `/api` at the end |
| The borrower app cannot reach the backend on a phone | `10.0.2.2` only works in the emulator. Use the computer's LAN address. |
| A lender's set-password link does not open | The portal must be running on port 5000 (or `PORTAL_URL` changed to match) |
| An email verification link points to `10.0.2.2` and does not open | Set `APP_URL=http://127.0.0.1:8001` in `laravel\.env`, run `php artisan config:clear`, and request a new link. Old emails keep the old link. |
| `php artisan serve` says port 8000 or 8001 is forbidden | Windows sometimes reserves ports. Use another port (for example `--port=8002` for the scoring service) and update `SCORING_SERVICE_URL` in `laravel\.env` to match. |
| A lender cannot sign in: "This lender account is suspended" | An admin suspended the lender. Reactivate it in the portal under **Lenders**. |
| The admin account cannot sign in to the portal | Run `php artisan db:seed --class=AdminSeeder` after setting `ADMIN_EMAIL` and `ADMIN_PASSWORD`, then run `php artisan migrate` if the `audit_logs` table is missing. |

## Repository notes

- Commit `7738aa0` removed many files by mistake and the next commit restored them, so the history shows both.
- `ml-service/models` holds the trained models used in the report (`model_meta.json` records the model version and metrics). `ml-service/data` is empty until you generate data.
