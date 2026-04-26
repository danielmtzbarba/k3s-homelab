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

resource "google_compute_address" "worker_internal_ip" {
  name         = "${var.worker_name}-internal-ip"
  region       = var.region
  subnetwork   = data.google_compute_subnetwork.cluster.id
  address_type = "INTERNAL"
  address      = var.worker_internal_ip
}

resource "google_service_account" "worker" {
  account_id   = replace(substr("${var.worker_name}-sa", 0, 30), "_", "-")
  display_name = "${var.worker_name} service account"
}

resource "google_project_iam_member" "worker_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_project_iam_member" "worker_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_compute_instance" "worker" {
  name         = var.worker_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.cluster_tag, var.worker_tag]

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      k3s_url              = "https://${data.google_compute_instance.server.network_interface[0].network_ip}:6443"
      k3s_cluster_token    = var.k3s_cluster_token
      tailscale_enable     = var.tailscale_enable
      tailscale_auth_key   = var.tailscale_auth_key
      tailscale_accept_dns = tostring(var.tailscale_accept_dns)
      tailscale_hostname   = coalesce(var.tailscale_hostname, var.worker_name)
    })
  }

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/family/${var.image_family}"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.cluster.id
    network_ip = google_compute_address.worker_internal_ip.address

    access_config {}
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.worker.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
