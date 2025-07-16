# Homelab Kubernetes Infrastructure

This project provisions repeatable, multi-cluster Kubernetes environments using Terraform and NixOS on Proxmox.

## 🧩 Project Goals

- Provision dev and prod Kubernetes clusters automatically via Terraform
- Use NixOS for minimal, declarative OS configuration
- Maintain a reusable infrastructure-as-code foundation
- Automate cluster provisioning with GitLab CI/CD
- Apply DRY principles and use reusable modules
- Future phases will add NixOS cloud-init, Kubernetes installation, and GitOps

## 📁 Directory Structure

```
.
├── README.md                  # This file
├── README-prompt.md           # AI agent task prompts
├── terraform/
│   ├── main.tf                # Entry point for Terraform root module
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf             # Remote state backend config
│   ├── terraform.tfvars.example
│   ├── modules/
│   │   └── proxmox_vm/        # Reusable VM provisioning module
│   └── outputs.tf
├── .gitlab-ci.yml             # GitLab CI for Terraform automation
└── .gitignore
```

## 🚀 Clusters

- `dev-cluster`: 1 control plane, 2 workers
- `prod-cluster`: 3 control planes, 3 workers

## ✅ Phase 1 Progress

Phase 1 is focused on automating VM creation using Terraform, Proxmox, and AWS for state management. See [README-prompt.md](./README-prompt.md) for detailed task descriptions.

## 🚀 Quick Start

1. **Set up AWS backend**: Follow [S3-DYNAMODB-SETUP.md](./S3-DYNAMODB-SETUP.md)
2. **Configure Terraform**: Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and populate with your Proxmox details
3. **Deploy infrastructure**: 
   ```bash
   cd terraform/
   terraform init
   terraform plan
   terraform apply
   ```
4. **Phase 2 - NixOS**: Follow [README-phase2.md](./README-phase2.md) for NixOS configuration

## 📚 Documentation

- **[TODO.md](./TODO.md)** - Prioritized task list and current issues
- **[README-phase2.md](./README-phase2.md)** - Phase 2 NixOS implementation guide
- **[README-roadmap.md](./README-roadmap.md)** - Complete multi-phase development roadmap
- **[S3-DYNAMODB-SETUP.md](./S3-DYNAMODB-SETUP.md)** - AWS backend configuration guide
- **[terraform/README.md](./terraform/README.md)** - Terraform module documentation
- **[CLAUDE.md](./CLAUDE.md)** - Claude Code integration guide

## 🔧 Development

For development commands and architecture overview, see [CLAUDE.md](./CLAUDE.md).

## 🎯 Multi-Phase Architecture

**Phase 1** - Terraform + Proxmox Automation ✅
- ✅ Terraform infrastructure provisioning
- ✅ Proxmox VM management
- ✅ AWS S3/DynamoDB backend for state management
- ✅ GitLab CI/CD pipeline

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
- **GitLab runner** (optional, for CI/CD)
- **NixOS** development environment or Nix package manager

## 📝 License

This project is part of a homelab experiment. Use at your own risk and adapt to your environment.
EOF < /dev/null