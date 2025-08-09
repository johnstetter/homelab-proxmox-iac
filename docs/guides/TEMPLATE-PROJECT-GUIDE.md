# Template Project Guide

This guide explains how to use the standardized Terraform template to create new infrastructure projects in the k8s-infra repository.

## Overview

The `terraform/environments/template/` directory provides a standardized starting point for creating new Terraform environment modules. It includes all the required files, standards, and patterns used across the project.

## When to Use the Template

Use the template when you need to create:
- New infrastructure types (beyond NixOS K8s and Ubuntu servers)
- Multi-VM deployments for specific use cases
- Specialized infrastructure with custom requirements
- Test environments for new concepts

## Template Contents

```
root-modules/template/
├── README.md                  # Complete usage documentation
├── main.tf                    # Base infrastructure template
├── variables.tf               # Standard variable definitions  
├── outputs.tf                 # Standard output patterns
├── providers.tf               # Provider configurations
├── versions.tf                # Provider version constraints
├── backend.tf                 # S3 backend template
├── environments/
│   └── dev.tfvars.example     # Environment configuration template
├── templates/
│   └── inventory.tpl          # Ansible inventory template
├── inventory/                 # Generated inventory files
└── ssh_keys/                  # Generated SSH keys
```

## Quick Start

### 1. Copy Template

```bash
# Copy template to new project
cp -r root-modules/template root-modules/my-project

# Navigate to new project
cd root-modules/my-project
```

### 2. Customize Backend

Update `backend.tf` with your project-specific state path:

```hcl
terraform {
  backend "s3" {
    bucket       = "stetter-k8s-infra-terraform-state"
    key          = "my-project/dev/terraform.tfstate"  # ← Change this
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
```

### 3. Define Your Infrastructure

Edit `main.tf` to define your specific infrastructure. The template includes commented examples:

```hcl
# Uncomment and modify for your VMs
module "project_vms" {
  source = "../../modules/proxmox_vm"
  count  = var.vm_count

  vm_name      = "${var.vm_name_prefix}-${count.index + 1}-${random_string.project_suffix.result}"
  target_node  = var.proxmox_node
  template     = var.vm_template
  # ... customize as needed
}
```

### 4. Add Project Variables

Add your project-specific variables to `variables.tf`:

```hcl
# Add after the standard variables
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10."
  }
}

variable "vm_name_prefix" {
  description = "Prefix for VM names"
  type        = string
  default     = "myproject"
}

variable "vm_cores" {
  description = "CPU cores per VM"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory per VM (MB)"
  type        = number  
  default     = 2048
}

variable "vm_disk_size" {
  description = "Disk size per VM"
  type        = string
  default     = "20G"
}

variable "vm_ip_base" {
  description = "Base IP address for VMs (without last octet)"
  type        = string
  default     = "192.168.1.20"
}
```

### 5. Update Outputs

Customize `outputs.tf` for your project needs:

```hcl
# Uncomment and modify template outputs
output "project_vms" {
  description = "VM details"
  value = {
    for i, vm in module.project_vms : vm.vm_name => {
      vm_id      = vm.vm_id
      ip_address = vm.ip_address
      ssh_user   = var.ssh_user
      node_name  = var.proxmox_node
    }
  }
}

output "vm_ips" {
  description = "List of VM IP addresses"
  value       = [for vm in module.project_vms : vm.ip_address]
}

output "ssh_connection_commands" {
  description = "SSH connection commands for each VM"
  value = [
    for vm in module.project_vms : 
    "ssh -i ${path.module}/ssh_keys/project_private_key.pem ${var.ssh_user}@${vm.ip_address}"
  ]
}
```

### 6. Create Environment Configuration

```bash
# Create development environment config
cd environments/
cp dev.tfvars.example dev.tfvars

# Edit dev.tfvars with your actual values
vim dev.tfvars
```

Example customized `dev.tfvars`:

```hcl
# Environment
environment = "dev"

# Proxmox Configuration (update with your values)
proxmox_api_url          = "https://192.168.1.100:8006/api2/json"
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "your-secret-here"

# Infrastructure
proxmox_node = "pve"
vm_template  = "ubuntu-25.04-cloud-init"  # or your template
disk_storage = "local-zfs"

# Project-specific variables
vm_count       = 3
vm_name_prefix = "myproject-dev"
vm_cores       = 4
vm_memory      = 4096
vm_disk_size   = "30G"
vm_ip_base     = "192.168.1.20"  # Results in .201, .202, .203

# Network
network_bridge  = "vmbr0"
network_gateway = "192.168.1.1"
nameserver      = "8.8.8.8"
```

### 7. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"
```

## Advanced Customization

### Multiple VM Types

You can define different types of VMs in the same project:

```hcl
# Web servers
module "web_servers" {
  source = "../../modules/proxmox_vm"
  count  = var.web_server_count
  
  vm_name      = "web-${count.index + 1}-${random_string.project_suffix.result}"
  cores        = var.web_server_cores
  memory       = var.web_server_memory
  ip_address   = "${var.web_server_ip_base}${count.index + 1}/${var.network_cidr}"
  # ...
}

# Database servers  
module "db_servers" {
  source = "../../modules/proxmox_vm"
  count  = var.db_server_count
  
  vm_name      = "db-${count.index + 1}-${random_string.project_suffix.result}"
  cores        = var.db_server_cores
  memory       = var.db_server_memory  
  disk_size    = var.db_server_disk_size
  ip_address   = "${var.db_server_ip_base}${count.index + 1}/${var.network_cidr}"
  # ...
}
```

### Custom Templates

For specialized Ansible inventory or other templates:

```bash
# Create custom template
cat > templates/custom-inventory.tpl << EOF
# Custom inventory structure
[web_servers]
%{ for vm in web_servers ~}
${vm.vm_name} ansible_host=${vm.ip_address}
%{ endfor ~}

[db_servers]  
%{ for vm in db_servers ~}
${vm.vm_name} ansible_host=${vm.ip_address}
%{ endfor ~}
EOF
```

### Environment-Specific Configurations

Create different configurations for each environment:

```bash
# Production environment
cat > environments/prod.tfvars << EOF
environment = "prod"

# Higher resources for production
vm_count = 5
vm_cores = 8
vm_memory = 8192
vm_disk_size = "100G"

# Production network
vm_ip_base = "10.0.1.20"
network_gateway = "10.0.1.1"
EOF
```

### Conditional Resources

Use conditional logic for optional components:

```hcl
# Optional load balancer
module "load_balancer" {
  count  = var.enable_load_balancer ? 1 : 0
  source = "../../modules/proxmox_vm"
  
  vm_name    = "lb-${random_string.project_suffix.result}"
  cores      = var.lb_cores
  memory     = var.lb_memory
  ip_address = "${var.lb_ip}/${var.network_cidr}"
  # ...
}

# Variables
variable "enable_load_balancer" {
  description = "Enable load balancer deployment"
  type        = bool
  default     = false
}
```

## Template Standards

### Required Standards

All projects must follow these standards:

1. **Use shared modules** where possible
2. **Include all standard variables** (Proxmox provider, network, etc.)
3. **Follow naming conventions** (vm_name pattern with suffix)
4. **Generate SSH keys** per project
5. **Use validation rules** for input variables
6. **Provide meaningful outputs**

### File Organization

- Keep `main.tf` focused on resource definitions
- Put all variables in `variables.tf` with descriptions
- Include useful outputs in `outputs.tf`
- Use `locals` for computed values
- Separate environment configs in `environments/`

### Variable Naming

- Use descriptive names: `web_server_count` not `count1`
- Include validation where appropriate
- Set sensible defaults
- Mark sensitive variables properly
- Group related variables with comments

## Example Projects

### Web Application Stack

```hcl
# Web servers
module "web_servers" {
  source = "../../modules/proxmox_vm"
  count  = var.web_server_count
  # ... web server config
}

# Database server
module "database" {
  source = "../../modules/proxmox_vm"
  count  = 1
  # ... database config with larger disk
}

# Load balancer
module "load_balancer" {
  count  = var.enable_load_balancer ? 1 : 0
  source = "../../modules/proxmox_vm" 
  # ... load balancer config
}
```

### Development Environment

```hcl
# Single VM for development
module "dev_vm" {
  source = "../../modules/proxmox_vm"
  count  = 1
  
  vm_name    = "dev-workstation-${random_string.project_suffix.result}"
  cores      = 4
  memory     = 8192
  disk_size  = "50G"
  # ... dev-specific config
}
```

### Testing Infrastructure

```hcl
# Multiple test VMs
module "test_vms" {
  source = "../../modules/proxmox_vm"
  count  = var.test_vm_count
  
  vm_name = "test-${count.index + 1}-${random_string.project_suffix.result}"
  cores   = 1  # Minimal for testing
  memory  = 1024
  # ... test-specific config
}
```

## Troubleshooting

### Common Issues

1. **Backend conflicts**: Ensure unique S3 key paths
2. **Module source errors**: Verify relative paths to shared modules
3. **Variable validation failures**: Check validation rules in variables
4. **SSH key permissions**: Ensure generated keys have correct permissions

### Debugging Steps

```bash
# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Plan with verbose output  
terraform plan -var-file="environments/dev.tfvars" -detailed-exitcode

# Apply with logging
TF_LOG=DEBUG terraform apply -var-file="environments/dev.tfvars"
```

## Next Steps

After creating your project:

1. **Test the deployment** in a dev environment
2. **Create additional environments** (staging, prod)
3. **Add monitoring/alerting** if needed
4. **Document project-specific** requirements
5. **Set up CI/CD** for automated deployments
6. **Create Ansible playbooks** for configuration management

For more information, see:
- [ROOT-MODULES-ARCHITECTURE.md](ROOT-MODULES-ARCHITECTURE.md) - Architecture overview
- [UBUNTU-TEMPLATE-SETUP.md](UBUNTU-TEMPLATE-SETUP.md) - Ubuntu-specific setup
- [PROXMOX-API-SETUP.md](PROXMOX-API-SETUP.md) - Proxmox API configuration