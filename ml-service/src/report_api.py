"""The /report endpoint. It is included from api.py with the service-key check passed in."""
from typing import Optional

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field

from src.report_pdf import build_report_pdf


class ReportDriver(BaseModel):
    label: str = Field(max_length=80)
    helping: bool


class ReportRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    score: float = Field(ge=0, le=100)
    tier: str = Field(max_length=20)
    high_risk: bool
    scored_at: str = Field(max_length=40)
    model_version: str = Field(max_length=20)
    code: str = Field(min_length=6, max_length=30)
    hash: str = Field(max_length=64)
    issued_at: str = Field(max_length=40)
    valid_until: str = Field(max_length=40)
    verify_url: str = Field(max_length=300)
    drivers: Optional[list[ReportDriver]] = Field(default=None, max_length=10)


def make_router(require_service_key):
    router = APIRouter()

    @router.post("/report", dependencies=[Depends(require_service_key)], summary="Build a credit report PDF")
    def report(req: ReportRequest):
        pdf = build_report_pdf(req.model_dump())
        return Response(content=pdf, media_type="application/pdf")

    return router
