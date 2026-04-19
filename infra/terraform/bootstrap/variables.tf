variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "tf_state_bucket" {
  description = "Globally unique GCS bucket name for Terraform state."
  type        = string
}

variable "tf_state_location" {
  description = "Bucket location, for example europe-west3 or EU."
  type        = string
}

variable "delete_old_versions" {
  description = "Whether to expire older object versions."
  type        = bool
  default     = false
}

variable "noncurrent_version_age_days" {
  description = "Days to retain older object versions before deletion."
  type        = number
  default     = 90
}
