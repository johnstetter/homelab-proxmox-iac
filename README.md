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
├── docs/                      # Documentation
│   ├── CLAUDE.md              # Claude Code integration guide
│   ├── README-phase2.md       # Phase 2 NixOS implementation guide
│   ├── README-roadmap.md      # Multi-phase development roadmap
│   ├── S3-DYNAMODB-SETUP.md   # AWS backend configuration guide
│   ├── TESTING-PLAN.md        # Comprehensive testing strategy
│   └── TODO.md                # Prioritized task list
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
│   ├── modules/
│   │   └── proxmox_vm/        # Reusable VM provisioning module
│   └── templates/             # Template files for generated configs
├── nixos/                     # NixOS configurations
│   ├── common/
│   │   └── configuration.nix  # Shared NixOS configuration
│   ├── dev/
│   │   ├── control.nix       # Dev control plane config
│   │   └── worker.nix        # Dev worker config
│   └── prod/
│       ├── control.nix       # Prod control plane config
│       └── worker.nix        # Prod worker config
├── scripts/                   # Automation scripts
│   ├── populate-nixos-configs.sh
│   ├── generate-nixos-isos.sh
│   ├── create-proxmox-templates.sh
│   └── validate-phase2.sh
├── gitlab-ci.yml              # GitLab CI/CD pipeline
└── .gitignore
```

## 🚀 Clusters

- `dev-cluster`: 1 control plane, 2 workers
- `prod-cluster`: 3 control planes, 3 workers

## ✅ Phase 1 Progress

Phase 1 is focused on automating VM creation using Terraform, Proxmox, and AWS for state management.

## 🚀 Quick Start (Local CLI)

1. **Set up AWS backend**: Follow [docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)
2. **Configure Terraform variables**: 
   - Use environment-specific configuration files in `terraform/environments/`
   - Copy `terraform/environments/dev.tfvars.example` to `terraform/environments/dev.tfvars` and customize for development
   - Copy `terraform/environments/prod.tfvars.example` to `terraform/environments/prod.tfvars` and customize for production
   - The `backend.tf` file uses variables for S3 bucket name, region, and DynamoDB table - configure these in your environment files
3. **Deploy infrastructure locally**: 
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
4. **Phase 2 - NixOS**: Follow [docs/README-phase2.md](./docs/README-phase2.md) for NixOS configuration
5. **Testing**: Use the comprehensive [docs/TESTING-PLAN.md](./docs/TESTING-PLAN.md) to validate your setup

## 📚 Documentation

- **[docs/TODO.md](./docs/TODO.md)** - Prioritized task list and current issues
- **[docs/TESTING-PLAN.md](./docs/TESTING-PLAN.md)** - Comprehensive testing strategy
- **[docs/README-phase2.md](./docs/README-phase2.md)** - Phase 2 NixOS implementation guide
- **[docs/README-roadmap.md](./docs/README-roadmap.md)** - Complete multi-phase development roadmap
- **[docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)** - AWS backend configuration guide
- **[terraform/README.md](./terraform/README.md)** - Terraform module documentation
- **[docs/CLAUDE.md](./docs/CLAUDE.md)** - Claude Code integration guide

## 🔧 Development

For development commands and architecture overview, see [docs/CLAUDE.md](./docs/CLAUDE.md).

## 🎯 Multi-Phase Architecture

**Phase 1** - Terraform + Proxmox Automation ✅
- ✅ Terraform infrastructure provisioning
- ✅ Proxmox VM management
- ✅ AWS S3/DynamoDB backend for state management
- ✅ Local CLI workflow established
- 🎯 GitLab CI/CD pipeline (stretch goal)

**Phase 2** - NixOS Node Configuration ⏳
- ⏳ NixOS ISO generation with nixos-generators
- ⏳ Kubernetes component pre-configuration
- ⏳ Proxmox template automation

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