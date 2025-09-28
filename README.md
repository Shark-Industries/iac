# Shark Outboards - Infrastructure as Code

This repository contains the Terraform configuration for Shark Outboards' Google Cloud Platform infrastructure.

## Architecture

- **Single GCP Project**: `shark-outboards-prod`
- **Core Services**:
  - Compute Engine VM (e2-micro) - Free tier eligible
  - Optional Cloud DNS or external DNS (Cloudflare)
  - Optional static or dynamic IP addressing
  - Firewall rules for HTTP/HTTPS/Email

## Cost Optimization

This infrastructure supports three deployment modes:

1. **Ultra-low cost** (~$0.20/month): Dynamic IP + Cloud DNS
2. **Zero infrastructure cost**: Dynamic IP + Cloudflare DNS (free)
3. **Static IP** (~$3.20/month): Most reliable but costs more

See `docs/CLOUDFLARE_SETUP.md` for free DNS option.

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
   gcloud projects create shark-outboards-prod --name="Shark Outboards Production"
   ```

2. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com dns.googleapis.com --project=shark-outboards-prod
   ```

3. Create a service account for Terraform:
   ```bash
   gcloud iam service-accounts create terraform --project=shark-outboards-prod
   ```

4. Set up authentication (save key locally, never commit):
   ```bash
   gcloud iam service-accounts keys create ~/terraform-key.json \
     --iam-account=terraform@shark-outboards-prod.iam.gserviceaccount.com
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