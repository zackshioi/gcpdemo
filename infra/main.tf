# Infra grows per feature, mirroring the app:
#   F2 adds Firestore, F3 the Agent Engine, F6 Artifact Registry + WIF + Cloud Run.
# F0 establishes the project (optional) and enables the APIs later features need.

# Optionally create the project from scratch. For a gmail account with no org,
# this creates a parent-less project; requires a billing account.
resource "google_project" "this" {
  count           = var.create_project ? 1 : 0
  name            = var.project_id
  project_id      = var.project_id
  billing_account = var.billing_account
  deletion_policy = "DELETE"
}

# APIs the demo will use. Enabled up front so each feature can create resources
# without a separate enablement step.
locals {
  services = [
    "run.googleapis.com",              # Cloud Run            (F6)
    "aiplatform.googleapis.com",       # Vertex AI + Agent Engine (F1, F3)
    "firestore.googleapis.com",        # Firestore            (F2)
    "artifactregistry.googleapis.com", # container images  (F6)
    "iamcredentials.googleapis.com",   # Workload Identity Federation (F6)
    "cloudbuild.googleapis.com",       # image builds         (F6)
    "storage.googleapis.com",          # GCS (Terraform remote state)
    "iam.googleapis.com",              # service accounts            (F6)
    "sts.googleapis.com",              # WIF token exchange          (F6)
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.services)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false # don't tear down shared APIs on `terraform destroy`

  depends_on = [google_project.this]
}
