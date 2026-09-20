from flask import Flask, Response, request
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST
)
import os
import socket
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status"]
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"]
)


@app.before_request
def start_timer():
    request.start_time = time.time()


@app.after_request
def record_metrics(response):
    if request.path not in ["/metrics", "/favicon.ico"]:
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.path,
            status=response.status_code
        ).inc()

        REQUEST_LATENCY.labels(
            method=request.method,
            endpoint=request.path
        ).observe(time.time() - request.start_time)

    return response


@app.route("/")
def home():
    return {
        "application": "DevOps GCP Architecture POC",
        "status": "running",
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "hostname": socket.gethostname()
    }


@app.route("/health")
def health():
    return {
        "status": "healthy"
    }


@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)