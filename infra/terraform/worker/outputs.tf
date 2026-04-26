output "worker_public_ips" {
  description = "Public IPs of workers keyed by instance name."
  value = {
    for name, instance in google_compute_instance.worker :
    name => instance.network_interface[0].access_config[0].nat_ip
  }
}

output "worker_private_ips" {
  description = "Private IPs of workers keyed by instance name."
  value = {
    for name, instance in google_compute_instance.worker :
    name => instance.network_interface[0].network_ip
  }
}

output "worker_names" {
  description = "Worker instance names."
  value       = sort(keys(google_compute_instance.worker))
}

output "ssh_commands" {
  description = "Commands to SSH into workers with gcloud."
  value = {
    for name, instance in google_compute_instance.worker :
    name => "gcloud compute ssh ${instance.name} --zone=${var.zone}"
  }
}
