# Kubernetes Infrastructure on Proxmox with Terraform

This Terraform module provisions a complete Kubernetes cluster infrastructure on Proxmox using NixOS templates and automated deployment.

## 🎯 Overview

A production-ready Kubernetes infrastructure using:
- **Terraform** for infrastructure provisioning on Proxmox
- **NixOS** with automated template creation and installation
- **Cloud-init** for post-deployment configuration
- **NFS integration** for shared storage

## Features

- **Automated NixOS template creation** with base system installation
- **Multi-node Kubernetes cluster** with configurable control plane and worker nodes  
- **LVM storage** with resize capabilities
- **NFS client support** for shared storage (Synology NAS)
- **Cloud-init integration** for post-deployment configuration
- **SSH key generation** for secure access
- **Ansible inventory generation** for cluster configuration
- **Kubeconfig template** for kubectl access

## Architecture

- **Base Template**: Single NixOS template with automated installation
- **Storage**: LVM-based with 20GB default disk size (expandable)
- **Networking**: Bridge networking with DHCP
- **Storage Integration**: NFS mount at `/mnt/nfs` for cluster storage

## Prerequisites

1. **Proxmox VE** server with API access
2. **Nix package manager** for template creation
3. **Terraform** >= 1.0
4. **SSH access** to Proxmox server

### Setup Steps

1. **Install Nix** (for template creation):
   ```bash
   curl -L https://nixos.org/nix/install | sh
   source ~/.nix-profile/etc/profile.d/nix.sh
   nix profile add nixpkgs#nixos-generators
   ```

2. **Create Proxmox API token**:
   - In Proxmox web UI: Datacenter > Permissions > API Tokens
   - Create token: `terraform@pve!terraform`

3. **Create NixOS template**:
   ```bash
   # Generate ISO and create template
   ./scripts/build-and-deploy-template.sh --proxmox-host <proxmox-ip>
   ```

## Quick Start

1. **Configure Terraform**:
   ```bash
   cd terraform/
   
   # Copy and customize configuration
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Proxmox details
   ```

2. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Access your cluster**:
   ```bash
   # SSH to control plane
   ssh -i ssh_keys/k8s_private_key.pem nixos@<control-plane-ip>
   
   # NFS mount available at /mnt/nfs on all nodes
   ```

## Configuration

### Key Variables

```hcl
# Proxmox connection
proxmox_host = "192.168.1.5"
proxmox_user = "terraform@pve!terraform"
proxmox_token = "your-token-here"

# Template and storage
vm_template = "nixos-base-template"
disk_storage = "local-lvm"
iso_storage = "local"

# Cluster sizing
control_plane_count = 1
worker_node_count = 2

# Network (DHCP-based)
network_bridge = "vmbr0"
```

### Template Creation

The NixOS template includes:
- Automated installation with LVM partitioning
- NFS client support for shared storage
- Cloud-init for post-deployment configuration
- SSH access with generated keys

## Generated Files

After deployment, the module generates several useful files:

- `ssh_keys/k8s_private_key.pem` - SSH private key for cluster access
- `ssh_keys/k8s_public_key.pub` - SSH public key
- `inventory/hosts.yml` - Ansible inventory for cluster configuration
- `kubeconfig/kubeconfig-template.yml` - Kubeconfig template

## Outputs

The module provides comprehensive outputs for integration:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output control_plane_ips
terraform output worker_node_ips
terraform output ssh_commands
terraform output quick_start_info
```

## Scripts

- `scripts/build-and-deploy-template.sh` - Complete template creation pipeline
- `scripts/generate-nixos-iso.sh` - Generate NixOS ISO
- `scripts/create-proxmox-template.sh` - Create Proxmox template

## Directory Structure

```
k8s-infra/
├── terraform/                 # Terraform infrastructure code
│   ├── main.tf               # Main infrastructure definition
│   ├── variables.tf          # Input variables  
│   ├── outputs.tf            # Output values
│   └── modules/
│       └── proxmox_vm/       # Reusable VM module
├── nixos/                    # NixOS configurations
│   ├── base-template.nix     # Base template with auto-install
│   └── roles/               # Role-specific configs
│       ├── control-plane.nix
│       └── worker.nix
└── scripts/                  # Automation scripts
    ├── build-and-deploy-template.sh
    ├── generate-nixos-iso.sh
    └── create-proxmox-template.sh
```