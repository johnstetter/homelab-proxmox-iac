# Extract Proxmox host IP from API URL
locals {
  proxmox_host = regex("https://([^:]+):", var.proxmox_api_url)[0]

  # Combined SSH keys for all VMs (newline separated)
  combined_ssh_keys = "${tls_private_key.k8s_ssh_key.public_key_openssh}\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZf7VzaIaxgfP3Jf2F2YfruyTmRF9Q2+ulbo/1K3gcP ansible@ansible.slowplanet.net"
}

# Generate SSH key pair for VM access
resource "tls_private_key" "k8s_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "k8s_private_key" {
  content         = tls_private_key.k8s_ssh_key.private_key_pem
  filename        = "${path.module}/ssh_keys/k8s_private_key.pem"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "k8s_public_key" {
  content         = tls_private_key.k8s_ssh_key.public_key_openssh
  filename        = "${path.module}/ssh_keys/k8s_public_key.pub"
  file_permission = "0644"
}

# Random suffix for unique resource naming
resource "random_string" "cluster_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Kubernetes Control Plane Nodes
module "k8s_control_plane" {
  source = "./modules/proxmox_vm"
  count  = var.control_plane_count

  # VM Configuration
  vm_name      = "${var.cluster_name}-control-${count.index + 1}-${random_string.cluster_suffix.result}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  proxmox_host = local.proxmox_host

  # Resource Allocation
  cores        = var.control_plane_cores
  memory       = var.control_plane_memory
  disk_size    = var.control_plane_disk_size
  disk_storage = var.disk_storage

  # Network Configuration
  network_bridge = var.network_bridge
  network_vlan   = var.network_vlan
  ip_address     = "${var.control_plane_ip_base}${count.index + 1}/${var.network_cidr}"
  gateway        = var.network_gateway
  nameserver     = var.nameserver

  # SSH Configuration
  ssh_user       = var.ssh_user
  ssh_public_key = local.combined_ssh_keys

  # NixOS configuration path (for Phase 2 implementation)
  nixos_config_path = "${path.root}/../nixos/${var.environment}/control.nix"

  # Tags
  tags = "k8s,control-plane,${var.environment}"
}

# Kubernetes Worker Nodes
module "k8s_worker_nodes" {
  source = "./modules/proxmox_vm"
  count  = var.worker_node_count

  # VM Configuration
  vm_name      = "${var.cluster_name}-worker-${count.index + 1}-${random_string.cluster_suffix.result}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  proxmox_host = local.proxmox_host

  # Resource Allocation
  cores        = var.worker_node_cores
  memory       = var.worker_node_memory
  disk_size    = var.worker_node_disk_size
  disk_storage = var.disk_storage

  # Network Configuration
  network_bridge = var.network_bridge
  network_vlan   = var.network_vlan
  ip_address     = "${var.worker_node_ip_base}${count.index + 1}/${var.network_cidr}"
  gateway        = var.network_gateway
  nameserver     = var.nameserver

  # SSH Configuration
  ssh_user       = var.ssh_user
  ssh_public_key = local.combined_ssh_keys

  # NixOS configuration path (for Phase 2 implementation)
  nixos_config_path = "${path.root}/../nixos/${var.environment}/worker.nix"

  # Tags
  tags = "k8s,worker,${var.environment}"
}

# Load Balancer for Control Plane (optional)
module "k8s_load_balancer" {
  source = "./modules/proxmox_vm"
  count  = var.enable_load_balancer ? 1 : 0

  # VM Configuration
  vm_name      = "${var.cluster_name}-lb-${random_string.cluster_suffix.result}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  proxmox_host = local.proxmox_host

  # Resource Allocation
  cores        = var.load_balancer_cores
  memory       = var.load_balancer_memory
  disk_size    = var.load_balancer_disk_size
  disk_storage = var.disk_storage

  # Network Configuration
  network_bridge = var.network_bridge
  network_vlan   = var.network_vlan
  ip_address     = "${var.load_balancer_ip}/${var.network_cidr}"
  gateway        = var.network_gateway
  nameserver     = var.nameserver

  # SSH Configuration
  ssh_user       = var.ssh_user
  ssh_public_key = local.combined_ssh_keys

  # Load balancer will use basic NixOS configuration
  # HAProxy configuration will be handled in NixOS config
  nixos_config_path = "${path.root}/../nixos/common/configuration.nix"

  # Tags
  tags = "k8s,load-balancer,${var.environment}"
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    control_plane_nodes = module.k8s_control_plane[*]
    worker_nodes        = module.k8s_worker_nodes[*]
    load_balancer       = var.enable_load_balancer ? module.k8s_load_balancer[0] : null
    ssh_user            = var.ssh_user
    ssh_private_key     = "${path.module}/ssh_keys/k8s_private_key.pem"
  })
  filename = "${path.module}/inventory/hosts.yml"
}

# Generate kubeconfig template
resource "local_file" "kubeconfig_template" {
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name       = var.cluster_name
    control_plane_ip   = var.enable_load_balancer ? var.load_balancer_ip : "${var.control_plane_ip_base}1"
    control_plane_port = var.kubernetes_api_port
  })
  filename = "${path.module}/kubeconfig/kubeconfig-template.yml"
}
