# The Cloud Run service. Terraform owns its shape (region, identity, scaling,
# env, public access); CICD only pushes new IMAGE revisions. We therefore
# ignore image changes here so `gcloud run deploy` and Terraform don't fight.
#
# Bootstrap: the service is first created with a public placeholder image; the
# first CICD run replaces it with our real image.
resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "memorychat"
  location = var.region

  # Allow public (unauthenticated) traffic so a browser can open it.
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.run_runtime.email

    scaling {
      min_instance_count = 0 # scale to zero when idle (ADR-001)
      max_instance_count = 2
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # placeholder; CICD overwrites

      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GCP_LOCATION"
        value = var.region
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [google_project_service.enabled]
}

# Make the service publicly invocable.
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
