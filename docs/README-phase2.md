# Phase 2 Developer's Guide: NixOS Base Template

This guide provides step-by-step instructions for implementing **Phase 2** of the NixOS Kubernetes experiment: creating a single base NixOS template that can be customized for different roles and environments.

## 🎯 Phase 2 Objectives

- Generate single base NixOS ISO using `nixos-generators`
- Create one Proxmox VM template for all node types
- Use LVM partitioning for disk resize capabilities
- Enable cloud-init for post-provisioning customization
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

# Enable experimental features
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Install nixos-generators
nix profile add nixpkgs#nixos-generators
```

### Nix Environment Setup
```bash
# Source Nix environment (required for each terminal session)
source ~/.nix-profile/etc/profile.d/nix.sh

# Optional: Add to shell profile for automatic loading
echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
```

## 🚀 Phase 2 Implementation Steps

### Step 1: Generate Base Template ISO

Create a single NixOS ISO with automated installation:

```bash
# Source Nix environment first (required)
source ~/.nix-profile/etc/profile.d/nix.sh

# Generate base template ISO (takes 10-30 minutes)
./scripts/generate-nixos-iso.sh

# This creates: build/isos/nixos-base-template.iso
```

### Step 2: Create Proxmox Base Template

Upload ISO to Proxmox and create the base template:

```bash
# Create base template
./scripts/create-proxmox-templates.sh --proxmox-host YOUR_PROXMOX_IP

# This script will:
# 1. Upload ISO to Proxmox storage
# 2. Create VM 9100 with 20GB disk
# 3. Configure for automated installation
# 4. Leave VM ready for manual completion
```

### Step 3: Complete Template Installation

Complete the NixOS installation manually:

1. **Start the VM and install NixOS**:
   - The ISO contains automated installation script
   - Uses LVM partitioning for resize capabilities
   - Installs base NixOS with cloud-init support

2. **Convert to template after installation**:
   ```bash
   ssh root@YOUR_PROXMOX_IP 'qm stop 9100'
   ssh root@YOUR_PROXMOX_IP 'qm set 9100 --delete ide0'
   ssh root@YOUR_PROXMOX_IP 'qm set 9100 --boot order=scsi0'
   ssh root@YOUR_PROXMOX_IP 'qm template 9100'
   ```

### Step 4: Update Terraform Configuration

Update your `terraform.tfvars` to use the single base template:

```hcl
# Use single base template for all deployments:
vm_template = "nixos-base-template"
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
│   └── nixos-base-template.iso
├── templates/
│   └── base-template-info.json
└── logs/
    ├── iso-generation.log
    └── template-creation.log
```

## 🔧 Utility Scripts Reference

### `./scripts/generate-nixos-iso.sh`
Creates single base NixOS ISO using nixos-generators with automated installation.

**Usage:**
```bash
./scripts/generate-nixos-iso.sh [--output-dir DIR] [--clean]
```

**Options:**
- `--output-dir`: Output directory (default: ./build/isos/)
- `--clean`: Clean build directory before generation

### `./scripts/create-proxmox-templates.sh`
Automates Proxmox base template creation from generated ISO.

**Usage:**
```bash
./scripts/create-proxmox-templates.sh --proxmox-host HOST [OPTIONS]
```

**Options:**
- `--proxmox-host`: Proxmox server hostname/IP (required)
- `--storage`: Storage pool for templates (default: local-zfs-tank)
- `--template-id`: VM ID for template (default: 9000)

### `./scripts/validate-phase2.sh`
Validates Phase 2 implementation and tests connectivity.

**Usage:**
```bash
./scripts/validate-phase2.sh [--terraform-dir DIR]
```

## 🧪 Testing Phase 2

### Validation Checklist

- [x] Base template ISO is generated successfully
- [x] Proxmox template is created (VM ID 9100, name: nixos-base-template)
- [x] Template uses LVM partitioning for disk resize
- [x] Terraform can deploy VMs using the base template
- [x] SSH access works with generated keys
- [x] Cloud-init configures VMs properly
- [x] Disk resizing works correctly

### Manual Testing

```bash
# Source Nix environment
source ~/.nix-profile/etc/profile.d/nix.sh

# Test ISO generation
./scripts/generate-nixos-iso.sh

# Test template creation
./scripts/create-proxmox-templates.sh --proxmox-host your-proxmox-server

# Test Terraform deployment
cd terraform/
terraform apply -target=module.k8s_control_plane[0]

# Test SSH connectivity
ssh -i ssh_keys/k8s_private_key.pem nixos@<control-plane-ip>

# Test disk resize
ssh root@your-proxmox-server 'qm resize <vmid> scsi0 +10G'
```

## 🐛 Troubleshooting

### Common Issues

**ISO Generation Fails:**
```bash
# Check Nix environment
source ~/.nix-profile/etc/profile.d/nix.sh
nix --version

# Check nixos-generators
nixos-generate --help

# Verify configuration exists
ls -la nixos/automated-template.nix
```

**Template Creation Fails:**
```bash
# Check Proxmox API access
ssh root@your-proxmox-server 'qm list'

# Verify storage availability
ssh root@your-proxmox-server 'pvesm status'

# Check ISO upload
ssh root@your-proxmox-server 'ls -la /var/lib/vz/template/iso/'
```

**SSH Access Issues:**
```bash
# Check SSH key permissions
chmod 600 ssh_keys/k8s_private_key.pem

# Verify cloud-init completion
ssh -i ssh_keys/k8s_private_key.pem nixos@<ip> "sudo cloud-init status"
```

## 🏗️ Architecture Benefits

### Single Template Approach

**Why One Template?**
- **Simplicity**: One template to maintain instead of four
- **Flexibility**: Role-specific configuration via cloud-init
- **Efficiency**: Faster deployment with post-provisioning setup
- **Maintenance**: Easier updates and version management

**Post-Provisioning Configuration:**
- Node-specific packages added via cloud-init
- Environment-specific settings applied during deployment
- Kubernetes configuration handled in future Phase 3

## 🔄 Integration with Phase 3

Once Phase 2 is complete, you'll be ready for **Phase 3: Kubernetes Configuration**:

- Use nixos-generators for role-specific configuration
- Install Kubernetes components (kubelet, containerd) post-deployment
- Configure CNI networking and cluster setup
- Leverage the single base template for all node types

## 📚 Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-generators Documentation](https://github.com/nix-community/nixos-generators)
- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [LVM Disk Management](https://tldp.org/HOWTO/LVM-HOWTO/)

---

**Next:** After completing Phase 2, proceed to Phase 3 for role-specific configuration and Kubernetes cluster setup.