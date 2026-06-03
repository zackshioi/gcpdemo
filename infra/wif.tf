# Workload Identity Federation: GitHub Actions authenticates to GCP with a
# short-lived OIDC token (NO long-lived JSON key). The token is exchanged for
# credentials that impersonate the github_deployer service account, and only
# for our specific repo.

variable "github_repo" {
  type        = string
  default     = "zackshioi/gcpdemo"
  description = "owner/repo allowed to deploy via WIF."
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Map GitHub token claims to attributes we can authorize on.
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Hard restriction: only tokens from our repo can use this provider.
  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

# Let identities from our repo impersonate the deployer SA.
resource "google_service_account_iam_member" "wif_impersonate_deployer" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
