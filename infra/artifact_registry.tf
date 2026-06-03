# Container images for Cloud Run live here. CICD builds and pushes to this repo,
# then deploys the pushed image to Cloud Run.
resource "google_artifact_registry_repository" "app" {
  project       = var.project_id
  location      = var.region
  repository_id = "app"
  format        = "DOCKER"
  description   = "MemoryChat container images"

  depends_on = [google_project_service.enabled]
}
