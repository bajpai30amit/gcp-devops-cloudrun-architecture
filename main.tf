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

module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id      = var.project_id
  region          = var.region
  repository_name = "${var.name_prefix}-docker"

  depends_on = [
    module.project_services
  ]
}

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = "${var.project_id}-${var.name_prefix}-backup"
  location    = "US"

  depends_on = [
    module.project_services
  ]
}

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

module "pubsub" {
  source = "./modules/pubsub"

  project_id = var.project_id
  topic_name = "${var.name_prefix}-events"

  depends_on = [
    module.project_services
  ]
}

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
resource "google_project_iam_member" "app_runtime_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}

resource "google_project_iam_member" "app_runtime_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"

  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}
resource "google_secret_manager_secret_iam_member" "mongodb_runtime_access" {
  project   = var.project_id
  secret_id = "mongodb-uri"

  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${module.iam.service_accounts["app-runtime"]}"
}

