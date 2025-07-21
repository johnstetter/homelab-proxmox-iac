# Phase 2 Developer's Guide: NixOS Node Configuration

This guide provides step-by-step instructions for implementing **Phase 2** of the NixOS Kubernetes experiment: transitioning from placeholder configurations to fully functional NixOS-based Kubernetes nodes.

## 🎯 Phase 2 Objectives

- Generate NixOS cloud-init ISOs using `nixos-generators`
- Populate NixOS configurations with Kubernetes components
- Create Proxmox VM templates from NixOS ISOs
- Automate the entire process with utility scripts

## 📋 Prerequisites

- **Nix package manager** installed
- **Proxmox VE** access for template creation
- **Phase 1** Terraform infrastructure completed

## 🛠️ Installation Requirements

### Install Nix (if not already installed)
```bash
# Install Nix package manager
curl -L https://nixos.org/nix/install | sh
source ~/.nix-profile/etc/profile.d/nix.sh

# Enable flakes (recommended)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Nix Environment Setup
```bash
# Source Nix environment (required for each terminal session)
source ~/.nix-profile/etc/profile.d/nix.sh

# Optional: Add to shell profile for automatic loading
echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
```

**Note**: The scripts use `nix run` to access nixos-generators dynamically, so no permanent installation is required.

## 🚀 Phase 2 Implementation Steps

### Step 1: Populate NixOS Configurations

The existing NixOS configuration files need to be populated with Kubernetes components:

```bash
# Use the provided script to generate base configurations
./scripts/populate-nixos-configs.sh

# Or manually edit the files:
# - nixos/common/configuration.nix
# - nixos/dev/control.nix
# - nixos/dev/worker.nix
# - nixos/prod/control.nix
# - nixos/prod/worker.nix
```

### Step 2: Generate NixOS ISOs

Create cloud-init compatible NixOS ISOs for each node type:

```bash
# Source Nix environment first (required)
source ~/.nix-profile/etc/profile.d/nix.sh

# Generate all ISOs automatically (takes 10-30 minutes)
./scripts/generate-nixos-isos.sh

# Or generate individually:
./scripts/generate-nixos-isos.sh --type control --env dev
./scripts/generate-nixos-isos.sh --type worker --env dev
./scripts/generate-nixos-isos.sh --type control --env prod
./scripts/generate-nixos-isos.sh --type worker --env prod
```

### Step 3: Create Proxmox Templates

Upload ISOs to Proxmox and create VM templates:

```bash
# Automated template creation
./scripts/create-proxmox-templates.sh

# This script will:
# 1. Upload ISOs to Proxmox storage
# 2. Create VMs from ISOs
# 3. Configure cloud-init settings
# 4. Convert VMs to templates
```

### Step 4: Update Terraform Configuration

Update your `terraform.tfvars` to use the new NixOS templates:

```hcl
# For development environment:
vm_template = "nixos-2311-k8s-control-dev"  # Dev control plane template

# For production environment:
vm_template = "nixos-2311-k8s-control-prod"  # Prod control plane template
```

### Step 5: Deploy and Test

```bash
cd terraform/
terraform plan
terraform apply

# Test SSH access
ssh -i ssh_keys/k8s_private_key.pem nixos@<node-ip>
```

## 📁 Generated Artifacts

After completing Phase 2, you'll have:

```
build/
├── isos/
│   ├── nixos-k8s-control-dev.iso
│   ├── nixos-k8s-worker-dev.iso
│   ├── nixos-k8s-control-prod.iso
│   └── nixos-k8s-worker-prod.iso
├── templates/
│   └── proxmox-template-ids.json
└── logs/
    ├── iso-generation.log
    └── template-creation.log
```

## 🔧 Utility Scripts Reference

### `./scripts/populate-nixos-configs.sh`
Generates complete NixOS configurations with Kubernetes components.

**Usage:**
```bash
./scripts/populate-nixos-configs.sh [--force] [--env dev|prod]
```

**Options:**
- `--force`: Overwrite existing configurations
- `--env`: Target specific environment (default: both)

### `./scripts/generate-nixos-isos.sh`
Creates NixOS ISOs using nixos-generators with cloud-init support.

**Usage:**
```bash
./scripts/generate-nixos-isos.sh [--type control|worker] [--env dev|prod] [--output-dir DIR]
```

**Options:**
- `--type`: Node type (default: all)
- `--env`: Environment (default: all)
- `--output-dir`: Output directory (default: ./build/isos/)

### `./scripts/create-proxmox-templates.sh`
Automates Proxmox template creation from generated ISOs.

**Usage:**
```bash
./scripts/create-proxmox-templates.sh [--proxmox-host HOST] [--storage STORAGE]
```

**Options:**
- `--proxmox-host`: Proxmox server hostname/IP
- `--storage`: Storage pool for templates (default: local)

### `./scripts/validate-phase2.sh`
Validates Phase 2 implementation and tests connectivity.

**Usage:**
```bash
./scripts/validate-phase2.sh [--terraform-dir DIR]
```

## 🧪 Testing Phase 2

### Validation Checklist

- [ ] NixOS configurations are populated with Kubernetes components
- [ ] ISOs are generated successfully
- [ ] Proxmox templates are created and accessible
- [ ] Terraform can deploy VMs using NixOS templates
- [ ] SSH access works with generated keys
- [ ] Kubernetes components are installed and configured
- [ ] Nodes can join the cluster

### Manual Testing

```bash
# Source Nix environment
source ~/.nix-profile/etc/profile.d/nix.sh

# Test ISO generation
./scripts/generate-nixos-isos.sh --type control --env dev

# Test template creation
./scripts/create-proxmox-templates.sh --proxmox-host your-proxmox-server

# Test Terraform deployment
cd terraform/
terraform apply -target=module.k8s_control_plane[0]

# Test SSH connectivity
ssh -i ssh_keys/k8s_private_key.pem nixos@<control-plane-ip>

# Verify Kubernetes installation
ssh -i ssh_keys/k8s_private_key.pem nixos@<control-plane-ip> "sudo systemctl status kubelet"
```

## 🐛 Troubleshooting

### Common Issues

**ISO Generation Fails:**
```bash
# Check Nix environment
source ~/.nix-profile/etc/profile.d/nix.sh
nix --version

# Verify experimental features are enabled
cat ~/.config/nix/nix.conf
```

**Template Creation Fails:**
```bash
# Check Proxmox API access
curl -k https://your-proxmox:8006/api2/json/version

# Verify storage availability
pvesm status
```

**SSH Access Issues:**
```bash
# Check SSH key permissions
chmod 600 ssh_keys/k8s_private_key.pem

# Verify cloud-init completion
ssh -i ssh_keys/k8s_private_key.pem nixos@<ip> "sudo cloud-init status"
```

## 🔄 Integration with Phase 3

Once Phase 2 is complete, you'll be ready for **Phase 3: Kubernetes Installation**:

- Use the generated Ansible inventory
- Deploy Kubernetes with kubeadm or explore nix-k3s
- Configure CNI networking (Flannel/Calico)
- Set up cluster networking and storage

## 📚 Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-generators Documentation](https://github.com/nix-community/nixos-generators)
- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Kubernetes on NixOS](https://nixos.wiki/wiki/Kubernetes)

---

**Next:** After completing Phase 2, proceed to Phase 3 for Kubernetes cluster initialization and configuration.