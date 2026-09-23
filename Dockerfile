FROM python:3.12-slim AS builder

WORKDIR /build

RUN python -m venv /opt/venv

COPY requirements.txt .

# pip is unused at runtime; stripping it removes its CVEs from the shipped image
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt \
    && /opt/venv/bin/pip uninstall -y pip


FROM python:3.12-slim AS runtime

# the base image ships its own pip alongside the venv's; both must go
RUN python -m pip uninstall -y pip \
    && useradd --create-home --uid 10001 appuser

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser run.py ./

USER appuser
EXPOSE 8000

# stdlib probe: python:3.12-slim ships no curl/wget
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/', timeout=2)"]

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "run:app"]