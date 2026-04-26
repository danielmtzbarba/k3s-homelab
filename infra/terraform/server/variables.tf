variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "zone" {
  description = "GCP zone."
  type        = string
}

variable "network_name" {
  description = "Custom VPC network name."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR range."
  type        = string
}

variable "cluster_tag" {
  description = "Shared network tag applied to all k3s nodes."
  type        = string
}

variable "server_name" {
  description = "Compute Engine instance name."
  type        = string
}

variable "server_tag" {
  description = "Network tag applied to the server."
  type        = string
}

variable "address_name" {
  description = "Static external IP resource name."
  type        = string
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
}

variable "image_family" {
  description = "Image family for the VM."
  type        = string
}

variable "image_project" {
  description = "Project that owns the image family."
  type        = string
}

variable "ssh_source_range" {
  description = "CIDR allowed to SSH and reach the k3s API."
  type        = string
}

variable "public_ssh_enable" {
  description = "Whether to create the public SSH firewall rule."
  type        = bool
  default     = true
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 40
}

variable "ssh_user" {
  description = "Linux username used for SSH metadata."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key contents for instance access."
  type        = string
  sensitive   = true
}

variable "tailscale_enable" {
  description = "Whether to enroll the server VM into Tailscale during boot."
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for server enrollment."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tailscale_accept_dns" {
  description = "Whether the server should accept DNS settings from Tailscale."
  type        = bool
  default     = false
}

variable "tailscale_hostname" {
  description = "Tailscale hostname for the server."
  type        = string
  default     = ""
}

variable "k3s_cluster_token" {
  description = "Stable k3s cluster token used by the server and workers."
  type        = string
  default     = ""
  sensitive   = true
}

variable "k8s_service_account_issuer_enable" {
  description = "Whether to configure a Kubernetes service-account issuer on the server."
  type        = bool
  default     = false
}

variable "k8s_service_account_issuer_url" {
  description = "Service-account issuer URL for the k3s server."
  type        = string
  default     = ""
}

variable "k8s_service_account_jwks_uri" {
  description = "Optional JWKS URI for the k3s service-account issuer."
  type        = string
  default     = ""
}
