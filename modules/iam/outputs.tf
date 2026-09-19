output "service_accounts" {
  value = {
    for name, sa in google_service_account.application :
    name => sa.email
  }
}