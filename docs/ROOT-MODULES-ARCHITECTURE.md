# Root Modules Architecture Guide

This document explains the root modules architecture introduced to support multiple infrastructure types while maintaining separation of concerns and state isolation.

## Overview

The root modules architecture organizes Terraform configurations into separate, independent root modules, each managing a specific type of infrastructure with its own state file.

## Architecture Benefits

- **State Isolation**: Each project has separate Terraform state files
- **Independent Deployments**: Deploy one infrastructure type without affecting others
- **Code Reuse**: Shared modules used across multiple projects
- **Scalability**: Easy to add new infrastructure types
- **Environment Separation**: Each root module can have its own environments

## Directory Structure

```
root-modules/
├── nixos-kubernetes/          # Kubernetes cluster infrastructure
│   ├── main.tf                # K8s cluster definitions
│   ├── variables.tf           # K8s-specific variables
│   ├── environments/
│   │   ├── dev.tfvars         # Development K8s cluster
│   │   └── prod.tfvars        # Production K8s cluster
│   └── ...
├── ubuntu-servers/            # Ubuntu server infrastructure
│   ├── main.tf                # Ubuntu server definitions  
│   ├── variables.tf           # Server-specific variables
│   ├── environments/
│   │   ├── dev.tfvars         # Development servers
│   │   └── prod.tfvars        # Production servers
│   └── ...
├── template/                  # Template for new projects
│   ├── README.md              # Template usage guide
│   ├── main.tf                # Base template structure
│   └── ...
└── future-project/            # Additional infrastructure types
    └── ...

shared-modules/
└── proxmox_vm/               # Reusable VM provisioning module
    ├── main.tf               # Core VM logic
    ├── variables.tf          # VM configuration variables
    └── outputs.tf            # VM outputs
```

## State Management

### S3 Backend Structure

Each root module uses a separate path in the same S3 bucket:

```
S3 Bucket: stetter-k8s-infra-terraform-state
├── nixos-kubernetes/
│   ├── dev/terraform.tfstate       # Dev K8s cluster state
│   └── prod/terraform.tfstate      # Prod K8s cluster state
├── ubuntu-servers/
│   ├── dev/terraform.tfstate       # Dev Ubuntu servers state
│   └── prod/terraform.tfstate      # Prod Ubuntu servers state
└── template-project/
    └── dev/terraform.tfstate       # Template project state
```

### Backend Configuration

Standard backend configuration for all projects:

```hcl
terraform {
  backend "s3" {
    bucket       = "stetter-k8s-infra-terraform-state"
    key          = "project-name/environment/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
```

## Shared Modules

### Proxmox VM Module

The `shared-modules/proxmox_vm` module provides common VM provisioning logic:

```hcl
module "servers" {
  source = "../../shared-modules/proxmox_vm"
  
  # VM Configuration
  vm_name      = "server-${count.index + 1}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  
  # Resource Allocation  
  cores        = var.server_cores
  memory       = var.server_memory
  disk_size    = var.server_disk_size
  
  # Network Configuration
  ip_address   = "192.168.1.${count.index + 10}/24"
  gateway      = "192.168.1.1"
  
  # SSH Configuration
  ssh_user       = "ubuntu"
  ssh_public_key = local.ssh_public_key
}
```

### Module Benefits

- **Consistency**: Same VM provisioning logic across all projects
- **Maintenance**: Single place to update VM functionality
- **Testing**: Shared module can be tested independently
- **Standards**: Enforces consistent VM configuration

## Project Standards

### Required Files

Every root module must include:

- `main.tf` - Primary resource definitions
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values
- `providers.tf` - Provider configurations
- `versions.tf` - Provider version constraints
- `backend.tf` - S3 backend configuration
- `environments/` - Environment-specific tfvars files

### Variable Standards

All projects include standardized Proxmox provider variables:

```hcl
# Proxmox Provider Variables
variable "proxmox_api_url" { ... }
variable "proxmox_username" { ... }
variable "proxmox_password" { ... }
variable "proxmox_api_token_id" { ... }
variable "proxmox_api_token_secret" { ... }
variable "proxmox_tls_insecure" { default = true }
variable "proxmox_parallel" { default = 2 }
variable "proxmox_timeout" { default = 300 }
variable "proxmox_debug" { default = false }
```

### Provider Standards

- **Proxmox**: `Telmate/proxmox` version `3.0.2-rc03`
- **Random**: `hashicorp/random` version `~> 3.1`
- **TLS**: `hashicorp/tls` version `~> 4.0`
- **Local**: `hashicorp/local` version `~> 2.1`
- **Null**: `hashicorp/null` version `~> 3.1`

## Workflows

### Creating New Projects

1. **Copy Template**:
   ```bash
   cp -r root-modules/template root-modules/new-project
   ```

2. **Customize Configuration**:
   - Update `backend.tf` with new project path
   - Modify `main.tf` for project requirements
   - Add project-specific variables
   - Create environment files

3. **Deploy**:
   ```bash
   cd root-modules/new-project
   terraform init
   terraform apply -var-file="environments/dev.tfvars"
   ```

### Deployment Workflow

Each project deploys independently:

```bash
# Deploy Kubernetes cluster
cd root-modules/nixos-kubernetes
terraform apply -var-file="environments/dev.tfvars"

# Deploy Ubuntu servers (completely separate)
cd ../ubuntu-servers  
terraform apply -var-file="environments/dev.tfvars"
```

### Environment Management

Each project supports multiple environments:

```bash
# Development environment
terraform apply -var-file="environments/dev.tfvars"

# Production environment  
terraform apply -var-file="environments/prod.tfvars"

# Staging environment
terraform apply -var-file="environments/staging.tfvars"
```

## Migration from Legacy Structure

### From Single Terraform Directory

The previous structure had a single `terraform/` directory. Migration steps:

1. **Backup existing state**:
   ```bash
   cd terraform
   terraform state pull > backup-state.json
   ```

2. **Move to root modules**:
   ```bash
   mv terraform root-modules/nixos-kubernetes
   mkdir shared-modules
   mv root-modules/nixos-kubernetes/modules/* shared-modules/
   ```

3. **Update module sources**:
   ```bash
   # Change from "./modules/proxmox_vm" 
   # to "../../shared-modules/proxmox_vm"
   ```

4. **Re-initialize**:
   ```bash
   cd root-modules/nixos-kubernetes
   terraform init -reconfigure
   ```

## Current Projects

### NixOS Kubernetes (`nixos-kubernetes/`)

- **Purpose**: Kubernetes cluster deployment
- **Template**: NixOS-based VMs with kubeadm
- **Environments**: dev (1 control + 2 workers), prod (3 control + 3 workers)
- **State**: `nixos-kubernetes/dev/terraform.tfstate`

### Ubuntu Servers (`ubuntu-servers/`)

- **Purpose**: General-purpose Ubuntu server deployment
- **Template**: Ubuntu 25.04 cloud-init
- **Use Cases**: Ansible-managed workloads, web servers, databases
- **State**: `ubuntu-servers/dev/terraform.tfstate`

## Best Practices

### State Management

- **Never share state files** between projects
- **Use consistent backend configuration** across projects
- **Environment-specific state paths** for isolation
- **Regular state backups** before major changes

### Development

- **Use template** for all new projects
- **Test shared modules** independently
- **Follow variable naming conventions**
- **Include proper validation rules**

### Security

- **Sensitive variables** marked appropriately
- **API tokens** stored securely
- **SSH keys** generated per project
- **Network isolation** between environments

## Troubleshooting

### State Migration Issues

```bash
# If state gets corrupted during migration
terraform state list
terraform import <resource> <id>
terraform state rm <resource>  # If needed
```

### Module Source Issues

```bash
# After changing module sources
terraform init -upgrade
terraform plan  # Verify no unexpected changes
```

### Backend Conflicts

```bash
# If multiple projects try to use same state path
# Check backend.tf key values are unique
# Verify S3 bucket permissions
```

## Future Considerations

### Planned Infrastructure Types

- **Database Clusters**: PostgreSQL/MySQL cluster deployment
- **Container Registry**: Harbor or similar registry infrastructure  
- **Monitoring Stack**: Prometheus/Grafana deployment
- **CI/CD Runners**: GitLab Runner infrastructure

### Architecture Evolution

- **Module Versioning**: Semantic versioning for shared modules
- **Cross-Project Dependencies**: Outputs from one project as inputs to another
- **Environment Promotion**: Automated promotion from dev → staging → prod
- **Infrastructure Testing**: Automated testing of infrastructure changes