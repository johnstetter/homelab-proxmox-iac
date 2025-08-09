# Ubuntu Servers Outputs

# Server Information
output "ubuntu_servers" {
  description = "Ubuntu server details"
  value = {
    for i, server in module.ubuntu_servers : server.vm_name => {
      vm_id      = server.vm_id
      ip_address = server.ip_address
      ssh_user   = var.ssh_user
      node_name  = var.proxmox_node
    }
  }
}

# SSH Keys
output "ssh_private_key_file" {
  description = "Path to SSH private key file"
  value       = "${path.module}/ssh_keys/ubuntu_private_key.pem"
  sensitive   = true
}

output "ssh_public_key_file" {
  description = "Path to SSH public key file"  
  value       = "${path.module}/ssh_keys/ubuntu_public_key.pub"
}

# Ansible Inventory
output "ansible_inventory_file" {
  description = "Path to generated Ansible inventory file"
  value       = "${path.module}/inventory/hosts.yml"
}

# Connection Information
output "server_ips" {
  description = "List of server IP addresses"
  value       = [for server in module.ubuntu_servers : server.ip_address]
}

output "ssh_connection_commands" {
  description = "SSH connection commands for each server"
  value = [
    for server in module.ubuntu_servers : 
    "ssh -i ${path.module}/ssh_keys/ubuntu_private_key.pem ${var.ssh_user}@${server.ip_address}"
  ]
}