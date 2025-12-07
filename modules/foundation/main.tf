terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.environment}-network"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "main" {
  name          = "${var.environment}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.main.id
  region        = var.region
  project       = var.project_id
}

# Static IP for VM (optional - costs ~$3/month)
resource "google_compute_address" "vm_ip" {
  count   = var.use_static_ip ? 1 : 0
  name    = "${var.environment}-vm-ip"
  region  = var.region
  project = var.project_id
}

# Firewall rule for HTTP
resource "google_compute_firewall" "http" {
  name    = "${var.environment}-allow-http"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Firewall rule for HTTPS
resource "google_compute_firewall" "https" {
  name    = "${var.environment}-allow-https"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Firewall rule for SSH
resource "google_compute_firewall" "ssh" {
  name    = "${var.environment}-allow-ssh"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
}

# Firewall rule for Email (SMTP)
resource "google_compute_firewall" "smtp" {
  name    = "${var.environment}-allow-smtp"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["25", "587", "465"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mail-server"]
}

locals {
  # Get the actual IP: static if configured, otherwise use the ephemeral IP
  vm_external_ip = var.use_static_ip ? google_compute_address.vm_ip[0].address : google_compute_instance.main_vm.network_interface[0].access_config[0].nat_ip
}

# Compute Instance
resource "google_compute_instance" "main_vm" {
  name         = "${var.environment}-web-mail-server"
  machine_type = var.vm_machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["web-server", "mail-server", "ssh-access"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.vm_boot_disk_size
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.main.id

    # Dynamic config for access - static IP if available, otherwise ephemeral
    dynamic "access_config" {
      for_each = [1]
      content {
        nat_ip = var.use_static_ip ? google_compute_address.vm_ip[0].address : null
      }
    }
  }

  metadata = {
    ssh-keys = join("\n", [for key in var.ssh_public_keys : "admin:${key}"])
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Log everything to startup script log
    exec > >(tee -a /var/log/startup-script.log) 2>&1
    echo "Starting startup script at $(date)"

    # Update package list
    apt-get update

    # Set non-interactive mode to avoid prompts
    export DEBIAN_FRONTEND=noninteractive

    # Pre-configure Postfix before installation
    debconf-set-selections <<< "postfix postfix/mailname string ${var.domain_name}"
    debconf-set-selections <<< "postfix postfix/main_mailer_type select Internet Site"

    # Install packages
    apt-get install -y nginx certbot python3-certbot-nginx postfix curl
    echo "Packages installed successfully"

    # Basic nginx setup
    systemctl start nginx
    systemctl enable nginx
    echo "Nginx started and enabled"

    # Create basic postfix configuration
    cat > /etc/postfix/main.cf <<'POSTFIXEOF'
# Basic configuration
smtpd_banner = $myhostname ESMTP $mail_name (Shark Outboards Mail Server)
biff = no
append_dot_mydomain = no
readme_directory = no

# Network settings
inet_interfaces = all
inet_protocols = ipv4
mydestination = ${var.domain_name}, localhost
myhostname = mail.${var.domain_name}
myorigin = ${var.domain_name}

# Virtual alias setup for forwarding
virtual_alias_domains = ${var.domain_name}
virtual_alias_maps = hash:/etc/postfix/virtual

# Security and anti-spam basics
smtpd_helo_required = yes
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
disable_vrfy_command = yes

# TLS support
smtpd_use_tls = yes
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level = may

# Relay configuration with fallback ports
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_fallback_relay = [smtp.gmail.com]:25,[smtp.gmail.com]:465
POSTFIXEOF
    echo "Postfix main.cf created"

    # Create virtual aliases file with Simon's forwarding rules
    cat > /etc/postfix/virtual <<'VIRTUALEOF'
# Simon's Email forwarding rules
simon@${var.domain_name}                simon.cederqvist@gmail.com
simon.cederqvist@${var.domain_name}     simon.cederqvist@gmail.com

# Additional forwarding rules can be added here
# Format: incoming@${var.domain_name} destination@example.com
VIRTUALEOF
    echo "Virtual aliases file created"

    # Generate virtual alias database
    postmap /etc/postfix/virtual
    echo "Virtual alias database generated"

    # Restart and enable postfix
    systemctl restart postfix
    systemctl enable postfix
    echo "Postfix restarted and enabled"

    echo "Startup script completed successfully at $(date)"
  EOF
}

# Cloud DNS Zone (only if using GCP DNS)
resource "google_dns_managed_zone" "main" {
  count       = var.dns_provider == "gcp" ? 1 : 0
  name        = "${var.environment}-dns-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.domain_name}"
  project     = var.project_id
}

# DNS A Record for root domain
resource "google_dns_record_set" "a_record" {
  count        = var.dns_provider == "gcp" ? 1 : 0
  name         = google_dns_managed_zone.main[0].dns_name
  type         = "A"
  ttl          = var.use_static_ip ? 300 : 60  # Lower TTL for dynamic IP
  managed_zone = google_dns_managed_zone.main[0].name
  rrdatas      = [local.vm_external_ip]
  project      = var.project_id
}

# DNS A Record for www
resource "google_dns_record_set" "www_record" {
  count        = var.dns_provider == "gcp" ? 1 : 0
  name         = "www.${google_dns_managed_zone.main[0].dns_name}"
  type         = "A"
  ttl          = var.use_static_ip ? 300 : 60  # Lower TTL for dynamic IP
  managed_zone = google_dns_managed_zone.main[0].name
  rrdatas      = [local.vm_external_ip]
  project      = var.project_id
}

# DNS MX Record for email
resource "google_dns_record_set" "mx_record" {
  count        = var.dns_provider == "gcp" ? 1 : 0
  name         = google_dns_managed_zone.main[0].dns_name
  type         = "MX"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main[0].name
  rrdatas      = ["10 mail.${var.domain_name}."]
  project      = var.project_id
}

# DNS A Record for mail subdomain
resource "google_dns_record_set" "mail_record" {
  count        = var.dns_provider == "gcp" ? 1 : 0
  name         = "mail.${google_dns_managed_zone.main[0].dns_name}"
  type         = "A"
  ttl          = var.use_static_ip ? 300 : 60  # Lower TTL for dynamic IP
  managed_zone = google_dns_managed_zone.main[0].name
  rrdatas      = [local.vm_external_ip]
  project      = var.project_id
}

# Enable required Google Cloud APIs
resource "google_project_service" "monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"
}

resource "google_project_service" "logging" {
  project = var.project_id
  service = "logging.googleapis.com"
}

# Update Route53 domain nameservers to point to Google Cloud DNS
resource "aws_route53domains_registered_domain" "main" {
  count       = var.dns_provider == "gcp" ? 1 : 0
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = google_dns_managed_zone.main[0].name_servers
    content {
      name = name_server.value
    }
  }

  depends_on = [google_dns_managed_zone.main]
}

# Note: Advanced monitoring disabled for initial deployment
# You can set up monitoring through the GCP Console after deployment