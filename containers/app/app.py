"""Minimal FastAPI app for the container demo."""
import json
import os

import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException

app = FastAPI(
    title="DevOps Demo App",
    version="1.0.0",
    description="A minimal FastAPI service used to demonstrate container + K8s patterns.",
)

BUCKET = os.getenv("S3_BUCKET", "")
s3 = boto3.client("s3") if BUCKET else None


@app.get("/")
def root() -> dict:
    """Service identifier."""
    return {"service": "devops-demo", "version": app.version}


@app.get("/health/")
def health() -> dict:
    """Liveness probe — checks only that the process is responding.

    Critically, this does NOT check external dependencies. A failed liveness
    probe causes the pod to be restarted, which won't help if the dependency
    (e.g. S3) is the actual problem.
    """
    return {"status": "ok"}


@app.get("/health/ready")
def ready() -> dict:
    """Readiness probe — checks dependencies the app needs to serve traffic.

    A failed readiness probe removes the pod from the Service's endpoints,
    so it stops receiving traffic. The pod stays alive (no restart loop).
    """
    if not BUCKET:
        raise HTTPException(status_code=503, detail="S3_BUCKET not configured")
    try:
        s3.head_bucket(Bucket=BUCKET)
        return {"status": "ready", "bucket": BUCKET}
    except ClientError as exc:
        raise HTTPException(status_code=503, detail=f"S3 unreachable: {exc}") from exc


@app.get("/items/{item_id}")
def get_item(item_id: str) -> dict:
    """Fetch a JSON item from S3."""
    if not BUCKET:
        raise HTTPException(status_code=503, detail="Storage not configured")
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=f"items/{item_id}.json")
        return json.loads(obj["Body"].read())
    except s3.exceptions.NoSuchKey as exc:
        raise HTTPException(status_code=404, detail="Item not found") from exc
