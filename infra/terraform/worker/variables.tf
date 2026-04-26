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
  description = "Existing VPC network name."
  type        = string
}

variable "subnet_name" {
  description = "Existing subnet name."
  type        = string
}

variable "cluster_tag" {
  description = "Shared cluster network tag."
  type        = string
}

variable "server_name" {
  description = "Compute Engine instance name for the k3s server."
  type        = string
}

variable "workers" {
  description = "Desired worker set keyed by worker instance name."
  type = map(object({
    internal_ip        = string
    worker_tag         = optional(string)
    machine_type       = optional(string)
    boot_disk_size_gb  = optional(number)
    tailscale_auth_key = optional(string)
    tailscale_hostname = optional(string)
  }))
}

variable "worker_tag" {
  description = "Default network tag for workers."
  type        = string
}

variable "machine_type" {
  description = "Default Compute Engine machine type."
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

variable "ssh_user" {
  description = "Linux username used for SSH metadata."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key contents for instance access."
  type        = string
  sensitive   = true
}

variable "boot_disk_size_gb" {
  description = "Default boot disk size in GB."
  type        = number
  default     = 40
}

variable "tailscale_enable" {
  description = "Whether to enroll worker VMs into Tailscale during boot."
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "Default Tailscale auth key for worker enrollment."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tailscale_accept_dns" {
  description = "Whether workers should accept DNS settings from Tailscale."
  type        = bool
  default     = false
}

variable "k3s_cluster_token" {
  description = "Stable k3s cluster token used for agent join on boot."
  type        = string
  default     = ""
  sensitive   = true
}
