output "worker_public_ip" {
  description = "Public IP of the worker."
  value       = google_compute_instance.worker.network_interface[0].access_config[0].nat_ip
}

output "worker_private_ip" {
  description = "Private IP of the worker."
  value       = google_compute_instance.worker.network_interface[0].network_ip
}

output "worker_name" {
  description = "Worker instance name."
  value       = google_compute_instance.worker.name
}

output "ssh_command" {
  description = "Command to SSH into the worker with gcloud."
  value       = "gcloud compute ssh ${google_compute_instance.worker.name} --zone=${var.zone}"
}
