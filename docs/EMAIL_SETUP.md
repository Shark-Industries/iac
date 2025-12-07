# Email Forwarding Setup for Shark Outboards

This document explains how to set up email forwarding for your domain using the infrastructure deployed by this Terraform configuration.

## Overview

The infrastructure automatically configures:
- **Postfix mail server** on the VM for email forwarding
- **Firewall rules** for SMTP (ports 25, 587, 465)
- **DNS records** (MX and A records for mail subdomain)

## Cost

- **Free** - Uses existing VM, no additional GCP costs
- Works with both static IP (~$3.20/month) and dynamic IP (free) configurations

## Route53 DNS Configuration Required

Since your domain is hosted on Route53, you need to manually add these DNS records:

### If using GCP DNS (dns_provider = "gcp"):
1. **Add NS records** in Route53 pointing to the GCP name servers
2. **MX record**: `10 mail.yourdomain.com`
3. **A record**: `mail.yourdomain.com` → VM IP address

### If using Route53 directly (dns_provider = "route53"):
Add these records in your Route53 hosted zone:

```
# MX Record
yourdomain.com    MX    10 mail.yourdomain.com

# A Record for mail subdomain
mail.yourdomain.com    A    [VM_IP_ADDRESS]
```

## Email Forwarding Configuration

After deployment, SSH into your VM and configure email forwarding:

### 1. Edit the virtual aliases file:
```bash
sudo nano /etc/postfix/virtual
```

### 2. Add forwarding rules:
```
# Examples - customize for your needs:
info@yourdomain.com        your-email@gmail.com
sales@yourdomain.com       sales-team@gmail.com
admin@yourdomain.com       admin@gmail.com
support@yourdomain.com     support@yourcompany.com

# Catch-all (forward any unmatched emails)
@yourdomain.com           catchall@gmail.com
```

### 3. Update the alias database:
```bash
sudo postmap /etc/postfix/virtual
sudo systemctl reload postfix
```

## Testing

1. **Test DNS resolution**:
   ```bash
   dig MX yourdomain.com
   dig mail.yourdomain.com
   ```

2. **Test email forwarding**:
   - Send an email to one of your configured addresses
   - Check that it arrives at the destination

3. **Check mail logs**:
   ```bash
   sudo tail -f /var/log/mail.log
   ```

## Security Considerations

- The configuration includes basic anti-spam measures
- TLS is enabled for encrypted connections
- Consider adding SPF, DKIM, and DMARC records for better deliverability

### Optional: Add SPF record to Route53:
```
yourdomain.com    TXT    "v=spf1 ip4:[VM_IP_ADDRESS] ~all"
```

## Troubleshooting

### Email not being received:
1. Check firewall rules: `sudo ufw status`
2. Check postfix status: `sudo systemctl status postfix`
3. Check DNS propagation: Use online DNS checker tools
4. Check mail logs: `sudo grep "postfix" /var/log/syslog`

### Emails not being forwarded:
1. Verify virtual aliases: `sudo cat /etc/postfix/virtual`
2. Regenerate alias database: `sudo postmap /etc/postfix/virtual`
3. Check postfix configuration: `sudo postconf -n`

## Dynamic IP Considerations

If using dynamic IP (free option):
- DNS records are updated every 5 minutes via cron job
- Email delivery might be delayed during IP changes
- Consider using static IP for critical email operations

## Limitations

- **Outgoing email**: This setup only handles email forwarding (incoming)
- **Spam filtering**: Basic protection only
- **Webmail**: No web interface provided (forwarding only)
- **Storage**: Emails are forwarded, not stored on the server