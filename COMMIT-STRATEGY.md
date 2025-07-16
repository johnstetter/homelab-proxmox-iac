# Commit Strategy for NixOS Kubernetes Infrastructure

This document outlines the recommended commit strategy for organizing the substantial changes made to transition from Ubuntu-based to NixOS-based infrastructure using conventional commits.

## 🎯 Conventional Commit Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`

## 📋 Recommended Commit Sequence

### 1. Infrastructure Foundation
```bash
# Commit 1: Core Terraform infrastructure
git add terraform/versions.tf terraform/providers.tf terraform/variables.tf
git commit -m "feat(terraform): add core infrastructure configuration

- Add Terraform version constraints with Telmate Proxmox provider
- Configure Proxmox provider with authentication variables
- Define comprehensive input variables for cluster configuration

Supports both dev and prod environments with configurable:
- Control plane and worker node counts
- Resource allocation (CPU, memory, disk)
- Network configuration and IP allocation
- Load balancer setup (optional)"

# Commit 2: Main infrastructure definition
git add terraform/main.tf terraform/outputs.tf
git commit -m "feat(terraform): implement Kubernetes cluster infrastructure

- Define control plane and worker node resources using proxmox_vm module
- Add optional load balancer with HAProxy configuration
- Generate SSH keys for secure cluster access
- Create Ansible inventory and kubeconfig templates
- Support for dev/prod environments with different sizing

Infrastructure includes:
- Multi-node control plane support
- Configurable worker node scaling
- Network isolation and security groups
- Automated key management"
```

### 2. VM Module Implementation
```bash
# Commit 3: Proxmox VM module
git add terraform/modules/proxmox_vm/
git commit -m "feat(terraform): add reusable Proxmox VM module

- Implement comprehensive VM provisioning with Telmate provider
- Support for cloud-init configuration and SSH key injection
- Configurable resources (CPU, memory, disk, network)
- VM lifecycle management with proper dependencies
- Output VM information for integration with other modules

Module supports:
- Multiple storage backends
- VLAN configuration
- Cloud-init user data
- SSH connectivity testing"
```

### 3. Configuration Templates
```bash
# Commit 4: Template files
git add terraform/templates/
git commit -m "feat(terraform): add Ansible and kubeconfig templates

- Create dynamic Ansible inventory template for cluster management
- Add kubeconfig template for kubectl access
- Support for load balancer and multi-node configurations
- Template variables for flexible deployment scenarios"
```

### 4. Example Configuration
```bash
# Commit 5: Example configuration
git add terraform/terraform.tfvars.example
git commit -m "feat(terraform): add comprehensive example configuration

- Provide complete terraform.tfvars.example with all variables
- Include network configuration examples and IP allocation
- Document required Proxmox setup and API token configuration
- Add usage instructions and deployment guidelines"
```

### 5. NixOS Transition
```bash
# Commit 6: Remove Ubuntu dependencies
git add -A  # This will include deletions
git commit -m "refactor(terraform): migrate from Ubuntu to NixOS approach

BREAKING CHANGE: Remove Ubuntu cloud-init dependencies

- Remove terraform/cloud-init/ directory and Ubuntu configurations
- Update VM module to reference NixOS configurations instead
- Change default SSH user from ubuntu to nixos
- Update template references to use NixOS VM templates
- Modify terraform.tfvars.example for NixOS template names

This prepares the infrastructure for Phase 2 NixOS implementation."
```

### 6. Documentation
```bash
# Commit 7: Core documentation
git add terraform/README.md
git commit -m "docs(terraform): add comprehensive usage documentation

- Document NixOS-focused Terraform infrastructure
- Include Proxmox setup instructions for NixOS templates
- Add deployment workflow and configuration examples
- Document integration with Phase 2 NixOS implementation
- Include troubleshooting and next steps guidance"
```

### 7. Project Configuration
```bash
# Commit 8: Project setup
git add .gitignore
git commit -m "chore: add comprehensive .gitignore for Terraform projects

- Ignore Terraform state files and sensitive data
- Exclude generated SSH keys and build artifacts
- Add IDE and OS-specific ignore patterns
- Include Terraform lock files and plan outputs"
```

### 8. Phase 2 Documentation
```bash
# Commit 9: Phase 2 guide
git add README-phase2.md
git commit -m "docs: add Phase 2 developer implementation guide

- Comprehensive guide for NixOS node configuration
- Step-by-step instructions for nixos-generators usage
- Integration workflow with existing Terraform infrastructure
- Prerequisites, troubleshooting, and validation procedures
- Roadmap alignment with multi-phase experiment goals"
```

### 9. Automation Scripts
```bash
# Commit 10: NixOS configuration automation
git add scripts/populate-nixos-configs.sh
git commit -m "feat(scripts): add NixOS configuration population automation

- Generate complete NixOS configurations with Kubernetes components
- Support for dev/prod environments and control/worker roles
- Comprehensive Kubernetes service definitions (kubelet, etcd, etc.)
- Cloud-init integration and SSH key management
- Force overwrite and selective environment targeting"

# Commit 11: ISO generation automation
git add scripts/generate-nixos-isos.sh
git commit -m "feat(scripts): add NixOS ISO generation with nixos-generators

- Automate cloud-init compatible NixOS ISO creation
- Support for different node types and environments
- Integration with existing NixOS configuration structure
- Comprehensive logging and error handling
- Clean build options and custom output directories"

# Commit 12: Proxmox template automation
git add scripts/create-proxmox-templates.sh
git commit -m "feat(scripts): add Proxmox template creation automation

- Automate VM template creation from generated NixOS ISOs
- Handle ISO upload, VM configuration, and template conversion
- SSH connectivity testing and dry-run capabilities
- Generate template mapping for Terraform integration
- Support for multiple storage backends and node configurations"

# Commit 13: Validation automation
git add scripts/validate-phase2.sh
git commit -m "feat(scripts): add Phase 2 validation and testing

- Comprehensive validation of NixOS configurations and ISOs
- Terraform syntax validation and connectivity testing
- Proxmox template verification and prerequisite checking
- Detailed reporting with actionable next steps
- Integration testing for complete Phase 2 workflow"
```

### 10. Final Documentation
```bash
# Commit 14: Commit strategy documentation
git add COMMIT-STRATEGY.md
git commit -m "docs: add conventional commit strategy guide

- Document recommended commit sequence for large changes
- Provide conventional commit examples for infrastructure changes
- Include rationale for commit organization and scope
- Guide for future development and collaboration"
```

## 🔄 Alternative: Squash Strategy

If you prefer fewer commits, you can group related changes:

```bash
# Option A: Feature-based commits (4 commits)
1. feat(terraform): implement complete NixOS Kubernetes infrastructure
2. feat(scripts): add Phase 2 automation and validation tools  
3. docs: add comprehensive documentation and guides
4. chore: add project configuration and commit strategy

# Option B: Phase-based commits (2 commits)
1. feat: complete Phase 1 NixOS Terraform infrastructure
2. feat: add Phase 2 automation and documentation
```

## 📝 Commit Message Best Practices

### Good Examples:
- `feat(terraform): add Kubernetes cluster infrastructure`
- `refactor(vm): migrate from cloud-init to NixOS configuration`
- `docs(phase2): add nixos-generators implementation guide`
- `chore(scripts): add automation for ISO generation`

### Avoid:
- `update files` (too vague)
- `fix stuff` (not descriptive)
- `WIP` (work in progress, should be squashed)
- `terraform changes` (missing scope and detail)

## 🎯 Benefits of This Strategy

1. **Reviewable Changes** - Each commit has a clear, focused purpose
2. **Rollback Safety** - Can revert specific features without affecting others
3. **History Clarity** - Easy to understand project evolution
4. **Collaboration** - Clear scope makes code review efficient
5. **Documentation** - Commit messages serve as change documentation

## 🚀 Execution Commands

```bash
# Make scripts executable first
chmod +x scripts/*.sh

# Follow the commit sequence above, or use your preferred grouping
# Each commit should be atomic and deployable
```

This strategy ensures your massive NixOS experiment has a clean, professional git history that's easy to navigate and understand!