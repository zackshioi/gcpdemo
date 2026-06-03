# Terraform remote state lives in this GCS bucket (GCP's S3 equivalent), so
# local runs and CICD (F6) share one state with locking and version history.
#
# Bootstrap order (chicken-and-egg): this bucket is first created with the LOCAL
# backend, then versions.tf points the backend at it and state is migrated in
# via `terraform init -migrate-state`. See docs/RUNBOOK.md.
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  project  = var.project_id
  location = var.region

  # State can contain secrets — keep it strictly private.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning lets us recover a clobbered/corrupted state.
  versioning {
    enabled = true
  }

  # Don't let old state versions accumulate forever.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.enabled]
}
