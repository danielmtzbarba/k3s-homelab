output "server_public_ip" {
  description = "Static public IP of the server."
  value       = google_compute_address.server.address
}

output "server_private_ip" {
  description = "Internal IP of the server."
  value       = google_compute_instance.server.network_interface[0].network_ip
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
