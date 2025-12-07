terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "shark-outboards-pro-terraform-state"
    prefix = "prod"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "aws" {
  region = "us-east-1"  # Route53 domains must use us-east-1
}

module "foundation" {
  source = "../../modules/foundation"

  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  domain_name     = var.domain_name
  environment     = var.environment
  ssh_public_keys = var.ssh_public_keys
  use_static_ip   = var.use_static_ip
  dns_provider    = var.dns_provider
  alert_email     = var.alert_email
}