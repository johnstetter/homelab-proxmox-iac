# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Terraform Operations
```bash
# Set up S3 backend (first time only)
cd scripts/
./create-s3-state-bucket.sh

# Initialize Terraform with S3 backend
cd terraform/
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### NixOS Phase 2 Operations
```bash
# Populate NixOS configurations
./scripts/populate-nixos-configs.sh

# Source Nix environment (required for ISO generation)
source ~/.nix-profile/etc/profile.d/nix.sh

# Generate NixOS ISOs (takes 10-30 minutes)
./scripts/generate-nixos-isos.sh

# Create Proxmox templates
./scripts/create-proxmox-templates.sh --proxmox-host YOUR_PROXMOX_IP

# Validate Phase 2 implementation
./scripts/validate-phase2.sh
```

### Project Setup
```bash
# Configure Terraform variables (including S3 backend)
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your Proxmox and S3 backend details

# Make scripts executable
chmod +x scripts/*.sh

# Set up AWS credentials for S3 backend
aws configure
# OR export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
```

## Architecture Overview

This project implements a **multi-phase NixOS Kubernetes infrastructure experiment** using Terraform and Proxmox. The architecture follows a modular approach with clear separation of concerns:

### Core Components

**Terraform Root Module** (`terraform/`):
- Main infrastructure entry point at `terraform/main.tf`
- Provisions SSH keys, control plane nodes, worker nodes, and optional load balancer
- Uses the reusable `proxmox_vm` module for VM creation
- Generates Ansible inventory and kubeconfig templates

**Proxmox VM Module** (`terraform/modules/proxmox_vm/`):
- Reusable module for VM provisioning via Telmate Proxmox provider
- Handles cloud-init configuration, SSH key injection, and resource allocation
- Supports NixOS template integration for Phase 2

**NixOS Configurations** (`nixos/`):
- Common base configuration in `nixos/common/configuration.nix`
- Environment-specific configs in `nixos/dev/` and `nixos/prod/`
- Separate configurations for control plane and worker nodes

**Automation Scripts** (`scripts/`):
- `populate-nixos-configs.sh`: Generates NixOS configurations with Kubernetes components
- `generate-nixos-isos.sh`: Creates cloud-init NixOS ISOs using nixos-generators
- `create-proxmox-templates.sh`: Automates Proxmox template creation
- `validate-phase2.sh`: Validates Phase 2 implementation

### Multi-Phase Architecture

**Phase 1** - Terraform + Proxmox Automation:
- Terraform infrastructure provisioning with S3 remote state backend
- Proxmox VM management via Telmate provider
- AWS S3/DynamoDB backend for state management and locking

**Phase 2** - NixOS Node Configuration:
- NixOS ISO generation with nixos-generators
- Kubernetes component pre-configuration
- Proxmox template automation

**Phase 3** - Kubernetes Installation (future):
- Cluster initialization with kubeadm
- CNI networking configuration
- Multi-node HA setup

### Cluster Topologies

**Development Cluster**:
- 1 control plane node
- 2 worker nodes
- Optional load balancer (disabled by default)

**Production Cluster**:
- 3 control plane nodes (HA)
- 3+ worker nodes
- Load balancer with HAProxy + keepalived

## Key Files and Patterns

### Terraform Configuration
- `terraform/main.tf`: Main infrastructure definition using modules
- `terraform/variables.tf`: Comprehensive input variables for customization
- `terraform/outputs.tf`: Exports for inventory generation and automation
- `terraform/terraform.tfvars.example`: Example configuration with all options

### NixOS Integration
- NixOS configurations reference `nixos/${environment}/${role}.nix`
- Templates support both dev and prod environments
- Configurations include Kubernetes components (kubelet, containerd, etc.)

### Generated Artifacts
- SSH keys stored in `terraform/ssh_keys/`
- Ansible inventory generated at `terraform/inventory/hosts.yml`
- Kubeconfig template at `terraform/kubeconfig/kubeconfig-template.yml`
- Build artifacts in `build/isos/` and `build/templates/`

## Development Workflow

1. **Configure Environment**: Copy and edit `terraform/terraform.tfvars`
2. **Phase 1**: Deploy base infrastructure with `terraform apply`
3. **Phase 2**: Run NixOS scripts to populate configs and generate ISOs
4. **Validation**: Use `./scripts/validate-phase2.sh` for testing
5. **Iteration**: Use `terraform plan` before applying changes

## Important Notes

- The project uses **NixOS** as the target OS, not Ubuntu
- SSH user is `nixos` (not `ubuntu`)
- Scripts should be made executable with `chmod +x scripts/*.sh`
- Terraform state is managed remotely via S3/DynamoDB backend
- The project follows conventional commit patterns (see `COMMIT-STRATEGY.md`)
- VM templates are created from NixOS ISOs generated by nixos-generators

## Dependencies

- **Terraform** >= 1.0 with Telmate Proxmox provider
- **Nix package manager** for Phase 2 (nixos-generators accessed via `nix run`)
- **Proxmox VE** with API access and sufficient permissions
- **AWS S3/DynamoDB** for Terraform state backend
- **jq** for JSON processing in validation scripts

### Nix Setup
```bash
# Install Nix (single-user installation)
curl -L https://nixos.org/nix/install | sh

# Source in current session
source ~/.nix-profile/etc/profile.d/nix.sh

# Optional: Add to shell profile for automatic loading
echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
```