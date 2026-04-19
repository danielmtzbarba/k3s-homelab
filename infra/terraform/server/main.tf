resource "google_compute_network" "server" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "server" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.server.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_firewall" "ssh" {
  name          = "${var.network_name}-allow-ssh"
  network       = google_compute_network.server.name
  source_ranges = [var.ssh_source_range]
  target_tags   = [var.server_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "k3s_api" {
  name          = "${var.network_name}-allow-k3s-api"
  network       = google_compute_network.server.name
  source_ranges = [var.ssh_source_range]
  target_tags   = [var.server_tag]

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
}

resource "google_compute_firewall" "web" {
  name          = "${var.network_name}-allow-web"
  network       = google_compute_network.server.name
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.server_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_address" "server" {
  name   = var.address_name
  region = var.region
}

resource "google_service_account" "server" {
  account_id   = replace(substr("${var.server_name}-sa", 0, 30), "_", "-")
  display_name = "${var.server_name} service account"
}

resource "google_project_iam_member" "server_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.server.email}"
}

resource "google_project_iam_member" "server_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.server.email}"
}

resource "google_compute_instance" "server" {
  name         = var.server_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.server_tag]

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/family/${var.image_family}"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.server.id

    access_config {
      nat_ip = google_compute_address.server.address
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.server.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
