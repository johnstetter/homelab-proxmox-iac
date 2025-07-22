
# Proxmox Provider Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = ""
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  default     = ""
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_parallel" {
  description = "Number of parallel operations for Proxmox"
  type        = number
  default     = 2
}

variable "proxmox_timeout" {
  description = "Timeout for Proxmox operations"
  type        = number
  default     = 300
}

variable "proxmox_debug" {
  description = "Enable debug mode for Proxmox provider"
  type        = bool
  default     = false
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Proxmox Infrastructure
variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
}

variable "vm_template" {
  description = "VM template name to clone from"
  type        = string
}

variable "disk_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# Control Plane Configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.control_plane_count >= 1 && var.control_plane_count <= 5
    error_message = "Control plane count must be between 1 and 5."
  }
}

variable "control_plane_cores" {
  description = "Number of CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 4096
}

variable "control_plane_disk_size" {
  description = "Disk size in GB for control plane nodes"
  type        = string
  default     = "50G"
}

variable "control_plane_ip_base" {
  description = "Base IP address for control plane nodes (without last octet)"
  type        = string
  default     = "192.168.1.10"
}

# Worker Node Configuration
variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 10
    error_message = "Worker node count must be between 1 and 10."
  }
}

variable "worker_node_cores" {
  description = "Number of CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_node_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 8192
}

variable "worker_node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = string
  default     = "100G"
}

variable "worker_node_ip_base" {
  description = "Base IP address for worker nodes (without last octet)"
  type        = string
  default     = "192.168.1.20"
}

# Load Balancer Configuration
variable "enable_load_balancer" {
  description = "Enable load balancer for control plane"
  type        = bool
  default     = false
}

variable "load_balancer_cores" {
  description = "Number of CPU cores for load balancer"
  type        = number
  default     = 1
}

variable "load_balancer_memory" {
  description = "Memory in MB for load balancer"
  type        = number
  default     = 2048
}

variable "load_balancer_disk_size" {
  description = "Disk size in GB for load balancer"
  type        = string
  default     = "20G"
}

variable "load_balancer_ip" {
  description = "IP address for load balancer"
  type        = string
  default     = "192.168.1.100"
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "network_vlan" {
  description = "VLAN tag for network (optional)"
  type        = number
  default     = null
}

variable "network_cidr" {
  description = "Network CIDR suffix (e.g., 24 for /24)"
  type        = string
  default     = "24"
}

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "192.168.1.1"
}

variable "nameserver" {
  description = "DNS nameserver IP address"
  type        = string
  default     = "8.8.8.8"
}

# SSH Configuration
variable "ssh_user" {
  description = "SSH username for VM access"
  type        = string
  default     = "ubuntu"
}

# Kubernetes Configuration
variable "kubernetes_api_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6443
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28.0"
}

variable "pod_subnet" {
  description = "Pod network subnet"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_subnet" {
  description = "Service network subnet"
  type        = string
  default     = "10.96.0.0/12"
}