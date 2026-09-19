resource "google_service_account" "application" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = each.value
  display_name = "Application service account - ${each.value}"
}