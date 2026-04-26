output "server_public_ip" {
  description = "Static public IP of the server."
  value       = google_compute_address.server.address
}

output "server_private_ip" {
  description = "Internal IP of the server."
  value       = google_compute_address.server_internal_ip.address
}

output "server_name" {
  description = "Compute Engine instance name."
  value       = google_compute_instance.server.name
}

output "network_name" {
  description = "Created VPC network name."
  value       = google_compute_network.server.name
}

output "ssh_command" {
  description = "Command to SSH into the server with gcloud."
  value       = "gcloud compute ssh ${google_compute_instance.server.name} --zone=${var.zone}"
}

output "eso_gcpsm_service_account_email" {
  description = "Email of the dedicated GCP service account used by External Secrets Operator."
  value       = var.eso_gcpsm_enable ? google_service_account.eso_gcpsm[0].email : null
}

output "eso_gcpsm_key_output_path" {
  description = "Local path where Terraform wrote the ESO GCPSM service account key JSON."
  value       = var.eso_gcpsm_enable && var.eso_gcpsm_key_create ? local_sensitive_file.eso_gcpsm_key[0].filename : null
  sensitive   = true
}
