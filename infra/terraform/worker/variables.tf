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

variable "worker_name" {
  description = "Compute Engine instance name for the worker."
  type        = string
}

variable "worker_tag" {
  description = "Network tag for the worker."
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
  description = "Boot disk size in GB."
  type        = number
  default     = 40
}
