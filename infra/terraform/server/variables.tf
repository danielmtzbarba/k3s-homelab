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
