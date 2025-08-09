# Proxmox Provider Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.5:8006/api2/json"
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

# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Proxmox Infrastructure
variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "core"
}

variable "vm_template" {
  description = "VM template name to clone from"
  type        = string
  default     = "ubuntu-25.04-cloud-init"
}

variable "disk_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# Server Configuration
variable "server_count" {
  description = "Number of Ubuntu servers to create"
  type        = number
  default     = 2

  validation {
    condition     = var.server_count >= 1 && var.server_count <= 10
    error_message = "Server count must be between 1 and 10."
  }
}

variable "server_name_prefix" {
  description = "Prefix for server names"
  type        = string
  default     = "ubuntu-server"
}

# Resource Allocation
variable "server_cores" {
  description = "Number of CPU cores per server"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "Memory in MB per server"
  type        = number
  default     = 2048
}

variable "server_disk_size" {
  description = "Disk size in GB per server"
  type        = string
  default     = "20G"
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

variable "server_ip_base" {
  description = "Base IP address for servers (without last octet)"
  type        = string
  default     = "192.168.1.5"
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