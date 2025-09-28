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

variable "use_static_ip" {
  description = "Whether to use a static IP (costs ~$3/month) or dynamic IP (free)"
  type        = bool
  default     = false  # Default to free option
}

variable "dns_provider" {
  description = "DNS provider to use: 'gcp' for Cloud DNS (~$0.20/month) or 'external' for Cloudflare/other (free)"
  type        = string
  default     = "gcp"
}