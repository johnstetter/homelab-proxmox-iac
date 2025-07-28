# Disk Resize Guide for NixOS VMs

This guide covers resizing VM disks for NixOS VMs deployed from LVM-based templates. The process works for both running VMs and templates.

## Overview

The LVM setup in our NixOS templates provides flexible disk management:
- **EFI boot partition**: 512MB (fixed size)
- **LVM physical volume**: Remaining space containing:
  - **swap LV**: 4GB (resizable)
  - **root LV**: Rest of disk (easily resizable)

## Prerequisites

- VM using LVM-based NixOS template
- Access to Proxmox host for disk operations
- SSH or console access to the VM

## Resize Process

### Step 1: Increase Disk Size in Proxmox

**For Running VMs:**
```bash
# Resize the virtual disk (e.g., from 20GB to 50GB)
ssh root@192.168.1.5 'qm resize VMID scsi0 50G'
```

**For Templates:**
```bash
# Convert template to VM temporarily
ssh root@192.168.1.5 'qm clone TEMPLATE_ID 999 --name temp-resize'
ssh root@192.168.1.5 'qm resize 999 scsi0 50G'
ssh root@192.168.1.5 'qm template 999'
# Optional: rename and replace original template
```

Replace `VMID` with the actual VM ID and `50G` with your desired size.

### Step 2: Extend Partition Inside VM

SSH to the VM or use console access:

```bash
# Check current disk layout
lsblk

# Method 1: Using growpart (if available)
growpart /dev/sda 2

# Method 2: Using fdisk (if growpart not available)
fdisk /dev/sda
# In fdisk:
# d, 2          (delete partition 2)
# n, p, 2       (create new primary partition 2)
# <enter>       (use default start sector - same as before)
# <enter>       (use default end sector - end of disk)
# w             (write changes)
```

**Note:** The fdisk method is safe because you're recreating the partition with the same start sector.

### Step 3: Extend LVM Components

```bash
# Extend the physical volume to use new space
pvresize /dev/sda2

# Verify new space is available
vgdisplay nixos-vg
# Look for "Free PE / Size" to see available space

# Extend the root logical volume
lvextend -l +100%FREE /dev/nixos-vg/root

# Alternative: extend by specific amount
# lvextend -L +20G /dev/nixos-vg/root
```

### Step 4: Resize the Filesystem

```bash
# Resize the ext4 filesystem to use new space
resize2fs /dev/nixos-vg/root

# Verify the new size
df -h /
```

### Step 5: Verify Results

```bash
# Check disk usage
df -h

# Check LVM layout
lsblk
lvdisplay
```

## Alternative: Resize Swap Instead

If you need more swap space instead of root space:

```bash
# After extending the PV (steps 1-2 above)
lvextend -L +4G /dev/nixos-vg/swap  # Add 4GB to swap
swapoff /dev/nixos-vg/swap          # Turn off swap
mkswap /dev/nixos-vg/swap           # Recreate swap
swapon /dev/nixos-vg/swap           # Turn back on
```

## Automated Resize with Cloud-Init

For automatic resizing during VM provisioning, add this to your cloud-init configuration:

```yaml
#cloud-config
runcmd:
  # Wait for system to fully boot
  - sleep 30
  # Extend partition
  - growpart /dev/sda 2 || echo "Partition already at max size"
  # Extend LVM
  - pvresize /dev/sda2
  - lvextend -l +100%FREE /dev/nixos-vg/root
  - resize2fs /dev/nixos-vg/root
  # Log completion
  - echo "Disk resize completed" >> /var/log/cloud-init-resize.log
```

## Terraform Integration

You can automate disk resizing in your Terraform configuration:

```hcl
resource "proxmox_vm_qemu" "vm" {
  # ... other configuration ...
  
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.disk_storage
    size    = var.disk_size  # e.g., "50G"
    format  = "raw"
    cache   = "writeback"
  }
}

# Resize disk after VM creation
resource "null_resource" "disk_resize" {
  count = var.auto_resize_disk ? 1 : 0
  
  depends_on = [proxmox_vm_qemu.vm]
  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = proxmox_vm_qemu.vm.default_ipv4_address
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }
    
    inline = [
      "growpart /dev/sda 2 || true",
      "pvresize /dev/sda2",
      "lvextend -l +100%FREE /dev/nixos-vg/root",
      "resize2fs /dev/nixos-vg/root"
    ]
  }
}
```

## Troubleshooting

### Common Issues

1. **"Device or resource busy"**
   - Reboot the VM after partition resize
   - Or try: `partprobe /dev/sda`

2. **"No space left on device"**
   - Check if the Proxmox disk was actually resized: `lsblk`
   - Verify partition was extended: `fdisk -l /dev/sda`

3. **LVM not detecting new space**
   - Force PV scan: `pvscan`
   - Check PV status: `pvdisplay /dev/sda2`

### Verification Commands

```bash
# Check physical disk size
lsblk

# Check partition table
fdisk -l /dev/sda

# Check LVM physical volume
pvdisplay /dev/sda2

# Check volume group
vgdisplay nixos-vg

# Check logical volumes
lvdisplay nixos-vg

# Check filesystem usage
df -h /
```

## Shrinking Disks (Advanced)

**Warning:** Shrinking is more dangerous and requires careful planning.

1. Shrink filesystem first: `resize2fs /dev/nixos-vg/root 15G`
2. Shrink logical volume: `lvreduce -L 15G /dev/nixos-vg/root`
3. Shrink physical volume (requires moving data if needed)
4. Shrink partition using fdisk
5. Shrink VM disk in Proxmox

**Recommendation:** Create backups before shrinking operations.

## Best Practices

1. **Always backup** before major disk operations
2. **Test resize process** on non-production VMs first
3. **Monitor disk usage** to plan resize operations
4. **Use automation** (cloud-init/Terraform) for consistent deployments
5. **Document custom sizes** in your infrastructure code
6. **Consider growth patterns** when sizing initially

## Integration with Monitoring

Add disk usage monitoring to catch resize needs early:

```nix
# In your NixOS configuration
services.prometheus.exporters.node = {
  enable = true;
  enabledCollectors = [ "filesystem" ];
};
```

This LVM-based approach provides the flexibility to easily resize disks as your infrastructure needs grow, whether manually or through automation.