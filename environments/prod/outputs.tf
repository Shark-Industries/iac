output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = module.foundation.vm_external_ip
}

output "dns_name_servers" {
  description = "Name servers for the DNS zone - update your domain registrar"
  value       = module.foundation.dns_name_servers
}

output "vm_ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh admin@${module.foundation.vm_external_ip}"
}