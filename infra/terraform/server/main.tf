resource "google_compute_network" "server" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

locals {
  eso_gcpsm_key_output_path = var.eso_gcpsm_key_output_path != "" ? var.eso_gcpsm_key_output_path : "${path.module}/generated/${var.eso_gcpsm_service_account_id}.json"
}

resource "terraform_data" "ensure_eso_gcpsm_key_dir" {
  count = var.eso_gcpsm_enable && var.eso_gcpsm_key_create ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p '${dirname(local.eso_gcpsm_key_output_path)}'"
  }
}

resource "google_compute_subnetwork" "server" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.server.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_firewall" "ssh" {
  count         = var.public_ssh_enable ? 1 : 0
  name          = "${var.network_name}-allow-ssh"
  network       = google_compute_network.server.name
  source_ranges = [var.ssh_source_range]
  target_tags   = [var.cluster_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "k3s_api" {
  name          = "${var.network_name}-allow-k3s-api"
  network       = google_compute_network.server.name
  source_ranges = [var.ssh_source_range, var.subnet_cidr]
  target_tags   = [var.server_tag]

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
}

resource "google_compute_firewall" "node_internal" {
  name          = "${var.network_name}-allow-node-internal"
  network       = google_compute_network.server.name
  source_ranges = [var.subnet_cidr]
  target_tags   = [var.cluster_tag]

  allow {
    protocol = "tcp"
    ports    = ["2379-2380", "9100", "10250", "30000-32767"]
  }

  allow {
    protocol = "udp"
    ports    = ["8472", "51820", "51821"]
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

resource "google_compute_address" "server_internal_ip" {
  name         = "${var.server_name}-internal-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.server.id
  address_type = "INTERNAL"
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

resource "google_service_account" "eso_gcpsm" {
  count        = var.eso_gcpsm_enable ? 1 : 0
  account_id   = replace(substr(var.eso_gcpsm_service_account_id, 0, 30), "_", "-")
  display_name = "External Secrets Operator GCPSM"
}

resource "google_project_iam_member" "eso_gcpsm_secretmanager" {
  count   = var.eso_gcpsm_enable ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_gcpsm[0].email}"
}

resource "google_service_account_key" "eso_gcpsm" {
  count              = var.eso_gcpsm_enable && var.eso_gcpsm_key_create ? 1 : 0
  service_account_id = google_service_account.eso_gcpsm[0].name
}

resource "local_sensitive_file" "eso_gcpsm_key" {
  count           = var.eso_gcpsm_enable && var.eso_gcpsm_key_create ? 1 : 0
  filename        = local.eso_gcpsm_key_output_path
  content         = base64decode(google_service_account_key.eso_gcpsm[0].private_key)
  file_permission = "0600"

  depends_on = [terraform_data.ensure_eso_gcpsm_key_dir]
}

resource "google_compute_instance" "server" {
  name         = var.server_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.cluster_tag, var.server_tag]

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      k3s_cluster_token                 = var.k3s_cluster_token
      tailscale_enable                  = var.tailscale_enable
      tailscale_auth_key                = var.tailscale_auth_key
      tailscale_accept_dns              = tostring(var.tailscale_accept_dns)
      tailscale_hostname                = coalesce(var.tailscale_hostname, var.server_name)
      k8s_service_account_issuer_enable = var.k8s_service_account_issuer_enable
      k8s_service_account_issuer_url    = var.k8s_service_account_issuer_url
      k8s_service_account_jwks_uri      = var.k8s_service_account_jwks_uri
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
    subnetwork = google_compute_subnetwork.server.id
    network_ip = google_compute_address.server_internal_ip.address

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
