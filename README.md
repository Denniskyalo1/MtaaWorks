# MtaaWorks

Machine learning credit scoring service for informal-sector borrowers in Kenya (final-year project, Strathmore University).

## Status
Implemented: synthetic data generator, model training and evaluation, FastAPI scoring service, automated tests.
Not yet implemented: M-Pesa statement parser, Laravel backend, Flutter app and web portal.

## Important limitation
The model is trained and tested on a synthetic dataset. Its results show that the pipeline works; they do not show performance on real borrowers.

## Setup (Windows, Python 3.14)
python -m venv venv
venv\Scripts\Activate.ps1
python -m pip install -r ml-service/requirements.txt

## Run (from the ml-service folder)
python src\generate_data.py
python src\train.py
python -m uvicorn src.api:app --port 8000
python -m pytest tests -v

The scoring service documentation is at http://127.0.0.1:8000/docs.
The generated data, model files and figures are not committed because they can be regenerated.
