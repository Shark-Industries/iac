output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = local.vm_external_ip
}

output "vm_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.main_vm.name
}

output "dns_zone_name" {
  description = "Name of the DNS managed zone"
  value       = var.dns_provider == "gcp" ? google_dns_managed_zone.main[0].name : "N/A - Using external DNS"
}

output "dns_name_servers" {
  description = "Name servers for the DNS zone"
  value       = var.dns_provider == "gcp" ? google_dns_managed_zone.main[0].name_servers : ["Using external DNS provider"]
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.main.name
}

output "ip_type" {
  description = "Type of IP address being used"
  value       = var.use_static_ip ? "Static IP (~$3/month)" : "Dynamic IP (free)"
}

output "monthly_cost_estimate" {
  description = "Estimated monthly cost"
  value       = var.use_static_ip ? "~$3.20/month (Static IP + Cloud DNS)" : "~$0.20/month (Cloud DNS only)"
}