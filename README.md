# Homelab Infrastructure-as-Code

This project provides a flexible, modular infrastructure-as-code foundation for homelab environments using Terraform, Proxmox, and multiple OS templates. It supports both Kubernetes clusters (NixOS) and general-purpose servers (Ubuntu).

## 🧩 Project Goals

- **Multi-platform Infrastructure**: Support both NixOS Kubernetes clusters and Ubuntu servers
- **Modular Architecture**: Root modules pattern for separate, independent deployments
- **Code Reuse**: Shared Terraform modules across all infrastructure types
- **State Isolation**: Independent Terraform state files for each infrastructure type
- **Environment Management**: Consistent dev/staging/prod patterns across all projects
- **Automation**: End-to-end scripts for template creation and deployment
- **Standards**: Consistent patterns and conventions across all infrastructure

## 📁 Directory Structure

```
.
├── README.md                  # This file
├── docs/                      # Documentation
│   ├── ROOT-MODULES-ARCHITECTURE.md  # Root modules architecture guide
│   ├── UBUNTU-TEMPLATE-SETUP.md      # Ubuntu server setup guide
│   ├── TEMPLATE-PROJECT-GUIDE.md     # Creating new projects guide
│   ├── PROXMOX-API-SETUP.md          # Proxmox API token configuration
│   ├── S3-DYNAMODB-SETUP.md          # AWS backend configuration
│   ├── NIXOS-TEMPLATE-SETUP.md       # NixOS template creation guide
│   ├── GITLAB-CI-SETUP.md            # GitLab CI/CD configuration
│   ├── TESTING-PLAN.md               # Comprehensive testing strategy
│   └── [legacy docs...]              # Phase guides, troubleshooting, etc.
├── terraform/                 # Terraform infrastructure
│   ├── projects/              # Independent Terraform projects  
│   │   ├── nixos-kubernetes/  # Kubernetes cluster infrastructure
│   │   │   ├── main.tf        # K8s cluster definitions
│   │   │   ├── variables.tf   # K8s-specific variables
│   │   │   ├── environments/  # Environment-specific configs
│   │   │   │   ├── dev.tfvars.example
│   │   │   │   └── prod.tfvars.example
│   │   │   ├── templates/     # Ansible inventory, kubeconfig templates
│   │   │   └── [standard files] # providers.tf, versions.tf, backend.tf, etc.
│   │   ├── ubuntu-servers/    # Ubuntu server infrastructure
│   │   │   ├── main.tf        # Ubuntu server definitions
│   │   │   ├── variables.tf   # Server-specific variables
│   │   │   ├── environments/  # Environment-specific configs
│   │   │   │   └── dev.tfvars # Development Ubuntu servers
│   │   │   ├── templates/     # Ansible inventory templates
│   │   │   └── [standard files] # Complete Terraform configuration
│   │   └── template/          # Template for creating new projects
│   │       ├── README.md      # Template usage documentation
│   │       ├── main.tf        # Base template structure
│   │       └── [standard files] # All required Terraform files
│   └── modules/               # Reusable Terraform modules
│       └── proxmox_vm/        # Common VM provisioning module
│           ├── main.tf        # Core VM provisioning logic
│           ├── variables.tf   # VM configuration variables
│           ├── outputs.tf     # VM outputs
│           └── versions.tf    # Provider constraints
├── ubuntu/                    # Ubuntu-specific tooling
│   ├── scripts/
│   │   ├── create-ubuntu-template.sh    # Proxmox template creation
│   │   └── build-and-deploy-ubuntu.sh   # End-to-end deployment
│   └── cloud-init/
│       └── ubuntu-cloud-init.yml        # Ubuntu cloud-init config
├── nixos/                     # NixOS configurations
│   ├── [existing NixOS files] # Template configs, role definitions
│   └── ...
├── scripts/                   # General automation scripts
│   └── [existing scripts]     # State bucket creation, validation, etc.
├── journal/                   # Development journal and retrospectives
└── .gitlab-ci.yml            # GitLab CI/CD pipeline
```

## 🚀 Infrastructure Types

### NixOS Kubernetes Clusters
- **Purpose**: Production-ready Kubernetes clusters
- **OS**: NixOS with declarative configuration
- **Environments**: 
  - `dev-cluster`: 1 control plane, 2 workers
  - `prod-cluster`: 3 control planes, 3 workers
- **Location**: `terraform/projects/nixos-kubernetes/`

### Ubuntu Servers  
- **Purpose**: General-purpose server infrastructure
- **OS**: Ubuntu 25.04 with cloud-init
- **Use Cases**: Web servers, databases, Ansible-managed workloads
- **Environments**: Configurable server count and resources
- **Location**: `terraform/projects/ubuntu-servers/`

### Custom Projects
- **Purpose**: Any specialized infrastructure needs
- **Template**: Standardized project template available
- **Location**: `terraform/projects/template/` → copy to new project

## ✅ Phase 1 Progress

Phase 1 is focused on automating VM creation using Terraform, Proxmox, and AWS for state management.

## 🚀 Quick Start

Choose your infrastructure type and follow the appropriate guide:

### Prerequisites (All Projects)
1. **AWS Backend**: [docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)
2. **Proxmox API**: [docs/PROXMOX-API-SETUP.md](./docs/PROXMOX-API-SETUP.md) 
3. **GitLab CI/CD** (optional): [docs/GITLAB-CI-SETUP.md](./docs/GITLAB-CI-SETUP.md)

### Deploy Ubuntu Servers
```bash
# 1. Create Ubuntu template
./ubuntu/scripts/create-ubuntu-template.sh

# 2. Configure environment
cd terraform/projects/ubuntu-servers/
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit dev.tfvars with your settings

# 3. Deploy servers
terraform init
terraform apply -var-file="environments/dev.tfvars"

# 4. Or use end-to-end automation
./ubuntu/scripts/build-and-deploy-ubuntu.sh
```

### Deploy NixOS Kubernetes
```bash
# 1. Create NixOS template (follow guide)
# See docs/NIXOS-TEMPLATE-SETUP.md

# 2. Configure environment  
cd terraform/projects/nixos-kubernetes/
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit dev.tfvars with your settings

# 3. Deploy cluster
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

### Create Custom Project
```bash
# 1. Copy template
cp -r terraform/projects/template terraform/projects/my-project

# 2. Customize for your needs
cd terraform/projects/my-project
# Edit main.tf, variables.tf, backend.tf

# 3. Deploy
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

### Architecture Overview
See [docs/ROOT-MODULES-ARCHITECTURE.md](./docs/ROOT-MODULES-ARCHITECTURE.md) for detailed architecture information.

## 📚 Documentation

### Architecture and Planning
- **[docs/ROOT-MODULES-ARCHITECTURE.md](./docs/ROOT-MODULES-ARCHITECTURE.md)** - Root modules architecture and design patterns
- **[docs/TEMPLATE-PROJECT-GUIDE.md](./docs/TEMPLATE-PROJECT-GUIDE.md)** - Creating new infrastructure projects
- **[docs/README-roadmap.md](./docs/README-roadmap.md)** - Multi-phase development roadmap

### Infrastructure Setup
- **[docs/UBUNTU-TEMPLATE-SETUP.md](./docs/UBUNTU-TEMPLATE-SETUP.md)** - Ubuntu 25.04 server setup guide
- **[docs/NIXOS-TEMPLATE-SETUP.md](./docs/NIXOS-TEMPLATE-SETUP.md)** - NixOS template creation guide
- **[docs/S3-DYNAMODB-SETUP.md](./docs/S3-DYNAMODB-SETUP.md)** - AWS backend configuration
- **[docs/PROXMOX-API-SETUP.md](./docs/PROXMOX-API-SETUP.md)** - Proxmox API token setup
- **[docs/GITLAB-CI-SETUP.md](./docs/GITLAB-CI-SETUP.md)** - CI/CD pipeline configuration

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