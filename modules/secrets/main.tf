resource "google_secret_manager_secret" "secrets" {
  for_each = var.secret_names

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}