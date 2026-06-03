# Short-term memory store (F2): a Firestore Native database holds per-session
# conversation history, so it survives Cloud Run cold starts / restarts.
# One project has a single "(default)" database; we pin it to our region.
resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.enabled]
}
