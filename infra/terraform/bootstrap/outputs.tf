output "tf_state_bucket" {
  description = "Terraform state bucket name."
  value       = google_storage_bucket.tf_state.name
}

output "tf_state_bucket_url" {
  description = "Terraform state bucket URL."
  value       = google_storage_bucket.tf_state.url
}
