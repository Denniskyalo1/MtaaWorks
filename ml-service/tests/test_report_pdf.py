"""Tests for the credit report PDF. Run from the ml-service folder:   python -m pytest tests -v"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
pytest.importorskip("reportlab")
pymupdf = pytest.importorskip("pymupdf")

from fastapi.testclient import TestClient

import src.api as api

client = TestClient(api.app)

PAYLOAD = {
    "name": "Dennis K.", "score": 90.1, "tier": "Tier 1", "high_risk": False, "scored_at": "15 Oct 2026",
    "model_version": "1.0.0", "code": "MWR-ABCD-EFGH-JKLM", "hash": "0123456789abcdef", "issued_at": "26 Oct 2026",
    "valid_until": "25 Nov 2026", "verify_url": "http://localhost:5000/?verify=MWR-ABCD-EFGH-JKLM",
    "drivers": [{"label": "Bill payment consistency", "helping": True}, {"label": "Outflow to inflow ratio", "helping": False}],
}


def text_of(pdf_bytes):
    doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    return doc, "\n".join(page.get_text() for page in doc)


def test_report_is_a_one_page_pdf_with_the_code_and_score():  # TC-S39
    r = client.post("/report", json=PAYLOAD)
    assert r.status_code == 200 and r.headers["content-type"] == "application/pdf" and r.content.startswith(b"%PDF")
    doc, text = text_of(r.content)
    assert len(doc) == 1
    for expected in ["MWR-ABCD-EFGH-JKLM", "90.1", "Tier 1", "Dennis K.", "Bill payment consistency", "helping", "holding back", "0123456789abcdef"]:
        assert expected in text


def test_report_without_drivers_says_so():  # TC-S40
    body = dict(PAYLOAD, drivers=None)
    r = client.post("/report", json=body)
    _, text = text_of(r.content)
    assert "Bill payment consistency" not in text and "chose not to include" in text


def test_high_risk_flag_is_shown():  # TC-S41
    r = client.post("/report", json=dict(PAYLOAD, high_risk=True, tier="Tier 3"))
    _, text = text_of(r.content)
    assert "flagged high risk" in text


def test_report_needs_the_service_key():  # TC-S42
    assert client.post("/report", json=PAYLOAD, headers={"X-Service-Key": ""}).status_code == 401


def test_report_rejects_a_score_out_of_range():  # TC-S43
    assert client.post("/report", json=dict(PAYLOAD, score=140)).status_code == 422
