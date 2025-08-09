# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_username
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
  pm_parallel     = var.proxmox_parallel
  pm_timeout      = var.proxmox_timeout
  pm_debug        = var.proxmox_debug
}

# Random Provider for generating unique identifiers
provider "random" {}

# TLS Provider for SSH key generation
provider "tls" {}

# Local Provider for file operations
provider "local" {}