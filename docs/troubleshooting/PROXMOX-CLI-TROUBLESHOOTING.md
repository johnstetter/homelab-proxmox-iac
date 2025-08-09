# Proxmox CLI Troubleshooting Guide

This guide contains essential Proxmox CLI commands for troubleshooting VMs, storage, and infrastructure issues.

## VM Management Commands

### List VMs
```bash
# List all VMs with status
qm list

# List only running VMs
qm list | grep running

# List VMs with more details
qm list --full
```

### VM Status and Information
```bash
# Check VM status
qm status <vmid>

# Get VM configuration
qm config <vmid>

# Show VM configuration in JSON format
qm config <vmid> --current

# Get VM uptime and resource usage
qm monitor <vmid> info status
```

### VM Operations
```bash
# Start VM
qm start <vmid>

# Stop VM gracefully
qm stop <vmid>

# Force stop VM
qm stop <vmid> --force

# Restart VM
qm reboot <vmid>

# Reset VM (hard reset)
qm reset <vmid>

# Suspend VM
qm suspend <vmid>

# Resume VM
qm resume <vmid>
```

### VM Console Access
```bash
# Open VNC console (requires GUI)
qm vncproxy <vmid>

# Access serial console
qm terminal <vmid>

# Send monitor commands
qm monitor <vmid> <command>

# Take screenshot (saves to /tmp)
qm vncproxy <vmid> --generate-password 0
```

### VM Cloning and Templates
```bash
# Clone VM
qm clone <source_vmid> <new_vmid> --name <new_name>

# Clone with full copy
qm clone <source_vmid> <new_vmid> --name <new_name> --full

# Clone to different storage
qm clone <source_vmid> <new_vmid> --name <new_name> --storage <storage_name>

# Convert VM to template
qm template <vmid>

# List templates
qm list | grep template
```

### Disk Management
```bash
# Resize disk
qm resize <vmid> <disk> <size>
# Example: qm resize 100 scsi0 +10G

# Add disk to VM
qm set <vmid> --scsi1 <storage>:<size>

# Remove disk from VM
qm set <vmid> --delete scsi1

# Move disk to different storage
qm move_disk <vmid> <disk> <target_storage>

# Show disk usage
qm disk rescan <vmid>
```

## Storage Commands

### ZFS Storage
```bash
# List ZFS pools
zpool list

# List ZFS datasets
zfs list

# List datasets for specific pool
zfs list | grep tank

# Show ZFS pool status
zpool status

# Destroy ZFS dataset
zfs destroy <dataset_name>

# Create ZFS dataset
zfs create <dataset_name>

# Show ZFS properties
zfs get all <dataset_name>
```

### Proxmox Storage
```bash
# List storage configurations
pvesm status

# Show storage content
pvesm list <storage_name>

# Check storage capacity
pvesm status --storage <storage_name>

# Remove orphaned disk images
pvesm list <storage_name> --vmid <vmid>
```

## Network Troubleshooting

### VM Network Configuration
```bash
# Show VM network configuration
qm config <vmid> | grep net

# Set network interface
qm set <vmid> --net0 virtio,bridge=vmbr0

# Show bridge configuration
ip link show vmbr0

# Show VM IP addresses (if guest agent is running)
qm guest cmd <vmid> network-get-interfaces
```

### Network Connectivity
```bash
# Test connectivity from Proxmox host
ping <vm_ip>

# Show ARP table
arp -a

# Show network bridges
brctl show

# Show bridge MAC table
brctl showmacs vmbr0
```

## Cloud-Init Troubleshooting

### Cloud-Init Configuration
```bash
# Show cloud-init configuration
qm config <vmid> | grep -E "ci|ssh|ip"

# Set cloud-init user
qm set <vmid> --ciuser <username>

# Set SSH keys
qm set <vmid> --sshkeys <path_to_public_key>

# Set IP configuration
qm set <vmid> --ipconfig0 ip=<ip>/<cidr>,gw=<gateway>

# Set nameserver
qm set <vmid> --nameserver <dns_server>
```

### Cloud-Init Status (inside VM)
```bash
# Check cloud-init status (run inside VM)
cloud-init status

# View cloud-init logs (run inside VM)
cloud-init query --all
tail -f /var/log/cloud-init.log
tail -f /var/log/cloud-init-output.log

# Re-run cloud-init (run inside VM)
cloud-init clean
cloud-init init
```

## Boot and Console Troubleshooting

### Boot Issues
```bash
# Check VM boot configuration
qm config <vmid> | grep -E "boot|bios"

# Set boot order
qm set <vmid> --boot c

# Set bootdisk
qm set <vmid> --bootdisk scsi0

# Enable/disable UEFI
qm set <vmid> --bios ovmf  # UEFI
qm set <vmid> --bios seabios  # BIOS
```

### Console and Graphics
```bash
# Set VGA type
qm set <vmid> --vga qxl

# Enable serial console
qm set <vmid> --serial0 socket

# Set VNC display
qm set <vmid> --vga std

# Check console output (if serial console is enabled)
qm terminal <vmid>
```

## Hardware Configuration

### CPU and Memory
```bash
# Set CPU cores
qm set <vmid> --cores <number>

# Set CPU type
qm set <vmid> --cpu host

# Set memory
qm set <vmid> --memory <mb>

# Enable/disable balloon
qm set <vmid> --balloon <mb>
```

### Advanced Hardware
```bash
# Enable QEMU guest agent
qm set <vmid> --agent enabled=1

# Set SCSI controller
qm set <vmid> --scsihw virtio-scsi-pci

# Set machine type
qm set <vmid> --machine q35

# Enable KVM hardware acceleration
qm set <vmid> --kvm 1
```

## Backup and Restore

### Backup Operations
```bash
# Create backup
vzdump <vmid>

# Create backup to specific location
vzdump <vmid> --storage <storage_name>

# List backups
pvesm list <backup_storage>

# Restore from backup
qmrestore <backup_file> <vmid>
```

## Logs and Monitoring

### System Logs
```bash
# View Proxmox logs
journalctl -u pveproxy
journalctl -u pvedaemon
journalctl -u pve-cluster

# View QEMU logs
tail -f /var/log/qemu-server/<vmid>.log

# View system messages
dmesg | tail

# View syslog
tail -f /var/log/syslog
```

### Resource Monitoring
```bash
# Show resource usage
pvesh get /nodes/<node_name>/status

# Show VM resource usage
qm monitor <vmid> info status

# Show storage usage
df -h

# Show memory usage
free -h

# Show CPU usage
top
```

## Common Troubleshooting Scenarios

### VM Won't Start
1. Check VM configuration: `qm config <vmid>`
2. Check storage availability: `pvesm status`
3. Check logs: `tail -f /var/log/qemu-server/<vmid>.log`
4. Verify disk paths exist
5. Check resource availability (memory, CPU)

### VM Won't Boot
1. Check boot configuration: `qm config <vmid> | grep boot`
2. Access console: `qm terminal <vmid>`
3. Check disk integrity
4. Verify boot disk exists and is accessible
5. Check BIOS/UEFI settings

### Network Issues
1. Check VM network config: `qm config <vmid> | grep net`
2. Verify bridge exists: `brctl show`
3. Check firewall rules
4. Test connectivity from host: `ping <vm_ip>`
5. Check guest agent status: `qm agent <vmid> ping`

### Storage Issues
1. Check storage status: `pvesm status`
2. Verify ZFS pool health: `zpool status`
3. Check disk space: `df -h`
4. Look for orphaned disk images
5. Check permissions on storage paths

### Template and Clone Issues
1. Verify template exists: `qm list | grep template`
2. Check source template configuration: `qm config <template_vmid>`
3. Ensure target storage has space
4. Check if cross-storage cloning is supported
5. Verify clone parameters are correct

## Emergency Recovery

### VM Recovery
```bash
# Force stop unresponsive VM
qm stop <vmid> --force

# Kill VM process directly
pkill -f "kvm.*vmid=<vmid>"

# Reset VM configuration to defaults
qm set <vmid> --delete <problematic_option>

# Restore VM from backup
qmrestore <backup_file> <new_vmid>
```

### Storage Recovery
```bash
# Import orphaned ZFS pool
zpool import

# Scrub ZFS pool
zpool scrub <pool_name>

# Check and repair filesystem
fsck /dev/<device>

# Emergency storage cleanup
find /var/lib/vz -name "*.tmp" -delete
```

This troubleshooting guide covers the most common Proxmox CLI operations and troubleshooting scenarios encountered during VM deployment and management.