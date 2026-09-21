# GCP DevOps Cloud Run Architecture

## Project Overview

This project demonstrates an end-to-end DevOps architecture on Google Cloud Platform using Infrastructure as Code, automated CI/CD, containerized application deployment, observability, secure secret management, MongoDB integration, and backup/disaster-recovery practices.

The solution is designed around two independent automation workflows:

* **Infrastructure CI/CD** — Terraform provisions and manages the GCP infrastructure.
* **Application CI/CD** — GitHub Actions builds the application container, pushes it to Artifact Registry, and deploys it to Cloud Run.

Both pipelines authenticate to Google Cloud using **GitHub OIDC and Google Cloud Workload Identity Federation (WIF)**. No long-lived GCP service-account JSON keys are required in GitHub.

The deployed application is a Python Flask service running on Google Cloud Run with Google Managed Service for Prometheus integration for application metrics.

---

# Architecture Overview

```text
                         GitHub Repository
                                |
                     GitHub Actions / OIDC
                                |
                 Google Workload Identity Federation
                                |
                +---------------+---------------+
                |                               |
                |                               |
        Application CI/CD               Infrastructure CI/CD
                |                               |
        github-actions SA                     gcp-tf SA
                |                               |
                |                           Terraform
                |                               |
                |                 +-------------+-------------+
                |                 |             |             |
                |                VPC           IAM          Storage
                |                 |             |             |
                |             Cloud NAT    Service Accounts   GCS
                |                               |
                |                        Secret Manager
                |                               |
                |                    Monitoring / Logging
                |                               |
                +-----------> Artifact Registry |
                                |               |
                                v               |
                            Cloud Run <---------+
                                |
                   +------------+-------------+
                   |                          |
             Flask Application        GMP Collector Sidecar
                   |                          |
                   |                          v
                   |                 Cloud Monitoring
                   |                 Prometheus Metrics
                   |
             Secret Manager
                   |
              MongoDB URI
                   |
                   v
              MongoDB Atlas
                   |
                   |
              Backup Process
                   |
             mongodump + gzip
                   |
                   v
            Google Cloud Storage
```

---

# Technology Stack

| Area                   | Technology                                     |
| ---------------------- | ---------------------------------------------- |
| Cloud Platform         | Google Cloud Platform                          |
| Infrastructure as Code | Terraform                                      |
| Source Control         | GitHub                                         |
| CI/CD                  | GitHub Actions                                 |
| Authentication         | GitHub OIDC + GCP Workload Identity Federation |
| Container Registry     | Google Artifact Registry                       |
| Application Platform   | Google Cloud Run                               |
| Application            | Python / Flask                                 |
| Containerization       | Docker                                         |
| Database               | MongoDB Atlas on GCP                           |
| Secret Management      | Google Secret Manager                          |
| Metrics                | Prometheus                                     |
| Metrics Collection     | Google Managed Service for Prometheus          |
| Monitoring             | Google Cloud Monitoring                        |
| Logging                | Google Cloud Logging                           |
| Alerting               | Google Cloud Monitoring Alert Policies         |
| Backup                 | MongoDB Database Tools / mongodump             |
| Backup Storage         | Google Cloud Storage                           |
| Networking             | VPC, Subnet, Cloud Router, Cloud NAT           |
| Automation             | Terraform, GitHub Actions, PowerShell          |

---

# Repository Structure

```text
devops-gcp-architecture/
|
+-- app/
|   +-- app.py
|   +-- Dockerfile
|   +-- requirements.txt
|
+-- modules/
|   +-- project-services/
|   +-- networking/
|   +-- iam/
|   +-- artifact-registry/
|   +-- storage/
|   +-- secrets/
|   +-- pubsub/
|   +-- cloud-run/
|   +-- monitoring/
|   +-- logging/
|   +-- gke/
|   +-- mongodb/
|   +-- backup/
|   +-- github-actions/
|
+-- scripts/
|   +-- mongodb-backup.ps1
|
+-- .github/
|   +-- workflows/
|       +-- deploy-cloud-run.yml
|       +-- terraform.yml
|
+-- backend.tf
+-- main.tf
+-- provider.tf
+-- variables.tf
+-- terraform.tfvars
+-- version.tf
+-- output.tf
+-- .gitignore
+-- README.md
```

`terraform.tfvars` contains environment-specific Terraform values and is intentionally excluded from Git using `.gitignore`.

GitHub Actions supplies required Terraform variables through `TF_VAR_*` environment variables and GitHub repository variables.

---

# Infrastructure as Code

Terraform is used as the primary Infrastructure as Code tool for the project.

Terraform manages the following GCP components:

* Required Google Cloud APIs
* VPC network
* Application subnet
* Cloud Router
* Cloud NAT
* IAM service accounts
* IAM role assignments
* Artifact Registry
* Google Cloud Storage backup bucket
* Secret Manager resources
* Pub/Sub
* Cloud Run
* Cloud Monitoring
* Monitoring dashboards
* Alert policies
* Notification channels
* Logging-related configuration
* Workload Identity-related infrastructure

## Terraform Providers

The project uses the Google and Google Beta Terraform providers.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.2"
    }
  }
}
```

---

# Terraform Remote State

Terraform state is stored remotely in Google Cloud Storage.

```text
Bucket:
watchful-idea-505906-u3-tfstate

State prefix:
dev
```

Backend configuration:

```hcl
terraform {
  backend "gcs" {
    bucket = "watchful-idea-505906-u3-tfstate"
    prefix = "dev"
  }
}
```

Remote state provides a centralized Terraform state location for local and CI/CD execution.

---

# Terraform Infrastructure CI/CD

Infrastructure changes are automated using:

```text
.github/workflows/terraform.yml
```

The infrastructure pipeline uses a dedicated service account:

```text
gcp-tf@watchful-idea-505906-u3.iam.gserviceaccount.com
```

GitHub authenticates to this account through Workload Identity Federation.

No GCP service-account JSON key is stored in GitHub.

## Pull Request Flow

```text
Pull Request
     |
     v
Checkout
     |
     v
OIDC / Workload Identity Federation
     |
     v
Terraform Format Check
     |
     v
Terraform Init
     |
     v
Terraform Validate
     |
     v
Terraform Plan
     |
     v
STOP
```

Terraform Apply is not executed for pull requests.

## Main Branch Flow

```text
Push / Merge to main
        |
        v
Terraform Format
        |
        v
Terraform Init
        |
        v
Terraform Validate
        |
        v
Terraform Plan
        |
        v
Terraform Apply
```

The implemented Terraform GitHub Actions pipeline has been successfully tested.

---

# Application CI/CD

Application deployment uses a separate GitHub Actions workflow:

```text
.github/workflows/deploy-cloud-run.yml
```

A separate service account is used for application deployments:

```text
github-actions@watchful-idea-505906-u3.iam.gserviceaccount.com
```

This separates application deployment permissions from infrastructure provisioning permissions.

The deployment pipeline performs:

```text
Git Push
   |
   v
GitHub Actions
   |
   v
GitHub OIDC
   |
   v
GCP Workload Identity Federation
   |
   v
Build Docker Image
   |
   v
Push Image
   |
   v
Artifact Registry
   |
   v
Deploy Cloud Run
   |
   v
Health Verification
```

This identity separation reduces the need for the application deployment pipeline to hold broad infrastructure-management permissions.

---

# Artifact Registry

Docker images are stored in Google Artifact Registry.

```text
Region:
us-central1

Repository:
devops-poc-docker
```

Registry path:

```text
us-central1-docker.pkg.dev/watchful-idea-505906-u3/devops-poc-docker
```

Each GitHub Actions deployment can use the Git commit SHA as the container image tag, providing traceability between source code and deployed revisions.

---

# Cloud Run Application

The application is deployed as:

```text
devops-poc-app
```

Region:

```text
us-central1
```

The Cloud Run service contains two containers:

```text
Cloud Run Service
|
+-- app
|   |
|   +-- Python Flask
|   +-- Port 8080
|   +-- Application endpoints
|   +-- Prometheus metrics
|
+-- collector
    |
    +-- Google Managed Prometheus sidecar
```

The application container exposes application functionality and Prometheus metrics.

The collector sidecar integrates those metrics with Google Managed Service for Prometheus / Cloud Monitoring.

---

# Application Health Endpoints

The application provides health endpoints for deployment and operational validation.

## Application Health

```text
/health
```

Expected response:

```json
{
  "status": "healthy"
}
```

## MongoDB Health

```text
/db-health
```

Expected successful response:

```json
{
  "database": "mongodb",
  "status": "connected"
}
```

## Prometheus Metrics

```text
/metrics
```

This endpoint exposes Prometheus-compatible application metrics.

---

# MongoDB Atlas Integration

MongoDB Atlas is used as the application database.

The MongoDB connection string is **not stored in the source repository**.

Instead:

```text
MongoDB Atlas
      ^
      |
Secret Manager
      ^
      |
Cloud Run Runtime Service Account
      ^
      |
Cloud Run Application
```

The connection information is stored in Google Secret Manager under:

```text
mongodb-uri
```

Cloud Run receives the latest secret version as:

```text
MONGODB_URI
```

The runtime service account has Secret Manager accessor permissions required to retrieve the secret.

---

# Secret Management

Application credentials are separated from source code.

The project uses:

* Google Secret Manager
* IAM-controlled secret access
* Cloud Run secret injection
* GitHub OIDC/WIF instead of service-account JSON keys

Sensitive database connection strings are not committed to Git.

---

# Monitoring and Observability

The project implements both Google Cloud native monitoring and application-level Prometheus monitoring.

## Cloud Run Native Metrics

Cloud Monitoring alert policies monitor:

* HTTP 5xx errors
* High request latency

The latency alert monitors p95 request latency.

Configured threshold:

```text
p95 > 2000 ms
for 5 minutes
```

Alerts are connected to an email notification channel.

---

# Prometheus Monitoring

The Flask application exposes Prometheus metrics through:

```text
/metrics
```

Google Managed Service for Prometheus collects application metrics through the Cloud Run collector sidecar.

Example application metric:

```text
http_requests_total
```

Prometheus data has been verified in Google Cloud Monitoring.

---

# Prometheus Application Dashboard

Terraform provisions:

```text
DevOps POC - Prometheus Application Dashboard
```

The dashboard contains four primary charts:

### Request Rate

PromQL:

```promql
sum(rate(http_requests_total{service_name="devops-poc-app"}[5m]))
```

### Request Rate by Endpoint

```promql
sum by (endpoint) (
  rate(http_requests_total{service_name="devops-poc-app"}[5m])
)
```

### HTTP Requests by Status Code

```promql
sum by (status) (
  rate(http_requests_total{service_name="devops-poc-app"}[5m])
)
```

### P95 Request Latency

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(
      http_request_duration_seconds_bucket{
        service_name="devops-poc-app"
      }[5m]
    )
  )
)
```

Google Monitoring normalizes some dashboard JSON fields after creation. The Terraform resource therefore ignores subsequent `dashboard_json` differences to prevent perpetual non-functional drift.

When intentionally modifying the dashboard JSON through Terraform, the lifecycle behavior should be reviewed temporarily so intended dashboard changes can be applied.

---

# Cloud Logging

Application and Cloud Run logs are available through Google Cloud Logging.

This provides centralized visibility for:

* Application output
* Container errors
* Cloud Run revision events
* Deployment troubleshooting
* Runtime failures

Together, Cloud Logging and Prometheus/Cloud Monitoring provide both log-based and metric-based observability.

---

# MongoDB Backup

MongoDB backups are automated using:

```text
scripts/mongodb-backup.ps1
```

The script performs:

```text
Secret Manager
      |
      | Retrieve MongoDB URI
      v
MongoDB Atlas
      |
      | mongodump
      v
Compressed Archive
      |
      | gzip
      v
Google Cloud Storage
      |
      v
Object Verification
      |
      v
Delete Local Backup
```

The MongoDB URI is retrieved dynamically from Secret Manager and is not embedded in the script.

---

# Backup Storage

MongoDB backup archives are stored in:

```text
gs://watchful-idea-505906-u3-devops-poc-backup/mongodb/
```

The backup bucket is configured with controls including:

* Public access prevention
* Uniform bucket-level access
* Object versioning
* 7-day soft delete retention
* 90-day lifecycle deletion

Two backup archives were successfully generated and uploaded during POC validation.

---

# Disaster Recovery Validation

MongoDB restore validation was performed using:

```text
mongorestore --archive=<backup> --gzip --dryRun --verbose
```

The dry run successfully identified BSON data and metadata for the collections contained in the archive.

The validated archive contained the following database:

```text
sample_mflix
```

and collections including:

```text
sessions
movies
theaters
users
embedded_movies
comments
```

A full production restore was intentionally **not performed** because the MongoDB tools reported a cross-version dump/restore compatibility warning.

Therefore, the demonstrated DR validation confirms that:

* the archive can be read,
* collection BSON data is present,
* collection metadata is present,
* the restore process can parse the backup.

It does **not** claim that a complete production restore has been executed.

For production, backup and restore tooling should use MongoDB-compatible versions and restore testing should be performed regularly in an isolated environment.

---

# Networking

Terraform provisions a dedicated network architecture.

```text
VPC:
devops-poc-vpc

Subnet:
devops-poc-app-subnet

CIDR:
10.10.0.0/24
```

The network module also provisions:

* Cloud Router
* Cloud NAT

The modular Terraform design allows networking components to be managed independently from application deployment.

---

# IAM and Workload Identity Federation

The project uses two separate GitHub identities.

## Application Deployment Identity

```text
github-actions@watchful-idea-505906-u3.iam.gserviceaccount.com
```

Used for:

* Artifact Registry access
* Cloud Run deployment
* Application release operations

## Infrastructure Identity

```text
gcp-tf@watchful-idea-505906-u3.iam.gserviceaccount.com
```

Used for Terraform infrastructure management.

GitHub repositories authenticate through:

```text
GitHub OIDC
      |
      v
Workload Identity Pool
      |
      v
github-provider
      |
      v
Repository identity restriction
      |
      v
GCP Service Account
```

This avoids storing long-lived Google Cloud service-account keys in GitHub.

---

# Security Controls

Implemented security controls include:

* GitHub OIDC authentication
* Google Cloud Workload Identity Federation
* No long-lived GCP JSON key required for CI/CD
* Dedicated application and infrastructure service accounts
* Secret Manager for MongoDB credentials
* IAM-controlled secret access
* GCS public access prevention
* Uniform bucket-level access
* GCS versioning
* Backup soft-delete retention
* TLS-based MongoDB Atlas connectivity
* Terraform remote state
* Monitoring alerts
* Centralized Cloud Logging

---

# Terraform Commands

Initialize Terraform:

```bash
terraform init
```

Validate configuration:

```bash
terraform validate
```

Check formatting:

```bash
terraform fmt -check -recursive
```

Generate plan:

```bash
terraform plan
```

Apply infrastructure:

```bash
terraform apply
```

The CI/CD pipeline performs these operations automatically according to the GitHub event.

---

# Infrastructure Validation

After Terraform reconciliation, the infrastructure was verified with:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms alignment between:

```text
Terraform Configuration
          =
Terraform State
          =
Current GCP Infrastructure
```

The Terraform GitHub Actions infrastructure pipeline was subsequently executed successfully.

---

# POC vs Production Considerations

This repository demonstrates the architecture as a technical POC. Several controls should be strengthened before production use.

## Cloud Run Access

POC:

```text
Public Cloud Run endpoint
```

Production recommendation:

Use authenticated/private access where application requirements permit.

## MongoDB Network Access

POC testing temporarily permits broad network connectivity to MongoDB Atlas.

Production recommendation:

* Remove broad `0.0.0.0/0` network access.
* Use restricted network ranges or private connectivity.
* Consider Atlas Private Endpoint / Private Service Connect where appropriate.

## MongoDB User Permissions

POC database access uses elevated Atlas permissions.

Production recommendation:

Create application-specific least-privilege database users with only the required database and collection permissions.

## MongoDB Backup

POC:

```text
PowerShell
  -> mongodump
  -> gzip
  -> GCS
```

Production recommendation:

Automate backup execution using cloud-native scheduled infrastructure such as:

```text
Cloud Scheduler
      |
      v
Cloud Run Job
      |
      v
MongoDB Backup
      |
      v
GCS
```

For production workloads, MongoDB Atlas managed backup/PITR should also be evaluated.

## Disaster Recovery

The POC validated the backup archive using a dry-run restore.

Production recommendation:

* Use compatible MongoDB backup/restore versions.
* Perform scheduled full restore tests.
* Define documented RPO/RTO targets.
* Measure actual restore time.
* Maintain DR runbooks.

## Terraform Apply

POC:

```text
Push to main
      |
      v
Automatic Terraform Apply
```

Production recommendation:

Use:

* Protected branches
* Pull-request review
* Terraform plan review
* GitHub protected environments
* Manual approval before production apply

## Dashboard Lifecycle

The current dashboard uses:

```hcl
lifecycle {
  ignore_changes = [dashboard_json]
}
```

This prevents repeated plan drift caused by Google Monitoring API JSON normalization.

For production, dashboard lifecycle management should be reviewed so intentional dashboard configuration changes remain controlled through Infrastructure as Code.

---

# Key Outcomes

This POC demonstrates:

* Modular Infrastructure as Code using Terraform
* GCS remote Terraform state
* Automated infrastructure CI/CD
* Automated application CI/CD
* Keyless GitHub-to-GCP authentication
* Workload Identity Federation
* Separate application and infrastructure service accounts
* Docker-based application deployment
* Artifact Registry integration
* Cloud Run multi-container deployment
* MongoDB Atlas integration
* Secret Manager integration
* Prometheus application instrumentation
* Google Managed Service for Prometheus
* Cloud Monitoring dashboards
* Cloud Monitoring alerting
* Cloud Logging
* Automated MongoDB backup
* GCS backup protection
* Disaster-recovery archive validation

---

# End-to-End DevOps Flow

```text
Provision with Terraform
          |
          v
Authenticate with WIF
          |
          v
Build with GitHub Actions
          |
          v
Store in Artifact Registry
          |
          v
Deploy to Cloud Run
          |
          v
Retrieve Secrets Securely
          |
          v
Connect to MongoDB Atlas
          |
          v
Observe with Prometheus
          |
          v
Monitor with Cloud Monitoring
          |
          v
Log with Cloud Logging
          |
          v
Back Up MongoDB to GCS
          |
          v
Validate Disaster Recovery
```

The project demonstrates a complete DevOps lifecycle from **Infrastructure as Code → CI/CD → deployment → security → observability → database integration → backup and disaster recovery**.
