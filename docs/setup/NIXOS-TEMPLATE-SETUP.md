# NixOS VM Template Creation for Proxmox

This guide covers the **automated** creation of a single base NixOS VM template for Phase 2 Kubernetes infrastructure.

## Overview

The project uses a **single base template approach** with:
- One base NixOS template with automated installation
- Cloud-init support for post-provisioning configuration
- SSH key authentication
- Qemu guest agent
- LVM partitioning for disk resize capabilities

## Automated Workflow (Recommended)

### Single Base Template Approach

The project creates a single base template that can be used for all node types (control plane and worker):

```bash
# 1. Source Nix environment and generate base template ISO
source ~/.nix-profile/etc/profile.d/nix.sh
./scripts/generate-nixos-iso.sh

# 2. Create Proxmox base template from the generated ISO
./scripts/create-proxmox-templates.sh --proxmox-host YOUR_PROXMOX_IP
```

This creates a single template:
- `nixos-base-template` (VM ID auto-assigned starting from 9100) - Base template for all node types

### Prerequisites

1. **Nix Package Manager** (for nixos-generators):
```bash
# Install Nix (single-user installation)
curl -L https://nixos.org/nix/install | sh
source ~/.nix-profile/etc/profile.d/nix.sh

# Enable experimental features
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Install nixos-generators
nix profile add nixpkgs#nixos-generators
```

2. **SSH access to Proxmox server**:
```bash
# Set up SSH key authentication to your Proxmox server
ssh-keygen -t rsa -b 4096 -f ~/.ssh/proxmox_key
ssh-copy-id -i ~/.ssh/proxmox_key root@YOUR_PROXMOX_IP
```

3. **Sufficient disk space** on both local machine and Proxmox for ISO generation and template creation.

### Step-by-Step Template Creation

#### Step 1: Generate Base Template ISO

```bash
# Source Nix environment (required for each session)
source ~/.nix-profile/etc/profile.d/nix.sh

# Generate base template ISO with automated installation
./scripts/generate-nixos-iso.sh

# This creates: build/isos/nixos-base-template.iso
```

**Note**: ISO generation can take 10-30 minutes depending on your machine as it builds a complete NixOS system with automated installation script.

#### Step 2: Create Proxmox Base Template

```bash
# Create base template from ISO
./scripts/create-proxmox-templates.sh --proxmox-host 192.168.1.5

# Optional parameters:
./scripts/create-proxmox-templates.sh \
    --proxmox-host 192.168.1.5 \
    --proxmox-user root \
    --storage local-zfs-tank \
    --template-id 9100  # Base ID - script will auto-increment if 9100 is in use
```

This script will:
1. Upload base template ISO to Proxmox
2. Find next available VM ID (starting from 9100) and create VM with 20GB disk and QXL display
3. Configure for automated NixOS installation
4. Start VM with automated systemd-managed installation
5. Monitor installation progress and auto-convert to template

#### Step 3: Automated Template Creation

The script handles the complete template creation process automatically:

1. **Automated Installation Process**:
   - VM boots from ISO with systemd service `nixos-auto-install` enabled
   - Installation runs automatically without manual intervention
   - Creates LVM partitioning with 20GB disk and 4GB swap
   - Installs NixOS with GRUB bootloader and cloud-init support
   - VM shuts down automatically when installation completes

2. **Automatic Template Conversion**:
   - Script monitors VM status and waits for shutdown
   - Removes installation ISO and converts VM to template
   - Sets proper boot order and template naming
   - Creates template info file with metadata

**Note**: The entire process is fully automated via systemd services - no manual console access required.

### Script Locations and Where to Run

All commands should be run from the **project root** directory (`/home/stetter/code/k8s-infra/`):

```bash
cd /home/stetter/code/k8s-infra/

# Source Nix environment before ISO generation
source ~/.nix-profile/etc/profile.d/nix.sh
./scripts/generate-nixos-iso.sh          # Creates build/isos/ (10-30 min)

./scripts/create-proxmox-templates.sh     # Uses build/isos/, creates base template
```

### Nix Environment Setup

The `generate-nixos-iso.sh` script uses nixos-generators:

```bash
# Always source Nix environment first (required for each terminal session):
source ~/.nix-profile/etc/profile.d/nix.sh

# Then run the ISO generation script:
./scripts/generate-nixos-iso.sh

# You can also add the source command to your shell profile:
echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
```

**Important**: You must source the Nix profile in each new terminal session before running the ISO generation script.

## Verification

### Check Generated Template

```bash
# List templates on Proxmox
ssh root@YOUR_PROXMOX_IP "qm list | grep template"

# View template details
cat build/templates/base-template-info.json
```

### Test Template with Terraform

Update your `terraform.tfvars`:

```hcl
# Use the single base template for all deployments:
vm_template = "nixos-base-template"
```

Test deployment:

```bash
cd terraform/
terraform plan
```

## Base Template Features

The automated base template includes:

**Base NixOS System:**
- ✅ NixOS 24.11 (stable)
- ✅ Cloud-init with LVM filesystem support  
- ✅ Qemu guest agent
- ✅ SSH key authentication (no password auth)
- ✅ nixos user with sudo access
- ✅ LVM partitioning for disk resize capabilities

**Essential Packages:**
- ✅ vim, git, curl, wget pre-installed
- ✅ systemd-boot bootloader (EFI)
- ✅ NetworkManager for interface management

**Post-Provisioning Ready:**
- ✅ Cloud-init enabled for role-specific configuration
- ✅ Ready for nixos-generators node-specific setup
- ✅ Supports both control plane and worker configurations

## Architecture Benefits

### Single Template Approach

**Why One Template?**
- **Simplicity**: One template to maintain instead of four (control/worker × dev/prod)
- **Flexibility**: Role-specific configuration via cloud-init and nixos-generators
- **Efficiency**: Faster deployment with post-provisioning configuration
- **Maintenance**: Easier updates and version management

**Post-Provisioning Configuration:**
- Node-specific packages (kubelet, containerd) added via cloud-init
- Environment-specific settings applied during deployment
- Kubernetes configuration handled by nixos-generators in Phase 2

## Troubleshooting

### Common Issues

**nixos-generators not found:**
```bash
# Install nixos-generators
nix profile add nixpkgs#nixos-generators

# Source Nix environment first
source ~/.nix-profile/etc/profile.d/nix.sh
# Then run the script
./scripts/generate-nixos-iso.sh
```

**SSH connection failed:**
```bash
# Test SSH access
ssh root@YOUR_PROXMOX_IP "echo 'Connection test'"

# Check SSH key
ssh-add -l
```

**ISO generation fails:**
```bash
# Check if NixOS configuration exists
ls -la nixos/base-template.nix

# Check Nix experimental features
cat ~/.config/nix/nix.conf
```

**Template creation fails:**
```bash
# Check if ISO was generated
ls -la build/isos/nixos-base-template.iso

# Check Proxmox storage
ssh root@YOUR_PROXMOX_IP "df -h /var/lib/vz"
```

## Disk Resize Capabilities

The base template uses LVM partitioning to support disk resizing:

```bash
# Resize VM disk in Proxmox
qm resize <vmid> scsi0 +10G

# Inside VM, extend LVM
sudo lvextend -l +100%FREE /dev/vg0/root
sudo resize2fs /dev/vg0/root
```

See `docs/disk-resize-guide.md` for complete resize procedures.

## Next Steps

1. **Generate base template**: Run `./scripts/generate-nixos-iso.sh`
2. **Create Proxmox template**: Run `./scripts/create-proxmox-templates.sh`
3. **Update terraform.tfvars**: Set `vm_template = "nixos-base-template"`
4. **Test with Terraform**: `terraform plan` 
5. **Deploy cluster**: `terraform apply`
6. **Phase 3**: Use nixos-generators for role-specific configuration

---

**Note**: This single template approach simplifies infrastructure management while maintaining flexibility for different node types and environments through post-provisioning configuration.