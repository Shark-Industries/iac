variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for compute resources"
  type        = string
  default     = "us-central1-a"
}

variable "domain_name" {
  description = "The domain name for DNS zone"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vm_machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-micro"
}

variable "vm_boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 10
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for VM access"
  type        = list(string)
  default     = []
}