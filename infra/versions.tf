terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Remote state in GCS (GCP's S3 equivalent): local runs and CICD share one
  # locked, versioned state. The bucket is created by state.tf, then state is
  # migrated in with `terraform init -migrate-state`. Backend blocks can't use
  # variables, so the bucket name is hardcoded.
  backend "gcs" {
    bucket = "gcpdemo-zackshioi-tfstate"
    prefix = "infra"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
