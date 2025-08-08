# Homelab Kubernetes Infrastructure

This project provisions repeatable, multi-cluster Kubernetes environments using Terraform and NixOS on Proxmox.

## 🧩 Project Goals

- Provision dev and prod Kubernetes clusters automatically via Terraform
- Use NixOS for minimal, declarative OS configuration
- Maintain a reusable infrastructure-as-code foundation
- Focus on local CLI usage for initial development and testing
- Apply DRY principles and use reusable modules
- Future phases will add NixOS cloud-init, Kubernetes installation, and GitOps
- GitLab CI/CD automation as a stretch goal

## 📁 Directory Structure

```
.
├── README.md                  # This file
├── build/                     # Generated build artifacts
├── docs/                      # Documentation
│   ├── CLAUDE.md              # Claude Code integration guide
│   ├── DISK-RESIZE-GUIDE.md   # Proxmox disk resize procedures
│   ├── GITLAB-CI-SETUP.md     # GitLab CI/CD configuration guide
│   ├── NIXOS-TEMPLATE-INSTALLATION.md # Legacy NixOS template guide
│   ├── NIXOS-TEMPLATE-SETUP.md # NixOS template creation guide
│   ├── PROXMOX-API-SETUP.md   # Proxmox API token configuration
│   ├── PROXMOX-CLI-TROUBLESHOOTING.md # Proxmox CLI debugging
│   ├── README-phase2.md       # Phase 2 NixOS implementation guide
│   ├── README-phase3.md       # Phase 3 Kubernetes implementation guide
│   ├── README-prompt.md       # AI prompt engineering guide
│   ├── README-roadmap.md      # Multi-phase development roadmap
│   ├── S3-DYNAMODB-SETUP.md   # AWS backend configuration guide
│   ├── TESTING-PLAN.md        # Comprehensive testing strategy
│   └── TODO.md                # Prioritized task list
├── journal/                   # Development journal
│   ├── README.md              # Journal overview and methodology
│   ├── phase-1-retrospective.md # Phase 1 AI-assisted development experience
│   └── phase-2-completion.md  # Phase 2 completion summary
├── terraform/
│   ├── main.tf                # Entry point for Terraform root module
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf             # Remote state backend config
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf
│   ├── environments/          # Environment-specific configurations
│   │   ├── dev.tfvars.example    # Development environment template
│   │   └── prod.tfvars.example   # Production environment template
│   ├── inventory/             # Generated Ansible inventory files (gitignored)
│   ├── kubeconfig/            # Generated kubeconfig files (gitignored)
│   ├── modules/
│   │   └── proxmox_vm/        # Reusable VM provisioning module
│   ├── ssh_keys/              # SSH key pairs for VM access (gitignored)
│   └── templates/             # Template files for generated configs
├── nixos/                     # NixOS configurations
│   ├── base-template.nix      # Base template configuration
│   ├── nixos-template-configuration.nix # Template-specific configuration
│   ├── common/
│   │   └── configuration.nix  # Shared NixOS configuration
│   ├── dev/
│   │   ├── control.nix       # Dev control plane config
│   │   └── worker.nix        # Dev worker config
│   ├── prod/
│   │   ├── control.nix       # Prod control plane config
│   │   └── worker.nix        # Prod worker config
│   └── roles/
│       ├── control-plane.nix  # Control plane role configuration
│       └── worker.nix         # Worker role configuration
├── scripts/                   # Automation scripts
│   ├── build-and-deploy-template.sh # Build and deploy NixOS template
│   ├── create-proxmox-template.sh   # Create Proxmox VM template
│   ├── create-s3-state-bucket.sh   # Create S3 bucket for Terraform state
│   ├── generate-nixos-iso.sh       # Generate NixOS ISO images
│   ├── populate-nixos-configs.sh   # Populate NixOS configurations
│   ├── setup-gitlab-aws-iam.sh     # Setup GitLab CI AWS credentials
│   └── validate-phase2.sh          # Validate Phase 2 implementation
├── .gitlab-ci.yml             # GitLab CI/CD pipeline
└── .gitignore
```

## 🚀 Clusters

- `dev-cluster`: 1 control plane, 2 workers
- `prod-cluster`: 3 control planes, 3 workers

## ✅ Phase 1 Progress

Phase 1 is focused on automating VM creation using Terraform, Proxmox, and AWS for state management.

## 🚀 Quick Start (Local CLI)

1. **Set up AWS backend**: Follow [docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)
2. **Set up Proxmox API access**: Follow [docs/PROXMOX-API-SETUP.md](./docs/PROXMOX-API-SETUP.md) to create API tokens with proper permissions
3. **Create NixOS VM template**: Follow [docs/NIXOS-TEMPLATE-SETUP.md](./docs/NIXOS-TEMPLATE-SETUP.md) to create the required `nixos-2311-cloud-init` template
4. **Set up GitLab CI/CD** (optional): Follow [docs/GITLAB-CI-SETUP.md](./docs/GITLAB-CI-SETUP.md) to configure automated pipelines
4. **Configure Terraform variables**: 
   - Use environment-specific configuration files in `terraform/environments/`
   - Copy `terraform/environments/dev.tfvars.example` to `terraform/environments/dev.tfvars` and customize for development
   - Copy `terraform/environments/prod.tfvars.example` to `terraform/environments/prod.tfvars` and customize for production
   - Update with your actual Proxmox API credentials and S3 backend details
5. **Deploy infrastructure locally**: 
   ```bash
   cd terraform/
   
   # For development environment
   terraform init
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply -var-file="environments/dev.tfvars"
   
   # For production environment
   terraform plan -var-file="environments/prod.tfvars"
   terraform apply -var-file="environments/prod.tfvars"
   ```
6. **Phase 2 - NixOS**: Follow [docs/README-phase2.md](./docs/README-phase2.md) for NixOS configuration
7. **Testing**: Use the comprehensive [docs/TESTING-PLAN.md](./docs/TESTING-PLAN.md) to validate your setup

## 📚 Documentation

### Setup and Configuration
- **[docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)** - AWS backend configuration guide
- **[docs/PROXMOX-API-SETUP.md](./docs/PROXMOX-API-SETUP.md)** - Proxmox API token setup with required permissions
- **[docs/NIXOS-TEMPLATE-SETUP.md](./docs/NIXOS-TEMPLATE-SETUP.md)** - Complete guide for creating NixOS VM templates
- **[docs/GITLAB-CI-SETUP.md](./docs/GITLAB-CI-SETUP.md)** - GitLab CI/CD pipeline configuration and AWS authentication

### Implementation Guides
- **[docs/README-phase2.md](./docs/README-phase2.md)** - Phase 2 NixOS implementation guide
- **[docs/README-phase3.md](./docs/README-phase3.md)** - Phase 3 Kubernetes implementation guide
- **[docs/README-roadmap.md](./docs/README-roadmap.md)** - Complete multi-phase development roadmap
- **[docs/TESTING-PLAN.md](./docs/TESTING-PLAN.md)** - Comprehensive testing strategy

### Troubleshooting and Maintenance
- **[docs/PROXMOX-CLI-TROUBLESHOOTING.md](./docs/PROXMOX-CLI-TROUBLESHOOTING.md)** - Proxmox CLI debugging procedures
- **[docs/DISK-RESIZE-GUIDE.md](./docs/DISK-RESIZE-GUIDE.md)** - Proxmox disk resize procedures
- **[docs/TODO.md](./docs/TODO.md)** - Prioritized task list and current issues

### Development Resources
- **[docs/CLAUDE.md](./docs/CLAUDE.md)** - Claude Code integration guide
- **[docs/README-prompt.md](./docs/README-prompt.md)** - AI prompt engineering guide
- **[terraform/README.md](./terraform/README.md)** - Terraform module documentation
- **[journal/README.md](./journal/README.md)** - Development journal overview and methodology
- **[journal/phase-1-retrospective.md](./journal/phase-1-retrospective.md)** - Phase 1 AI-assisted development experience
- **[journal/phase-2-completion.md](./journal/phase-2-completion.md)** - Phase 2 completion summary and achievements

### Legacy Documentation
- **[docs/NIXOS-TEMPLATE-INSTALLATION.md](./docs/NIXOS-TEMPLATE-INSTALLATION.md)** - Legacy NixOS template guide (superseded by NIXOS-TEMPLATE-SETUP.md)

## 🔧 Development

For development commands and architecture overview, see [docs/CLAUDE.md](./docs/CLAUDE.md).

## 🎯 Multi-Phase Architecture

**Phase 1** - Terraform + Proxmox Automation ✅
- ✅ Terraform infrastructure provisioning with environment-specific configs
- ✅ Proxmox VM management with proper API token setup
- ✅ AWS S3/DynamoDB backend for state management
- ✅ Local CLI workflow established and tested
- ✅ Comprehensive documentation and setup guides
- ✅ GitLab CI/CD pipeline with AWS authentication and security best practices

**Phase 2** - NixOS Node Configuration ✅
- ✅ NixOS ISO generation with nixos-generators
- ✅ Kubernetes component pre-configuration
- ✅ Proxmox template automation
- ✅ Role-based configuration system (control-plane/worker)
- ✅ Base template with NFS client support

**Phase 3** - Kubernetes Installation 📋
- 📋 Cluster initialization with kubeadm
- 📋 CNI networking configuration
- 📋 Multi-node HA setup

## 🛠️ Prerequisites

- **Proxmox VE** server with API access
- **AWS account** for Terraform state backend
- **Terraform CLI** installed locally
- **NixOS** development environment or Nix package manager
- **GitLab runner** (optional, for future CI/CD automation)

## 📝 License

This project is part of a homelab experiment. Use at your own risk and adapt to your environment.
EOF < /dev/null