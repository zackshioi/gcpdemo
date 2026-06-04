variable "project_id" {
  type        = string
  description = "Target GCP project ID."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Single region for all resources (see docs/DECISIONS.md ADR-005)."
}

variable "agent_engine_id" {
  type        = string
  default     = "projects/1079899377320/locations/us-central1/reasoningEngines/6351899014627065856"
  description = "Memory Bank Agent Engine resource name. Created out-of-band (no TF resource); see RUNBOOK."
}

variable "create_project" {
  type        = bool
  default     = false
  description = "If true, Terraform creates the project itself (needs billing_account). Otherwise it manages resources inside an existing project."
}

variable "billing_account" {
  type        = string
  default     = ""
  description = "Billing account ID. Only used when create_project = true."
}
