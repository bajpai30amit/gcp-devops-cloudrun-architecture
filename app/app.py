from flask import Flask, Response, request

from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST
)

from pymongo import MongoClient
from pymongo.errors import PyMongoError

import os
import socket
import time


app = Flask(__name__)


# ============================================================
# MongoDB Configuration
# ============================================================

MONGODB_URI = os.getenv("MONGODB_URI")

mongo_client = None

if MONGODB_URI:
    mongo_client = MongoClient(
        MONGODB_URI,
        serverSelectionTimeoutMS=5000
    )


# ============================================================
# Prometheus Metrics
# ============================================================

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

    # Do not count Prometheus scraping or browser favicon requests
    if request.path not in ["/metrics", "/favicon.ico"]:

        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.path,
            status=response.status_code
        ).inc()

        REQUEST_LATENCY.labels(
            method=request.method,
            endpoint=request.path
        ).observe(
            time.time() - request.start_time
        )

    return response


# ============================================================
# Application Endpoints
# ============================================================

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


# ============================================================
# MongoDB Health Check
# ============================================================

@app.route("/db-health")
def db_health():

    if not mongo_client:

        app.logger.error(
            "MongoDB connection failed: MONGODB_URI is not configured"
        )

        return {
            "database": "mongodb",
            "status": "configuration_missing"
        }, 500

    try:

        mongo_client.admin.command("ping")

        return {
            "database": "mongodb",
            "status": "connected"
        }

    except PyMongoError as e:

        # Log the actual MongoDB error to Cloud Logging.
        # Do NOT return the internal exception to the client.
        app.logger.error(
            "MongoDB connection failed: %s",
            str(e)
        )

        return {
            "database": "mongodb",
            "status": "connection_failed"
        }, 500


# ============================================================
# Prometheus Metrics Endpoint
# ============================================================

@app.route("/metrics")
def metrics():

    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )


# ============================================================
# Application Startup
# ============================================================

if __name__ == "__main__":

    port = int(
        os.environ.get(
            "PORT",
            8080
        )
    )

    app.run(
        host="0.0.0.0",
        port=port
    )