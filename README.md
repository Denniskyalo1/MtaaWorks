# MtaaWorks
Machine learning credit scoring for informal-sector borrowers in Kenya (final-year project, Strathmore University). A borrower consents to share an M-Pesa statement, receives a score and risk tier, and approves lenders one at a time to view it.
## Status
Implemented: synthetic data generator, model training and evaluation, FastAPI scoring service, statement parser, Laravel backend (accounts, consent, roles, scoring, lender access), Flutter borrower app, Flutter lender web portal.
Not implemented: Daraja statement retrieval, name matching on upload, report export, portfolio analytics, a lender logout route that revokes the token.
## Important limitation
The model is trained and tested on synthetic data. The results show that the pipeline works. They do not show performance on real borrowers.
## Folders
ml-service (Python, FastAPI), laravel (backend API), mobile (borrower app), mobile/mtaaworks_lender_portal (lender portal).
## Run (Windows)
1. ml-service: create a venv, pip install -r requirements.txt, python src\generate_data.py, python src\train.py, python -m uvicorn src.api:app --port 8000, python -m pytest tests.
2. laravel: composer install, copy .env.example to .env, php artisan key:generate, php artisan migrate, php artisan serve --port=8001, php artisan test.
3. mobile: flutter pub get, flutter run (emulator). Lender portal: flutter run -d chrome from mobile/mtaaworks_lender_portal.
