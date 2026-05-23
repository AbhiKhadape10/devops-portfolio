"""Tests for the FastAPI demo app."""
from fastapi.testclient import TestClient

from app import app

client = TestClient(app)


def test_root() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "devops-demo"


def test_health_endpoint_returns_ok() -> None:
    response = client.get("/health/")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readiness_without_bucket_returns_503() -> None:
    # No S3_BUCKET configured in tests by default
    response = client.get("/health/ready")
    assert response.status_code == 503


def test_get_item_without_bucket_returns_503() -> None:
    response = client.get("/items/abc")
    assert response.status_code == 503
