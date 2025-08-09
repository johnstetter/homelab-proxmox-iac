# Ubuntu Server Template Setup Guide

This guide walks through setting up Ubuntu Server templates for Proxmox and deploying them with Terraform for Ansible-managed workloads.

## Overview

The Ubuntu infrastructure setup provides:
- Automated Ubuntu 25.04 template creation
- Terraform-based server deployment  
- Ansible-ready configuration
- Separate state management from NixOS Kubernetes infrastructure

## Architecture

```
root-modules/
├── nixos-kubernetes/          # Existing K8s infrastructure  
├── ubuntu-servers/            # Ubuntu server deployments
└── shared-modules/            # Shared Proxmox VM module

ubuntu/
├── scripts/
│   ├── create-ubuntu-template.sh
│   └── build-and-deploy-ubuntu.sh
├── cloud-init/
│   └── ubuntu-cloud-init.yml
└── docs/
    └── UBUNTU-TEMPLATE-SETUP.md
```

## Prerequisites

- **Proxmox VE** server with API access
- **AWS account** for Terraform state backend
- **Terraform CLI** installed locally
- Proxmox API tokens configured (see [PROXMOX-API-SETUP.md](../../docs/PROXMOX-API-SETUP.md))

## Quick Start

### 1. Create Ubuntu Template

```bash
# Create the Ubuntu cloud-init template
cd ubuntu/scripts/
./create-ubuntu-template.sh

# Or with custom settings
TEMPLATE_ID=9001 TEMPLATE_NAME="ubuntu-25.04-custom" ./create-ubuntu-template.sh
```

### 2. Configure Environment

```bash
cd root-modules/ubuntu-servers/
cp environments/dev.tfvars.example environments/dev.tfvars
```

Update `environments/dev.tfvars` with your Proxmox and network settings:

```hcl
# Proxmox Configuration
proxmox_api_url          = "https://your-proxmox-ip:8006/api2/json"
proxmox_api_token_id     = "your-token-id"
proxmox_api_token_secret = "your-token-secret"
proxmox_node             = "your-node-name"

# Network Configuration  
server_ip_base  = "192.168.1.10"  # Results in .101, .102, etc.
network_gateway = "192.168.1.1"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/dev.tfvars"

# Deploy servers
terraform apply -var-file="environments/dev.tfvars"
```

### 4. Connect and Configure

```bash
# SSH to servers (output from terraform)
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.101

# Use Ansible with generated inventory
ansible-playbook -i inventory/hosts.yml your-playbook.yml
```

## Template Configuration

### Ubuntu Template Features

- **Ubuntu 25.04** - Latest release
- **Cloud-init ready** - Automated configuration
- **Python 3** - Ansible compatibility  
- **DevOps tools** - git, curl, jq, htop, vim
- **Security hardened** - UFW firewall, SSH keys only
- **Minimal footprint** - Essential packages only

### Cloud-Init Configuration

The template includes a comprehensive cloud-init configuration at `ubuntu/cloud-init/ubuntu-cloud-init.yml`:

```yaml
packages:
  - python3
  - python3-pip  
  - openssh-server
  - git
  - curl
  - htop
  - vim
  # ... and more DevOps essentials
```

## Terraform Configuration

### Server Deployment Options

```hcl
# Basic configuration
server_count       = 2
server_name_prefix = "ubuntu-dev"
server_cores       = 2
server_memory      = 2048
server_disk_size   = "20G"
```

### Network Configuration

```hcl
network_bridge  = "vmbr0"
server_ip_base  = "192.168.1.10"  # .101, .102, .103...
network_cidr    = "24"
network_gateway = "192.168.1.1"
```

## Advanced Usage

### End-to-End Automation

Use the comprehensive deployment script:

```bash
# Full deployment (template + servers)
./ubuntu/scripts/build-and-deploy-ubuntu.sh

# Production environment
./ubuntu/scripts/build-and-deploy-ubuntu.sh -e prod

# Skip template creation (if already exists)
./ubuntu/scripts/build-and-deploy-ubuntu.sh -s

# Plan only
./ubuntu/scripts/build-and-deploy-ubuntu.sh -a plan

# Destroy infrastructure
./ubuntu/scripts/build-and-deploy-ubuntu.sh -a destroy
```

### Multiple Environments

Create separate environment files:

```bash
# Development
environments/dev.tfvars

# Staging  
environments/staging.tfvars

# Production
environments/prod.tfvars
```

Deploy each with:
```bash
terraform apply -var-file="environments/staging.tfvars"
```

### Ansible Integration

The deployment generates an Ansible inventory at `inventory/hosts.yml`:

```yaml
ubuntu_servers:
  hosts:
    ubuntu-dev-1-abc123:
      ansible_host: 192.168.1.101
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ssh_keys/ubuntu_private_key.pem
```

Use with Ansible:
```bash
# Ping all servers
ansible all -i inventory/hosts.yml -m ping

# Run playbooks
ansible-playbook -i inventory/hosts.yml site.yml
```

## State Management

Ubuntu servers use **separate Terraform state** from NixOS Kubernetes:

- **NixOS K8s**: `s3://bucket/nixos-kubernetes/terraform.tfstate`
- **Ubuntu**: `s3://bucket/ubuntu-servers/terraform.tfstate`

This prevents cross-contamination and allows independent deployments.

## Troubleshooting

### Template Creation Issues

```bash
# Check if template ID is available
pvesh get /nodes/pve/qemu/9000/config

# Destroy existing template
qm destroy 9000

# Verify Proxmox storage
pvesh get /nodes/pve/storage
```

### Terraform Issues

```bash
# Verify Proxmox connectivity
terraform plan -var-file="environments/dev.tfvars"

# Check state file
terraform state list

# Force refresh
terraform refresh -var-file="environments/dev.tfvars"
```

### SSH Connection Issues

```bash
# Verify SSH key permissions
chmod 600 ssh_keys/ubuntu_private_key.pem

# Test connection with verbose output
ssh -v -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.101

# Check cloud-init logs on VM
sudo cloud-init status --long
sudo journalctl -u cloud-init
```

## Integration with Existing Infrastructure

This Ubuntu setup is designed to complement the existing NixOS Kubernetes infrastructure:

- **Shared modules** - Reuses the same `proxmox_vm` module
- **Same tools** - Uses same Terraform/Ansible patterns
- **Isolated state** - Separate deployments, no interference
- **Common workflows** - Similar deployment and management processes

## Next Steps

1. **Create templates** - Run template creation script
2. **Deploy servers** - Use Terraform for server provisioning
3. **Configure with Ansible** - Use generated inventory for automation
4. **Scale as needed** - Add more servers by adjusting `server_count`

For more detailed Proxmox setup, see [PROXMOX-API-SETUP.md](../../docs/PROXMOX-API-SETUP.md).