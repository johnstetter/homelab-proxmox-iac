# Ubuntu Servers Infrastructure
# Simple Ubuntu server deployments for Ansible-managed workloads

# Extract Proxmox host IP from API URL
locals {
  proxmox_host = regex("https://([^:]+):", var.proxmox_api_url)[0]

  # Combined SSH keys for all VMs (newline separated)
  combined_ssh_keys = "${tls_private_key.ubuntu_ssh_key.public_key_openssh}\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZf7VzaIaxgfP3Jf2F2YfruyTmRF9Q2+ulbo/1K3gcP ansible@ansible.slowplanet.net"
}

# Generate SSH key pair for VM access
resource "tls_private_key" "ubuntu_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "ubuntu_private_key" {
  content         = tls_private_key.ubuntu_ssh_key.private_key_pem
  filename        = "${path.module}/ssh_keys/ubuntu_private_key.pem"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "ubuntu_public_key" {
  content         = tls_private_key.ubuntu_ssh_key.public_key_openssh
  filename        = "${path.module}/ssh_keys/ubuntu_public_key.pub"
  file_permission = "0644"
}

# Random suffix for unique resource naming
resource "random_string" "server_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Ubuntu Servers
module "ubuntu_servers" {
  source = "../../modules/proxmox_vm"
  count  = var.server_count

  # VM Configuration
  vm_name      = "${var.server_name_prefix}-${count.index + 1}-${random_string.server_suffix.result}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  proxmox_host = local.proxmox_host

  # Resource Allocation
  cores        = var.server_cores
  memory       = var.server_memory
  disk_size    = var.server_disk_size
  disk_storage = var.disk_storage

  # Network Configuration
  network_bridge = var.network_bridge
  network_vlan   = var.network_vlan
  ip_address     = "${var.server_ip_base}${count.index + 1}/${var.network_cidr}"
  gateway        = var.network_gateway
  nameserver     = var.nameserver

  # SSH Configuration
  ssh_user       = var.ssh_user
  ssh_public_key = local.combined_ssh_keys

  # Ubuntu servers don't need NixOS config path
  # nixos_config_path is handled by the module but not used for Ubuntu

  # Tags
  tags = "ubuntu,server,${var.environment}"
}

# Generate Ansible inventory file for Ubuntu servers
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    servers         = module.ubuntu_servers[*]
    ssh_user        = var.ssh_user
    ssh_private_key = "${path.module}/ssh_keys/ubuntu_private_key.pem"
  })
  filename = "${path.module}/inventory/hosts.yml"
}