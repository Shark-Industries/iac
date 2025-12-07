# Shark Outboards - Infrastructure as Code

This repository contains the Terraform configuration for Shark Outboards' Google Cloud Platform infrastructure.

## Architecture

- **Single GCP Project**: `shark-outboards-pro`
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
   gcloud projects create shark-outboards-pro --name="Shark Outboards Production"
   ```

2. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com dns.googleapis.com --project=shark-outboards-pro
   ```

3. Create a service account for Terraform:
   ```bash
   gcloud iam service-accounts create terraform --project=shark-outboards-pro
   ```

4. Set up authentication (save key locally, never commit):
   ```bash
   gcloud iam service-accounts keys create ~/terraform-key.json \
     --iam-account=terraform@shark-outboards-pro.iam.gserviceaccount.com
   ```

## Deployment

From the appropriate environment directory:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Current Infrastructure Status

**LIVE PRODUCTION SYSTEM**
- **Project**: shark-outboards (417349761648)
- **VM**: prod-web-mail-server (34.30.150.73)
- **SSH Access**: Configured for admin user
- **Email Server**: Postfix running and configured

### SSH Access
```bash
ssh admin@34.30.150.73
```

### DNS Nameservers (for Route53)
```
ns-cloud-c1.googledomains.com
ns-cloud-c2.googledomains.com
ns-cloud-c3.googledomains.com
ns-cloud-c4.googledomains.com
```

### Email Configuration
Edit forwarding rules:
```bash
sudo nano /etc/postfix/virtual
sudo postmap /etc/postfix/virtual
sudo systemctl reload postfix
```

## Infrastructure as Code

Your SSH key is configured in `environments/prod/variables.tf`. When recreating:
- VM will automatically include your SSH key
- Email forwarding will be pre-configured
- DNS records will be set up automatically

## GitHub Actions

Automated deployment is configured via GitHub Actions on push to main branch.