variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "shark-industries-prod"
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
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for VM access"
  type        = list(string)
  default     = []
}