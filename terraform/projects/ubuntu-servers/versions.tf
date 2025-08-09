terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc03"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}