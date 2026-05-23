# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1 — builder: install Python deps + any build tools
# ============================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Build tools only in the builder layer — they don't ship in the final image
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


# ============================================================
# Stage 2 — runtime: slim base, non-root user, no build tools
# ============================================================
FROM python:3.12-slim AS runtime

# Create non-root user
RUN groupadd --system --gid 1000 app && \
    useradd --system --uid 1000 --gid app --home-dir /home/app --create-home app

# Copy installed packages from builder
COPY --from=builder --chown=app:app /root/.local /home/app/.local

ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY --chown=app:app app/ ./

USER app

EXPOSE 8000

# Python-based healthcheck — no curl/wget needed in the image
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; \
        sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health/', timeout=2).status==200 else 1)" \
    || exit 1

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
