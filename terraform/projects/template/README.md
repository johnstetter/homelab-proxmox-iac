# Terraform Root Module Template

This directory provides a standardized template for creating new Terraform root modules in the homelab-proxmox-iac project.

## Template Standards

All root modules in this project follow these standards:

### File Structure
```
project-name/
├── main.tf                    # Primary resource definitions
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── providers.tf               # Provider configurations  
├── versions.tf                # Provider version constraints
├── backend.tf                 # Remote state configuration
├── environments/              # Environment-specific configs
│   ├── dev.tfvars.example     # Development template
│   ├── staging.tfvars         # Staging configuration
│   └── prod.tfvars            # Production configuration
├── templates/                 # Template files (inventory, etc.)
├── inventory/                 # Generated inventory files
└── ssh_keys/                  # Generated SSH keys
```

### Provider Standards

- **Proxmox**: Version `3.0.2-rc03` (Telmate/proxmox)
- **Random**: Version `~> 3.1`
- **TLS**: Version `~> 4.0` 
- **Local**: Version `~> 2.1`
- **Null**: Version `~> 3.1`

### Variable Standards

#### Proxmox Provider Variables
Always include these standard Proxmox provider variables:

```hcl
# Core connection
variable "proxmox_api_url" { ... }
variable "proxmox_username" { ... }
variable "proxmox_password" { ... }
variable "proxmox_api_token_id" { ... }
variable "proxmox_api_token_secret" { ... }

# Behavior settings
variable "proxmox_tls_insecure" { default = true }
variable "proxmox_parallel" { default = 2 }
variable "proxmox_timeout" { default = 300 }
variable "proxmox_debug" { default = false }
```

#### Infrastructure Variables
```hcl
variable "environment" { ... }
variable "proxmox_node" { ... }
variable "vm_template" { ... }
variable "disk_storage" { ... }
```

#### Network Variables
```hcl
variable "network_bridge" { default = "vmbr0" }
variable "network_vlan" { default = null }
variable "network_cidr" { default = "24" }
variable "network_gateway" { ... }
variable "nameserver" { default = "8.8.8.8" }
```

### Backend Configuration

Use consistent S3 backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket       = "stetter-homelab-proxmox-iac-tf-state"
    key          = "project-name/dev/terraform.tfstate"
    region       = "us-east-2"
    dynamodb_table = "homelab-proxmox-iac-tf-locks"
    encrypt      = true
  }
}
```

### Resource Naming

- Use random suffixes for unique naming: `${random_string.project_suffix.result}`
- Follow pattern: `${prefix}-${index}-${suffix}`
- Use descriptive prefixes: `ubuntu-dev`, `k8s-prod`, etc.

### SSH Key Management

Generate project-specific SSH keys:

```hcl
resource "tls_private_key" "project_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

### Shared Module Usage

All projects should use shared modules:

```hcl
module "vms" {
  source = "../../modules/proxmox_vm"
  # ...
}
```

## Using This Template

1. **Copy template directory**:
   ```bash
   cp -r root-modules/template root-modules/new-project
   ```

2. **Customize files**:
   - Update `backend.tf` with new project key
   - Modify `main.tf` for project-specific resources
   - Add project-specific variables to `variables.tf`
   - Update outputs in `outputs.tf`

3. **Create environment configs**:
   ```bash
   cd terraform/projects/new-project/environments/
   cp dev.tfvars.example dev.tfvars
   # Edit dev.tfvars with actual values
   ```

4. **Deploy**:
   ```bash
   terraform init
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply -var-file="environments/dev.tfvars"
   ```

## Project Examples

- **nixos-kubernetes/**: Kubernetes cluster deployment
- **ubuntu-servers/**: Ubuntu server management
- **template/**: This standardized template

## Validation

Before submitting, ensure your project:

- [ ] Uses standard file structure
- [ ] Includes all required provider variables
- [ ] Has proper version constraints
- [ ] Uses shared modules where possible
- [ ] Follows naming conventions
- [ ] Includes example environment files
- [ ] Has appropriate validation rules
- [ ] Generates useful outputs