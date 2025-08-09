# Template Project Outputs

# SSH Keys
output "ssh_private_key_file" {
  description = "Path to SSH private key file"
  value       = "${path.module}/ssh_keys/project_private_key.pem"
  sensitive   = true
}

output "ssh_public_key_file" {
  description = "Path to SSH public key file"  
  value       = "${path.module}/ssh_keys/project_public_key.pub"
}

# Project Information
output "project_suffix" {
  description = "Random suffix used for resource naming"
  value       = random_string.project_suffix.result
}

# Example VM outputs (uncomment and modify as needed)
# output "project_vms" {
#   description = "VM details"
#   value = {
#     for i, vm in module.project_vms : vm.vm_name => {
#       vm_id      = vm.vm_id
#       ip_address = vm.ip_address
#       ssh_user   = var.ssh_user
#       node_name  = var.proxmox_node
#     }
#   }
# }

# output "vm_ips" {
#   description = "List of VM IP addresses"
#   value       = [for vm in module.project_vms : vm.ip_address]
# }

# output "ssh_connection_commands" {
#   description = "SSH connection commands for each VM"
#   value = [
#     for vm in module.project_vms : 
#     "ssh -i ${path.module}/ssh_keys/project_private_key.pem ${var.ssh_user}@${vm.ip_address}"
#   ]
# }