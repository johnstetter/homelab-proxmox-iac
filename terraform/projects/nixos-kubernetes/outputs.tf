# SSH Key Information
output "ssh_private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.k8s_private_key.filename
  sensitive   = true
}

output "ssh_public_key_path" {
  description = "Path to the generated SSH public key"
  value       = local_file.k8s_public_key.filename
}

output "ssh_public_key" {
  description = "SSH public key content"
  value       = tls_private_key.k8s_ssh_key.public_key_openssh
}

# Cluster Information
output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "cluster_suffix" {
  description = "Random suffix used for resource naming"
  value       = random_string.cluster_suffix.result
}

# Control Plane Nodes
output "control_plane_nodes" {
  description = "Information about control plane nodes"
  value = {
    for i, node in module.k8s_control_plane : i => {
      name           = node.vm_name
      ip_address     = node.ip_address
      vm_id          = node.vm_id
      ssh_connection = node.ssh_connection
    }
  }
}

output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = [for node in module.k8s_control_plane : node.ip_address]
}

# Worker Nodes
output "worker_nodes" {
  description = "Information about worker nodes"
  value = {
    for i, node in module.k8s_worker_nodes : i => {
      name           = node.vm_name
      ip_address     = node.ip_address
      vm_id          = node.vm_id
      ssh_connection = node.ssh_connection
    }
  }
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value       = [for node in module.k8s_worker_nodes : node.ip_address]
}

# Load Balancer (if enabled)
output "load_balancer" {
  description = "Information about load balancer"
  value = var.enable_load_balancer ? {
    name           = module.k8s_load_balancer[0].vm_name
    ip_address     = module.k8s_load_balancer[0].ip_address
    vm_id          = module.k8s_load_balancer[0].vm_id
    ssh_connection = module.k8s_load_balancer[0].ssh_connection
  } : null
}

output "load_balancer_ip" {
  description = "IP address of load balancer (if enabled)"
  value       = var.enable_load_balancer ? module.k8s_load_balancer[0].ip_address : null
}

# Kubernetes Configuration
output "kubernetes_api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = var.enable_load_balancer ? "https://${var.load_balancer_ip}:${var.kubernetes_api_port}" : "https://${var.control_plane_ip_base}1:${var.kubernetes_api_port}"
}

output "kubernetes_api_port" {
  description = "Kubernetes API server port"
  value       = var.kubernetes_api_port
}

# Generated Files
output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "kubeconfig_template_path" {
  description = "Path to generated kubeconfig template"
  value       = local_file.kubeconfig_template.filename
}

# Network Information
output "network_configuration" {
  description = "Network configuration details"
  value = {
    bridge     = var.network_bridge
    vlan       = var.network_vlan
    cidr       = var.network_cidr
    gateway    = var.network_gateway
    nameserver = var.nameserver
  }
}

# SSH Connection Commands
output "ssh_commands" {
  description = "SSH commands to connect to nodes"
  value = {
    control_plane = [
      for node in module.k8s_control_plane :
      "ssh -i ${local_file.k8s_private_key.filename} ${node.ssh_connection}"
    ]
    workers = [
      for node in module.k8s_worker_nodes :
      "ssh -i ${local_file.k8s_private_key.filename} ${node.ssh_connection}"
    ]
    load_balancer = var.enable_load_balancer ? [
      "ssh -i ${local_file.k8s_private_key.filename} ${module.k8s_load_balancer[0].ssh_connection}"
    ] : []
  }
}

# Quick Start Information
output "quick_start_info" {
  description = "Quick start information for the cluster"
  value       = <<-EOT
    Kubernetes Cluster: ${var.cluster_name}
    
    Control Plane Nodes: ${length(module.k8s_control_plane)}
    Worker Nodes: ${length(module.k8s_worker_nodes)}
    Load Balancer: ${var.enable_load_balancer ? "Enabled" : "Disabled"}
    
    API Endpoint: ${var.enable_load_balancer ? "https://${var.load_balancer_ip}:${var.kubernetes_api_port}" : "https://${var.control_plane_ip_base}1:${var.kubernetes_api_port}"}
    
    SSH Private Key: ${local_file.k8s_private_key.filename}
    Ansible Inventory: ${local_file.ansible_inventory.filename}
    
    Next Steps:
    1. Configure kubectl with the generated kubeconfig
    2. Use Ansible inventory to configure Kubernetes
    3. Install CNI plugin (Flannel, Calico, etc.)
    4. Join worker nodes to the cluster
  EOT
}
