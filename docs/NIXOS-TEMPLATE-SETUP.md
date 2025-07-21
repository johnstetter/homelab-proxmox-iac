# NixOS VM Template Creation for Proxmox

This guide covers the **automated** creation of NixOS VM templates for Phase 2 Kubernetes infrastructure.

## Overview

The project uses a **fully automated approach** to create Proxmox templates with:
- NixOS with cloud-init support
- Pre-configured Kubernetes components (kubelet, containerd, etc.)
- SSH key authentication
- Qemu guest agent

## Automated Workflow (Recommended)

### Phase 2 Automated Template Creation

The project includes complete automation scripts for template creation:

```bash
# 1. Populate NixOS configurations with Kubernetes components
./scripts/populate-nixos-configs.sh

# 2. Source Nix environment and generate cloud-init NixOS ISOs
source ~/.nix-profile/etc/profile.d/nix.sh
./scripts/generate-nixos-isos.sh

# 3. Create Proxmox templates from the generated ISOs
./scripts/create-proxmox-templates.sh --proxmox-host YOUR_PROXMOX_IP
```

This creates templates like:
- `nixos-2311-k8s-controlplane-dev` (for control plane nodes)
- `nixos-2311-k8s-worker-dev` (for worker nodes)

### Prerequisites

1. **Nix Package Manager** (for nixos-generators):
```bash
# Install Nix (single-user installation)
curl -L https://nixos.org/nix/install | sh
source ~/.nix-profile/etc/profile.d/nix.sh

# Or enter nix-shell for the session
nix-shell -p nixos-generators
```

2. **SSH access to Proxmox server**:
```bash
# Set up SSH key authentication to your Proxmox server
ssh-keygen -t rsa -b 4096 -f ~/.ssh/proxmox_key
ssh-copy-id -i ~/.ssh/proxmox_key root@YOUR_PROXMOX_IP
```

3. **Sufficient disk space** on both local machine and Proxmox for ISO generation and template creation.

### Step-by-Step Template Creation

#### Step 1: Generate NixOS Configurations

```bash
# Populates nixos/ directory with Kubernetes-ready configurations
./scripts/populate-nixos-configs.sh

# This creates configurations in:
# - nixos/dev/controlplane.nix
# - nixos/dev/worker.nix  
# - nixos/prod/controlplane.nix
# - nixos/prod/worker.nix
```

#### Step 2: Generate Cloud-Init ISOs

```bash
# Source Nix environment (required for each session)
source ~/.nix-profile/etc/profile.d/nix.sh

# Generate ISOs for all configurations
./scripts/generate-nixos-isos.sh

# Or generate specific ones:
./scripts/generate-nixos-isos.sh --type control --env dev
./scripts/generate-nixos-isos.sh --type worker --env dev
```

This creates ISOs in `build/isos/`:
- `nixos-k8s-control-dev.iso`
- `nixos-k8s-worker-dev.iso`

**Note**: ISO generation can take 10-30 minutes depending on your machine as it builds a complete NixOS system.

#### Step 3: Create Proxmox Templates

```bash
# Upload ISOs and create templates automatically
./scripts/create-proxmox-templates.sh --proxmox-host 192.168.1.100

# Optional parameters:
./scripts/create-proxmox-templates.sh \
    --proxmox-host 192.168.1.100 \
    --proxmox-user root@pam \
    --storage local-lvm \
    --template-start-id 9000
```

This script will:
1. Upload generated ISOs to Proxmox
2. Create VMs from the ISOs
3. Configure cloud-init, networking, and qemu-agent
4. Convert VMs to templates
5. Generate `build/templates/proxmox-template-ids.json` with template mappings

### Script Locations and Where to Run

All commands should be run from the **project root** directory (`/home/stetter/code/k8s-infra/`):

```bash
cd /home/stetter/code/k8s-infra/

# These scripts expect to be run from project root:
./scripts/populate-nixos-configs.sh       # Populates nixos/ directory

# Source Nix environment before ISO generation
source ~/.nix-profile/etc/profile.d/nix.sh
./scripts/generate-nixos-isos.sh          # Creates build/isos/ (10-30 min)

./scripts/create-proxmox-templates.sh     # Uses build/isos/, creates templates
```

### Nix Environment Setup

The `generate-nixos-isos.sh` script uses `nix run` to access nixos-generators:

```bash
# Always source Nix environment first (required for each terminal session):
source ~/.nix-profile/etc/profile.d/nix.sh

# Then run the ISO generation script:
./scripts/generate-nixos-isos.sh

# You can also add the source command to your shell profile:
echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
```

**Important**: You must source the Nix profile in each new terminal session before running the ISO generation script.

## Verification

### Check Generated Templates

```bash
# List templates on Proxmox
ssh root@YOUR_PROXMOX_IP "qm list | grep template"

# View template details
cat build/templates/proxmox-template-ids.json
```

### Test Template with Terraform

Update your `terraform.tfvars`:

```hcl
# Use the generated template names
control_plane_template = "nixos-2311-k8s-control-dev"
worker_template = "nixos-2311-k8s-worker-dev"
```

Test deployment:

```bash
cd terraform/
terraform plan
```

## Template Features

The automated templates include:

**Base NixOS System:**
- ✅ NixOS 25.05 (updated from 23.11)
- ✅ Cloud-init with ext4 filesystem support  
- ✅ Qemu guest agent
- ✅ SSH key authentication (no password auth)
- ✅ nixos user with sudo access

**Kubernetes Pre-configuration:**
- ✅ Containerd container runtime
- ✅ Kubelet, kubeadm, kubectl pre-installed
- ✅ Required kernel modules (br_netfilter, overlay)
- ✅ Kubernetes networking sysctls configured
- ✅ Swap disabled
- ✅ Memory cgroup enabled

**Networking & Security:**
- ✅ NetworkManager for interface management
- ✅ Firewall configured for Kubernetes ports
- ✅ Docker group access for nixos user

## Troubleshooting

### Common Issues

**nixos-generators not found:**
```bash
# Source Nix environment first
source ~/.nix-profile/etc/profile.d/nix.sh
# Then run the script
./scripts/generate-nixos-isos.sh
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
# Check if configurations exist
ls -la nixos/dev/
ls -la nixos/prod/

# Run populate script first
./scripts/populate-nixos-configs.sh
```

**Template creation fails:**
```bash
# Check if ISOs were generated
ls -la build/isos/

# Check Proxmox storage
ssh root@YOUR_PROXMOX_IP "df -h /var/lib/vz"
```

### Validation Script

```bash
# Validate the entire Phase 2 setup
./scripts/validate-phase2.sh
```

## Manual Template Creation (Fallback)

If automation fails, you can manually create a basic template:

1. Download NixOS ISO:
```bash
cd /var/lib/vz/template/iso/
wget https://releases.nixos.org/nixos/25.05/nixos-25.05.805252.b43c397f6c21/nixos-minimal-25.05.805252.b43c397f6c21-x86_64-linux.iso
```

2. Create VM in Proxmox web interface:
   - VM ID: 9000
   - Name: `nixos-2311-cloud-init`
   - ISO: Select downloaded NixOS ISO
   - Memory: 2048 MB
   - Disk: 32 GB (virtio-scsi)
   - Network: virtio, bridge=vmbr0
   - Enable Qemu Agent: ✅

3. Install NixOS with basic cloud-init configuration
4. Convert to template: `qm template 9000`

## Next Steps

1. **Run the automation scripts** in order
2. **Update terraform.tfvars** with generated template names
3. **Test with Terraform**: `terraform plan` 
4. **Deploy cluster**: `terraform apply`
5. **Phase 3**: Kubernetes cluster initialization (future)

---

**Note**: This automated approach replaces manual template creation and integrates directly with the Terraform infrastructure provisioning.