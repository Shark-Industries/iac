variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "shark-outboards"
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
  default     = "sharkoutboards.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for VM access"
  type        = list(string)
  default     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDOGOks5lwcpAkBTxWD0vKYjqEZiXcbCa8zZG2cXnLUOE6CFHnBLIV9kxuWIxBeXjSvYpFkea+hB72utTCg7AMHHf5ztoxQy1sY3moPhNSFaLg0GJueh9SykARa+zY2f1spfgWYkxkuT6gtFlIT8lwzIFhPF+w9XbOTzpA+3aZ0vcfREBjVu4mSBf6vQEu69txF6k5HQmcqQ/IZp8jacZcWQmaCgf9/ecx5k6qhgRxZRh3G1pWEqz1Dk0KIhb2jT5pDrEPEzRd9BFudJM+36gTWGx8MP2PUhj9e8ow4z++acUUPk9ULAik/xoi6G3QuoUJFMd5rOHpY/g785AwloBHj"]
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

variable "alert_email" {
  description = "Email address for monitoring alerts (leave empty to disable alerts)"
  type        = string
  default     = ""
}