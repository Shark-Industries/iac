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

# Static IP for VM
resource "google_compute_address" "vm_ip" {
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

    access_config {
      nat_ip = google_compute_address.vm_ip.address
    }
  }

  metadata = {
    ssh-keys = join("\n", [for key in var.ssh_public_keys : "admin:${key}"])
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx postfix

    # Basic nginx setup
    systemctl start nginx
    systemctl enable nginx

    # Basic postfix setup for email forwarding (to be configured later)
    systemctl start postfix
    systemctl enable postfix
  EOF
}

# Cloud DNS Zone
resource "google_dns_managed_zone" "main" {
  name        = "${var.environment}-dns-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.domain_name}"
  project     = var.project_id
}

# DNS A Record for root domain
resource "google_dns_record_set" "a_record" {
  name         = google_dns_managed_zone.main.dns_name
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_address.vm_ip.address]
  project      = var.project_id
}

# DNS A Record for www
resource "google_dns_record_set" "www_record" {
  name         = "www.${google_dns_managed_zone.main.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_address.vm_ip.address]
  project      = var.project_id
}

# DNS MX Record for email
resource "google_dns_record_set" "mx_record" {
  name         = google_dns_managed_zone.main.dns_name
  type         = "MX"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = ["10 mail.${var.domain_name}."]
  project      = var.project_id
}

# DNS A Record for mail subdomain
resource "google_dns_record_set" "mail_record" {
  name         = "mail.${google_dns_managed_zone.main.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_address.vm_ip.address]
  project      = var.project_id
}