# Shark Industries - Infrastructure as Code

This repository contains the Terraform configuration for Shark Industries' Google Cloud Platform infrastructure.

## Architecture

- **Single GCP Project**: `shark-industries-prod`
- **Core Services**:
  - Cloud DNS for domain management
  - Compute Engine VM (e2-micro) for web hosting
  - Static IP addressing
  - Firewall rules for HTTP/HTTPS/Email

## Structure

```
.
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development (future)
│   ├── staging/          # Staging (future)
│   └── prod/             # Production environment
├── modules/              # Reusable Terraform modules
│   └── foundation/       # Core infrastructure (project, networking, VM)
└── scripts/              # Automation and helper scripts
```

## Prerequisites

1. Google Cloud account with billing enabled
2. `gcloud` CLI installed and authenticated
3. Terraform >= 1.0
4. Service account with appropriate permissions

## Setup

1. Create a GCP project manually or via `gcloud`:
   ```bash
   gcloud projects create shark-industries-prod --name="Shark Industries Production"
   ```

2. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com dns.googleapis.com --project=shark-industries-prod
   ```

3. Create a service account for Terraform:
   ```bash
   gcloud iam service-accounts create terraform --project=shark-industries-prod
   ```

4. Set up authentication (save key locally, never commit):
   ```bash
   gcloud iam service-accounts keys create ~/terraform-key.json \
     --iam-account=terraform@shark-industries-prod.iam.gserviceaccount.com
   ```

## Deployment

From the appropriate environment directory:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## GitHub Actions

Automated deployment is configured via GitHub Actions on push to main branch.