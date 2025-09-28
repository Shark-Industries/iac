# Using Cloudflare for Free DNS

This guide explains how to use Cloudflare's free tier for DNS instead of Google Cloud DNS, reducing your monthly costs to essentially zero (just domain registration).

## Why Cloudflare?

- **Free DNS hosting** (vs $0.20/month for Cloud DNS)
- **Free SSL certificates**
- **Free CDN and caching**
- **DDoS protection**
- **API for dynamic DNS updates**

## Setup Steps

### 1. Create Cloudflare Account

1. Sign up at [cloudflare.com](https://www.cloudflare.com)
2. Add your domain (`sharkoutboards.com`)
3. Cloudflare will scan existing DNS records

### 2. Update Nameservers

At your domain registrar, change nameservers to Cloudflare's (provided during setup):
- Example: `ns1.cloudflare.com`, `ns2.cloudflare.com`

### 3. Configure Terraform

In `environments/prod/terraform.tfvars`:

```hcl
use_static_ip = false      # Use free dynamic IP
dns_provider  = "external"  # Skip Cloud DNS creation
```

### 4. Set Up Dynamic DNS Updates

Create a Cloudflare API token:
1. Go to My Profile → API Tokens
2. Create token with permissions:
   - Zone → DNS → Edit
   - Zone Resources → Include → Specific zone → sharkoutboards.com

On your VM, create `/usr/local/bin/update-cloudflare-dns.sh`:

```bash
#!/bin/bash

# Cloudflare settings
CF_API_TOKEN="your-api-token"
CF_ZONE_ID="your-zone-id"
DOMAIN="sharkoutboards.com"

# Get current external IP
CURRENT_IP=$(curl -s https://ipinfo.io/ip)

# Update A records via Cloudflare API
update_record() {
    local record_name=$1
    local record_id=$2

    curl -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
         -H "Authorization: Bearer $CF_API_TOKEN" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$CURRENT_IP\",\"ttl\":60}"
}

# Get record IDs (run once to find these)
# curl -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
#      -H "Authorization: Bearer $CF_API_TOKEN"

# Update records (replace with actual record IDs)
update_record "@" "root-record-id"
update_record "www" "www-record-id"
update_record "mail" "mail-record-id"
```

### 5. Add Cron Job

```bash
crontab -e
```

Add:
```
*/5 * * * * /usr/local/bin/update-cloudflare-dns.sh
```

## DNS Records to Create in Cloudflare

| Type | Name | Content | TTL | Proxy |
|------|------|---------|-----|-------|
| A | @ | VM_IP | 60 | No |
| A | www | VM_IP | 60 | Yes (for CDN) |
| A | mail | VM_IP | 60 | No |
| MX | @ | mail.sharkoutboards.com | 300 | - |

## Cost Comparison

| Setup | Monthly Cost | Features |
|-------|--------------|----------|
| GCP Static IP + Cloud DNS | ~$3.20 | Most reliable, no IP changes |
| GCP Dynamic IP + Cloud DNS | ~$0.20 | IP may change on restart |
| GCP Dynamic IP + Cloudflare | ~$0.00 | Free CDN, SSL, DDoS protection |

## Notes

- The VM's IP will change if it's stopped/started (not rebooted)
- The DNS update script runs every 5 minutes to catch IP changes
- Cloudflare's proxy (orange cloud) provides CDN but can't be used for mail
- Keep mail subdomain with proxy disabled (gray cloud)