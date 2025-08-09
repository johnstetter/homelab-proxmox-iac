# NixOS Base Template Installation Guide

This guide covers the manual installation of NixOS for the single base template approach. The base template serves as a foundation that can be customized later with role-specific configurations via cloud-init and nixos-generators.

## Prerequisites

- VM created with 20GB disk and QXL display (✅ done by template creation script)
- Boot from NixOS ISO (✅ configured by script)
- Access to VM console via Proxmox web interface
- VM should be at root prompt: `root@nixos:~#`

## Installation Methods

You can install NixOS either via:
1. **SSH** (recommended if VM has network access)
2. **Console** (via Proxmox web interface)

### Method 1: SSH Installation

First, start the VM and get its IP address:

```bash
# Start the VM (VM ID 9100 for base template)
ssh root@192.168.1.5 'qm start 9100'

# Wait ~60 seconds for boot, then get IP
ssh root@192.168.1.5 'qm guest cmd 9100 network-get-interfaces' | grep -o '"ip-address":"[^"]*"' | grep -v 127.0.0.1
```

Or check via Proxmox web interface in the VM's Summary tab.

Once you have the IP address:

```bash
# SSH to the VM (replace IP with actual VM IP)
ssh root@192.168.1.100
```

Then follow the installation steps below.

### Method 2: Console Installation

Access the VM console via Proxmox web interface:
1. Go to VM in Proxmox web UI
2. Click "Console" 
3. You should see `root@nixos:~#` prompt

## Installation Steps

### Step 1: Partition the Disk with LVM

Create partitions with LVM for better flexibility:

```bash
# Create partition layout with sfdisk
sfdisk /dev/sda << EOF
label: gpt
,512M,U
,,L
EOF
```

### Step 2: Set up LVM

```bash
# Create physical volume
pvcreate /dev/sda2

# Create volume group
vgcreate nixos-vg /dev/sda2

# Create logical volumes
lvcreate -L 4G -n swap nixos-vg     # 4GB swap
lvcreate -l 100%FREE -n root nixos-vg  # Rest for root
```

### Step 3: Format Filesystems

```bash
# Format EFI partition
mkfs.fat -F 32 -n boot /dev/sda1

# Format LVM volumes
mkfs.ext4 -L nixos /dev/nixos-vg/root
mkswap -L swap /dev/nixos-vg/swap
```

### Step 4: Mount Filesystems

```bash
# Mount root partition
mount /dev/nixos-vg/root /mnt

# Enable swap
swapon /dev/nixos-vg/swap

# Create and mount boot partition
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
```

### Step 5: Generate Base Configuration

Generate the initial NixOS configuration:

```bash
# Generate hardware configuration and base system config
nixos-generate-config --root /mnt
```

**Note:** The generated hardware configuration will automatically detect and configure LVM.

### Step 6: Edit Configuration (Required)

The generated configuration needs to be updated for proper EFI boot and VM functionality. Replace the entire contents:

```bash
# Use vi to edit (vim will be available after installation)
vi /mnt/etc/nixos/configuration.nix
```

**Replace entire file contents with:**

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot loader configuration for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking.useDHCP = true;
  networking.networkmanager.enable = false;  # Disable to avoid conflicts with useDHCP

  # Set timezone
  time.timeZone = "America/Chicago";

  # SSH configuration
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  # Enable QEMU guest agent for Proxmox
  services.qemuGuest.enable = true;

  # Enable cloud-init for VM customization
  services.cloud-init.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # Set state version (matches NixOS 24.11)
  system.stateVersion = "24.11";
}
```

**Alternative: Use template configuration file**

If you have the template config in your repo:

```bash
# Copy template config (if available)
cp /path/to/nixos-template-configuration.nix /mnt/etc/nixos/configuration.nix
```

### Step 7: Install NixOS

Install NixOS to the mounted filesystem:

```bash
# Install NixOS (this takes approximately 5-10 minutes)
nixos-install --no-root-passwd --root /mnt
```

**Note:** The installation process will:
- Download and install packages
- Generate bootloader configuration
- Set up LVM configuration automatically
- Set up the system according to your configuration

### Step 8: Shutdown VM

After installation completes successfully:

```bash
poweroff
```

## Post-Installation: Convert to Template

Once the VM has shut down, convert it to a Proxmox template from your local machine:

### Remove Installation Media

```bash
# Remove the ISO from the CD drive (VM ID 9100 for base template)
ssh root@192.168.1.5 'qm set 9100 --delete ide0'
```

### Set Boot Order

```bash
# Configure VM to boot from disk only
ssh root@192.168.1.5 'qm set 9100 --boot order=scsi0'
```

### Convert to Template

```bash
# Convert VM to template
ssh root@192.168.1.5 'qm template 9100'
```

## Template Verification

After conversion, verify the template:

1. **Check template exists:**
   ```bash
   ssh root@192.168.1.5 'qm list | grep 9100'
   ```

2. **Test clone creation:**
   ```bash
   ssh root@192.168.1.5 'qm clone 9100 999 --name test-clone --full'
   ssh root@192.168.1.5 'qm start 999'
   ```

3. **Clean up test:**
   ```bash
   ssh root@192.168.1.5 'qm stop 999 && qm destroy 999 --purge'
   ```

## Template Usage

The base NixOS template (`nixos-base-template`, VM ID 9100) will be used by:

- **Terraform Proxmox provider** for VM provisioning with `vm_template = "nixos-base-template"`
- **Cloud-init** for runtime configuration (SSH keys, networking, etc.)
- **Future nixos-generators integration** for role-specific customization

The base template provides a clean NixOS foundation that can be customized post-deployment for different roles (control plane, worker) and environments (dev, prod).

## Troubleshooting

### Common Issues

1. **Disk not found:** Ensure `/dev/sda` exists with `lsblk`
2. **Boot failure:** Verify EFI partition is properly formatted and mounted
3. **Network issues:** Check DHCP is working with `ip addr show`
4. **Installation hangs:** Wait patiently, NixOS downloads packages during install

### Recovery

If installation fails, you can:
1. Unmount filesystems: `umount /mnt/boot /mnt`
2. Start over from Step 1
3. Or reboot VM and try again

## Next Steps

After creating the base template:

1. **Update Terraform configurations** to use `vm_template = "nixos-base-template"`
2. **Test VM deployment** with `terraform plan/apply`
3. **Verify cloud-init functionality** with SSH key injection and networking
4. **Plan Phase 3 integration** with nixos-generators for role-specific configuration