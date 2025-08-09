# K8S Infrastructure Documentation

This directory contains comprehensive documentation for the k8s-infra project.

## 📁 Documentation Structure

### Setup Guides (`setup/`)
- **[GITLAB-CI-SETUP.md](setup/GITLAB-CI-SETUP.md)** - GitLab CI/CD pipeline configuration
- **[NIXOS-TEMPLATE-SETUP.md](setup/NIXOS-TEMPLATE-SETUP.md)** - NixOS template creation process
- **[PROXMOX-API-SETUP.md](setup/PROXMOX-API-SETUP.md)** - Proxmox API authentication setup
- **[S3-DYNAMODB-SETUP.md](setup/S3-DYNAMODB-SETUP.md)** - AWS S3/DynamoDB backend configuration
- **[UBUNTU-TEMPLATE-SETUP.md](setup/UBUNTU-TEMPLATE-SETUP.md)** - Ubuntu template creation process

### User Guides (`guides/`)
- **[DISK-RESIZE-GUIDE.md](guides/DISK-RESIZE-GUIDE.md)** - VM disk resizing procedures
- **[NIXOS-TEMPLATE-INSTALLATION.md](guides/NIXOS-TEMPLATE-INSTALLATION.md)** - NixOS template installation details
- **[TEMPLATE-PROJECT-GUIDE.md](guides/TEMPLATE-PROJECT-GUIDE.md)** - Creating new projects from templates

### Architecture (`architecture/`)
- **[PROJECT-STRUCTURE.md](architecture/PROJECT-STRUCTURE.md)** - Project organization and path resolution
- **[ROOT-MODULES-ARCHITECTURE.md](architecture/ROOT-MODULES-ARCHITECTURE.md)** - Terraform module architecture

### Troubleshooting (`troubleshooting/`)
- **[PROXMOX-CLI-TROUBLESHOOTING.md](troubleshooting/PROXMOX-CLI-TROUBLESHOOTING.md)** - Common Proxmox issues and solutions

### Development (`development/`)
- **[CLAUDE.md](development/CLAUDE.md)** - Claude Code assistant reference
- **[GITIGNORE-STRATEGY.md](development/GITIGNORE-STRATEGY.md)** - Git ignore patterns strategy
- **[README-phase2.md](development/README-phase2.md)** - Phase 2 development notes
- **[README-phase3.md](development/README-phase3.md)** - Phase 3 planning
- **[README-prompt.md](development/README-prompt.md)** - Initial project prompts
- **[README-roadmap.md](development/README-roadmap.md)** - Project roadmap
- **[TESTING-PLAN.md](development/TESTING-PLAN.md)** - NixOS testing strategy
- **[TODO.md](development/TODO.md)** - Project task tracking
- **[UBUNTU-TESTING-PLAN.md](development/UBUNTU-TESTING-PLAN.md)** - Ubuntu testing strategy

## 🚀 Quick Start

1. **Initial Setup**: Start with [setup/](setup/) guides for infrastructure prerequisites
2. **Architecture**: Understand the project structure with [architecture/](architecture/) docs
3. **Development**: Use [development/CLAUDE.md](development/CLAUDE.md) for common commands and patterns
4. **Guides**: Follow [guides/](guides/) for specific operational procedures
5. **Issues**: Check [troubleshooting/](troubleshooting/) for common problems and solutions

## 📝 Documentation Conventions

- **Setup guides**: Step-by-step configuration procedures
- **User guides**: Task-oriented operational documentation  
- **Architecture docs**: Design decisions and system structure
- **Development docs**: Internal development notes and references
- **Troubleshooting**: Problem-solving and debugging guides

## 🔄 Maintenance

Documentation is maintained alongside code changes. When updating infrastructure or processes, ensure corresponding documentation is updated.