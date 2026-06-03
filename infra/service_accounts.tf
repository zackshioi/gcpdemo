# Two service accounts, least-privilege:
#   - run_runtime:  the identity the Cloud Run container runs AS (calls Vertex +
#                   Firestore). No deploy rights.
#   - github_deployer: the identity GitHub Actions impersonates via WIF to push
#                   images and deploy. No data-plane rights.

# --- runtime identity (what the app uses at request time) -------------------
resource "google_service_account" "run_runtime" {
  project      = var.project_id
  account_id   = "memorychat-run"
  display_name = "MemoryChat Cloud Run runtime"
}

resource "google_project_iam_member" "runtime_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user" # call Gemini on Vertex (F1) + Memory Bank (F3)
  member  = "serviceAccount:${google_service_account.run_runtime.email}"
}

resource "google_project_iam_member" "runtime_firestore" {
  project = var.project_id
  role    = "roles/datastore.user" # read/write Firestore session history (F2)
  member  = "serviceAccount:${google_service_account.run_runtime.email}"
}

# --- deploy identity (what CICD uses) ---------------------------------------
resource "google_service_account" "github_deployer" {
  project      = var.project_id
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer (WIF)"
}

resource "google_project_iam_member" "deployer_run" {
  project = var.project_id
  role    = "roles/run.admin" # create/update the Cloud Run service
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_project_iam_member" "deployer_ar" {
  project = var.project_id
  role    = "roles/artifactregistry.writer" # push images
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Deploying a service that RUNS AS run_runtime requires actAs on that SA.
resource "google_service_account_iam_member" "deployer_actas_runtime" {
  service_account_id = google_service_account.run_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}
