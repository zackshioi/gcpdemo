output "project_id" {
  value       = var.project_id
  description = "Project all resources live in."
}

output "region" {
  value       = var.region
  description = "Single region for all resources."
}

# --- values the GitHub Actions workflow needs (not secrets) -----------------
output "wif_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full WIF provider resource name for google-github-actions/auth."
}

output "deployer_sa" {
  value       = google_service_account.github_deployer.email
  description = "Service account GitHub Actions impersonates."
}

output "artifact_repo" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
  description = "Artifact Registry path images are pushed to."
}

output "cloud_run_url" {
  value       = google_cloud_run_v2_service.app.uri
  description = "Public URL of the deployed app."
}
