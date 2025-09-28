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

  # DNS update script for dynamic IP
  dns_update_script = var.dns_provider == "gcp" && !var.use_static_ip ? <<-SCRIPT
    # Update Cloud DNS with current IP
    ZONE="${var.environment}-dns-zone"
    DOMAIN="${var.domain_name}"
    CURRENT_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")

    # Update A records via gcloud
    gcloud dns record-sets update $DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
    gcloud dns record-sets update www.$DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
    gcloud dns record-sets update mail.$DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
  SCRIPT : ""
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
    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx postfix curl

    # Basic nginx setup
    systemctl start nginx
    systemctl enable nginx

    # Basic postfix setup for email forwarding (to be configured later)
    systemctl start postfix
    systemctl enable postfix

    ${local.dns_update_script}

    # Set up a cron job to update DNS if using dynamic IP with GCP DNS
    ${var.dns_provider == "gcp" && !var.use_static_ip ? <<-CRON
    cat > /etc/cron.d/update-dns <<'CRONEOF'
    */5 * * * * root /usr/local/bin/update-dns.sh
    CRONEOF

    cat > /usr/local/bin/update-dns.sh <<'DNSEOF'
    #!/bin/bash
    ZONE="${var.environment}-dns-zone"
    DOMAIN="${var.domain_name}"
    CURRENT_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
    RECORDED_IP=$(dig +short @8.8.8.8 $DOMAIN)

    if [ "$CURRENT_IP" != "$RECORDED_IP" ]; then
      gcloud dns record-sets update $DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
      gcloud dns record-sets update www.$DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
      gcloud dns record-sets update mail.$DOMAIN --type=A --zone=$ZONE --rrdatas=$CURRENT_IP --ttl=60
    fi
    DNSEOF

    chmod +x /usr/local/bin/update-dns.sh
    CRON : ""}
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