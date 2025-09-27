output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = google_compute_address.vm_ip.address
}

output "vm_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.main_vm.name
}

output "dns_zone_name" {
  description = "Name of the DNS managed zone"
  value       = google_dns_managed_zone.main.name
}

output "dns_name_servers" {
  description = "Name servers for the DNS zone"
  value       = google_dns_managed_zone.main.name_servers
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.main.name
}