from fastapi.testclient import TestClient
from src.api import app

client = TestClient(app)


def test_score_rejects_missing_key():
    r = client.post("/score", json={}, headers={"X-Service-Key": ""})
    assert r.status_code == 401


def test_score_rejects_wrong_key():
    r = client.post("/score", json={}, headers={"X-Service-Key": "wrong"})
    assert r.status_code == 401


def test_score_statement_rejects_wrong_key():
    r = client.post("/score-statement", headers={"X-Service-Key": "wrong"})
    assert r.status_code == 401


def test_health_needs_no_key():
    r = client.get("/health", headers={"X-Service-Key": ""})
    assert r.status_code == 200