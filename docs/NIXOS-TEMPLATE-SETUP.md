# NixOS VM Template Creation for Proxmox

This guide covers creating NixOS VM templates for use with Terraform automation in Phase 2 of the project.

## Overview

The Terraform configuration expects a VM template named `nixos-2311-cloud-init` that includes:
- NixOS with cloud-init support
- SSH key authentication
- Proper networking configuration
- Qemu guest agent

## Prerequisites

- Proxmox VE server with sufficient storage
- NixOS ISO (23.11 or compatible)
- Administrative access to Proxmox
- Basic understanding of NixOS configuration

## Method 1: Manual Template Creation (Immediate Solution)

### Step 1: Download NixOS ISO

```bash
# On Proxmox server, download NixOS ISO
cd /var/lib/vz/template/iso/
wget https://releases.nixos.org/nixos/23.11/nixos-23.11.6094.59075d5e4e9e-x86_64-linux.iso
```

### Step 2: Create VM in Proxmox

1. **Create New VM:**
   - VM ID: `9000` (or any free ID for template)
   - Name: `nixos-template`
   - ISO: Select downloaded NixOS ISO

2. **Configure Hardware:**
   - Memory: 2048 MB
   - Disk: 32 GB (virtio-scsi)
   - Network: virtio, bridge=vmbr0
   - Enable Qemu Agent: ✅

### Step 3: Install NixOS

Boot the VM and install NixOS with this configuration:

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.hostName = "nixos-template";
  networking.networkmanager.enable = true;

  # Enable cloud-init
  services.cloud-init = {
    enable = true;
    ext4.enable = true;
  };

  # Enable Qemu guest agent
  services.qemuGuest.enable = true;

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Create nixos user
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      # Temporary key - will be replaced by cloud-init
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... temp-key"
    ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Essential packages
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    git
    cloud-init
  ];

  # System packages for Kubernetes (Phase 3)
  virtualisation.docker.enable = true;
  
  system.stateVersion = "23.11";
}
```

### Step 4: Prepare Template

After installation:

1. **Clean up the VM:**
```bash
# Inside the VM
sudo nix-collect-garbage -d
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo rm -f /etc/machine-id
sudo truncate -s 0 /etc/machine-id
history -c
```

2. **Shutdown VM:**
```bash
sudo shutdown -h now
```

3. **Convert to Template:**
```bash
# On Proxmox server
qm template 9000
qm set 9000 --name nixos-2311-cloud-init
```

## Method 2: Automated Template Creation (Future Enhancement)

### Using nixos-generators

This is the recommended approach for Phase 2 automation:

```bash
# Install nixos-generators
nix-shell -p nixos-generators

# Generate Proxmox-compatible image
nixos-generate -f proxmox -c ./nixos-template-config.nix
```

### Template Configuration File

Create `nixos-template-config.nix`:

```nix
{ config, pkgs, ... }:

{
  # Base system configuration
  system.stateVersion = "23.11";
  
  # Cloud-init configuration
  services.cloud-init = {
    enable = true;
    ext4.enable = true;
    network.enable = true;
  };

  # Qemu guest agent
  services.qemuGuest.enable = true;

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    useDHCP = false;
    interfaces.ens18.useDHCP = true; # Adjust interface name as needed
  };

  # Users
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };

  # Enable sudo without password
  security.sudo.wheelNeedsPassword = false;

  # Essential packages for Kubernetes
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    git
    htop
    cloud-init
  ];

  # Container runtime for Kubernetes
  virtualisation.docker.enable = true;

  # Kernel modules for Kubernetes
  boot.kernelModules = [ "br_netfilter" "overlay" ];
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # Disable swap (required for Kubernetes)
  swapDevices = [ ];

  # Performance tuning
  boot.kernelParams = [ "cgroup_enable=memory" "cgroup_memory=1" ];
}
```

### Automation Script

Create `scripts/create-nixos-template.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
TEMPLATE_ID="9000"
TEMPLATE_NAME="nixos-2311-cloud-init"
NIXOS_CONFIG="./nixos-template-config.nix"
STORAGE="local-lvm"

echo "Creating NixOS template for Proxmox..."

# Generate the image
echo "Generating NixOS image..."
nixos-generate -f proxmox-lxc -c "$NIXOS_CONFIG" -o nixos-template.tar.xz

# Import to Proxmox
echo "Importing template to Proxmox..."
pct create "$TEMPLATE_ID" nixos-template.tar.xz \
  --hostname "$TEMPLATE_NAME" \
  --storage "$STORAGE" \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,dhcp=1

# Convert to template
echo "Converting to template..."
pct template "$TEMPLATE_ID"

echo "Template created successfully: $TEMPLATE_NAME"
echo "Template ID: $TEMPLATE_ID"
```

## Method 3: Using Existing Cloud Images (Quick Start)

For immediate testing, you can use pre-built cloud images:

### Download and Import

```bash
# Download NixOS cloud image (if available)
wget https://hydra.nixos.org/build/latest-finished/nixos/release-23.11/nixos.proxmox

# Import to Proxmox
qm importdisk 9000 nixos.proxmox local-lvm
qm set 9000 --name nixos-2311-cloud-init
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

## Verification

### Test the Template

1. **Clone the template:**
```bash
qm clone 9000 999 --name nixos-test
```

2. **Configure cloud-init:**
```bash
qm set 999 --ciuser nixos
qm set 999 --sshkeys ~/.ssh/id_rsa.pub
qm set 999 --ipconfig0 ip=dhcp
```

3. **Start and test:**
```bash
qm start 999
# Wait for boot, then test SSH access
ssh nixos@<vm-ip>
```

### Required Template Features

Verify your template includes:

- ✅ **Cloud-init enabled and working**
- ✅ **Qemu guest agent running**
- ✅ **SSH key authentication working**
- ✅ **Network configuration via cloud-init**
- ✅ **nixos user with sudo access**
- ✅ **Docker/container runtime available**

## Integration with Terraform

Once your template is ready, update the Terraform configuration:

```hcl
# In environments/dev.tfvars
vm_template = "nixos-2311-cloud-init"  # Must match your template name
```

## Troubleshooting

### Common Issues

**Cloud-init not working:**
```bash
# Check cloud-init status
sudo systemctl status cloud-init
sudo cloud-init status --long
```

**Network not configured:**
```bash
# Check network interfaces
ip addr show
# Check cloud-init network config
sudo cat /var/log/cloud-init.log
```

**SSH authentication failing:**
```bash
# Check SSH keys
sudo cat /home/nixos/.ssh/authorized_keys
# Check SSH daemon
sudo systemctl status sshd
```

### Template Debugging

```bash
# View cloud-init logs
sudo journalctl -u cloud-init

# Check cloud-init configuration
sudo cloud-init query --all

# Verify qemu-guest-agent
sudo systemctl status qemu-guest-agent
```

## Next Steps

1. **Create the template** using one of the methods above
2. **Test with Terraform** using a simple plan
3. **Phase 2**: Enhance with automated Kubernetes pre-configuration
4. **Phase 3**: Add cluster initialization automation

## Security Considerations

- Template should not contain any sensitive data
- SSH keys are injected via cloud-init, not baked into template
- Regular template updates for security patches
- Minimal package installation to reduce attack surface

---

**Note**: This template creation is a prerequisite for Phase 2. The current Terraform configuration expects this template to exist. Choose Method 1 for immediate deployment or Method 2 for automation.