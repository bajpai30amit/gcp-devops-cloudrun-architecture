
# ============================================================
# 1. Enable GCP APIs
# ============================================================

module "project_services" {
  source = "./modules/project-services"

  project_id = var.project_id

  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "compute.googleapis.com",

    # Observability
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "telemetry.googleapis.com"
  ]
}


# ============================================================
# 2. Networking: VPC, Subnet, Router and NAT
# ============================================================

module "networking" {
  source = "./modules/networking"

  project_id   = var.project_id
  region       = var.region
  network_name = "${var.name_prefix}-vpc"
  subnet_name  = "${var.name_prefix}-app-subnet"
  subnet_cidr  = "10.10.0.0/24"

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 3. Application Service Account
# ============================================================

module "iam" {
  source = "./modules/iam"

  project_id = var.project_id

  service_accounts = [
    "app-runtime"
  ]

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 4. Artifact Registry
# ============================================================

module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id      = var.project_id
  region          = var.region
  repository_name = "${var.name_prefix}-docker"

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 5. GCS Backup Bucket
# ============================================================

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = "${var.project_id}-${var.name_prefix}-backup"
  location    = "US"

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 6. Secret Manager
# ============================================================

module "secrets" {
  source = "./modules/secrets"

  project_id = var.project_id

  secret_names = [
    "application-secret"
  ]

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 7. Cloud Run Application
# ============================================================

module "cloud_run" {
  source = "./modules/cloud-run"

  project_id = var.project_id
  region     = var.region

  service_name = "${var.name_prefix}-app"

  image = "us-central1-docker.pkg.dev/watchful-idea-505906-u3/devops-poc-docker/devops-poc-app:1.0"

  service_account = module.iam.service_accounts["app-runtime"]

  min_instances = 0
  max_instances = 5

  depends_on = [
    module.project_services,
    module.iam
  ]
}


# ============================================================
# 8. Pub/Sub Push Service Account
# ============================================================

data "google_project" "current" {
  project_id = var.project_id

  depends_on = [
    module.project_services
  ]
}

resource "google_service_account" "pubsub_push" {
  project      = var.project_id
  account_id   = "pubsub-push"
  display_name = "Pub/Sub Cloud Run Push"

  depends_on = [
    module.project_services
  ]
}


# ============================================================
# 9. Pub/Sub Push Authentication
# ============================================================

# Allow the push service account to invoke Cloud Run.

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.region
  name     = module.cloud_run.service_name

  role   = "roles/run.invoker"
  member = "serviceAccount:${google_service_account.pubsub_push.email}"
}

# Allow the Google-managed Pub/Sub service agent to generate
# OIDC identity tokens for the push service account.

resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.pubsub_push.name

  role = "roles/iam.serviceAccountTokenCreator"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}


# ============================================================
# 10. Pub/Sub Topic and Push Subscription
# ============================================================

module "pubsub" {
  source = "./modules/pubsub"

  project_id = var.project_id
  topic_name = "${var.name_prefix}-events"

  cloud_run_push_endpoint = "${module.cloud_run.service_uri}/pubsub"

  push_service_account_email = google_service_account.pubsub_push.email

  depends_on = [
    module.project_services,
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
    google_service_account_iam_member.pubsub_token_creator
  ]
}


# ============================================================
# 11. Monitoring
# ============================================================

module "monitoring" {
  source = "./modules/monitoring"

  project_id             = var.project_id
  region                 = var.region
  cloud_run_service_name = module.cloud_run.service_name
  notification_email     = var.notification_email

  depends_on = [
    module.project_services,
    module.cloud_run
  ]
}


# ============================================================
# 12. Application Runtime IAM
# ============================================================

# Allow Cloud Run to write application metrics.

resource "google_project_iam_member" "app_runtime_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}

# Allow Cloud Run to write application logs.

resource "google_project_iam_member" "app_runtime_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}

# Allow Cloud Run to access the MongoDB connection secret.

resource "google_secret_manager_secret_iam_member" "mongodb_runtime_access" {
  project   = var.project_id
  secret_id = "mongodb-uri"

  role = "roles/secretmanager.secretAccessor"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}

# Allow the Flask application to publish events to its topic.

resource "google_pubsub_topic_iam_member" "app_runtime_pubsub_publisher" {
  project = var.project_id
  topic   = module.pubsub.topic_name

  role = "roles/pubsub.publisher"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}
