data "google_compute_network" "cluster" {
  name = var.network_name
}

data "google_compute_subnetwork" "cluster" {
  name   = var.subnet_name
  region = var.region
}

data "google_compute_instance" "server" {
  name = var.server_name
  zone = var.zone
}

locals {
  workers = {
    for name, worker in var.workers : name => {
      internal_ip        = worker.internal_ip
      worker_tag         = coalesce(try(worker.worker_tag, null), var.worker_tag)
      machine_type       = coalesce(try(worker.machine_type, null), var.machine_type)
      boot_disk_size_gb  = coalesce(try(worker.boot_disk_size_gb, null), var.boot_disk_size_gb)
      tailscale_auth_key = coalesce(try(worker.tailscale_auth_key, null), var.tailscale_auth_key)
      tailscale_hostname = coalesce(try(worker.tailscale_hostname, null), name)
    }
  }
}

resource "google_compute_address" "worker_internal_ip" {
  for_each     = local.workers
  name         = "${each.key}-internal-ip"
  region       = var.region
  subnetwork   = data.google_compute_subnetwork.cluster.id
  address_type = "INTERNAL"
  address      = each.value.internal_ip
}

resource "google_service_account" "worker" {
  for_each     = local.workers
  account_id   = replace(substr("${each.key}-sa", 0, 30), "_", "-")
  display_name = "${each.key} service account"
}

resource "google_project_iam_member" "worker_logging" {
  for_each = local.workers
  project  = var.project_id
  role     = "roles/logging.logWriter"
  member   = "serviceAccount:${google_service_account.worker[each.key].email}"
}

resource "google_project_iam_member" "worker_monitoring" {
  for_each = local.workers
  project  = var.project_id
  role     = "roles/monitoring.metricWriter"
  member   = "serviceAccount:${google_service_account.worker[each.key].email}"
}

resource "google_compute_instance" "worker" {
  for_each     = local.workers
  name         = each.key
  zone         = var.zone
  machine_type = each.value.machine_type
  tags         = [var.cluster_tag, each.value.worker_tag]

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      k3s_url              = "https://${data.google_compute_instance.server.network_interface[0].network_ip}:6443"
      k3s_cluster_token    = var.k3s_cluster_token
      tailscale_enable     = var.tailscale_enable
      tailscale_auth_key   = each.value.tailscale_auth_key
      tailscale_accept_dns = tostring(var.tailscale_accept_dns)
      tailscale_hostname   = each.value.tailscale_hostname
    })
  }

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/family/${var.image_family}"
      size  = each.value.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.cluster.id
    network_ip = google_compute_address.worker_internal_ip[each.key].address

    access_config {}
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.worker[each.key].email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
