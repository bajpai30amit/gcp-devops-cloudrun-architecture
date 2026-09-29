
from flask import Flask, Response, request

from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST
)

from pymongo import MongoClient
from pymongo.errors import PyMongoError
from google.cloud import pubsub_v1

import base64
import binascii
import json
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
# Pub/Sub Configuration
# ============================================================

PROJECT_ID = os.getenv("PROJECT_ID")
TOPIC_ID = os.getenv("TOPIC_ID", "devops-poc-events")

publisher = pubsub_v1.PublisherClient()

topic_path = (
    publisher.topic_path(PROJECT_ID, TOPIC_ID)
    if PROJECT_ID
    else None
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

    # Exclude metrics scraping and favicon requests.
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

    if mongo_client is None:
        print(
            "MongoDB connection failed: MONGODB_URI is not configured",
            flush=True
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
        print(
            f"MongoDB connection failed: {type(e).__name__}: {e}",
            flush=True
        )

        return {
            "database": "mongodb",
            "status": "connection_failed"
        }, 500


# ============================================================
# Pub/Sub Publisher
# ============================================================

@app.post("/publish")
def publish_event():

    if not topic_path:
        return {
            "error": "PROJECT_ID is not configured"
        }, 500

    event = request.get_json(silent=True)

    if not isinstance(event, dict):
        return {
            "error": "A JSON object is required"
        }, 400

    try:
        message_data = json.dumps(event).encode("utf-8")

        future = publisher.publish(
            topic_path,
            message_data
        )

        message_id = future.result(timeout=10)

        app.logger.info(
            "Published Pub/Sub message: %s",
            message_id
        )

        return {
            "status": "published",
            "message_id": message_id
        }, 202

    except Exception:
        app.logger.exception("Failed to publish Pub/Sub message")

        return {
            "error": "Failed to publish message"
        }, 500


# ============================================================
# Pub/Sub Push Receiver
# ============================================================

@app.post("/pubsub")
def receive_pubsub():

    envelope = request.get_json(silent=True)

    if not isinstance(envelope, dict):
        return {
            "error": "Invalid Pub/Sub request"
        }, 400

    message = envelope.get("message")

    if not isinstance(message, dict):
        return {
            "error": "Missing Pub/Sub message"
        }, 400

    try:
        encoded_data = message.get("data", "")

        decoded_data = base64.b64decode(
            encoded_data,
            validate=True
        )

        event = json.loads(decoded_data)

        if not isinstance(event, dict):
            raise ValueError("Expected a JSON object")

        message_id = message.get("messageId")

        app.logger.info(
            "Received Pub/Sub message %s: %s",
            message_id,
            event
        )

        # Future step:
        # Process the event and save it to MongoDB.

        return {
            "status": "processed",
            "message_id": message_id
        }, 200

    except (ValueError, binascii.Error):
        app.logger.warning("Invalid Pub/Sub message data")

        return {
            "error": "Invalid message data"
        }, 400

    except Exception:
        app.logger.exception("Pub/Sub processing failed")

        return {
            "error": "Processing failed"
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

    port = int(os.environ.get("PORT", 8080))

    app.run(
        host="0.0.0.0",
        port=port
    )
