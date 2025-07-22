# VM Information
output "vm_id" {
  description = "The ID of the created VM"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "The name of the created VM"
  value       = proxmox_vm_qemu.vm.name
}

output "vm_node" {
  description = "The Proxmox node where the VM is running"
  value       = proxmox_vm_qemu.vm.target_node
}

# Network Information
output "ip_address" {
  description = "The IP address of the VM"
  value       = split("/", var.ip_address)[0]
}

output "ip_address_cidr" {
  description = "The IP address with CIDR notation"
  value       = var.ip_address
}

output "ssh_user" {
  description = "SSH username for the VM"
  value       = var.ssh_user
}

# Resource Information
output "cores" {
  description = "Number of CPU cores assigned to the VM"
  value       = var.cores
}

output "memory" {
  description = "Memory in MB assigned to the VM"
  value       = proxmox_vm_qemu.vm.memory
}

# Connection Information
output "ssh_connection" {
  description = "SSH connection string"
  value       = "${var.ssh_user}@${split("/", var.ip_address)[0]}"
}

# VM Status
output "vm_status" {
  description = "Current status of the VM"
  value       = "created" # Static value since vm_state attribute doesn't exist
}

# Tags
output "tags" {
  description = "Tags assigned to the VM"
  value       = var.tags
}
