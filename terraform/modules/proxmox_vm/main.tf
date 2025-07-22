# Proxmox VM Resource
resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.template

  # VM Configuration
  cpu {
    cores = var.cores
  }
  memory   = var.memory
  onboot   = var.onboot
  agent    = var.agent
  balloon  = var.balloon
  boot     = var.boot
  bootdisk = var.bootdisk
  scsihw   = var.scsihw
  os_type  = var.os_type
  
  # VNC/Console Configuration
  vga {
    type   = "qxl"
    memory = 16
  }
  
  # Enable VNC console
  define_connection_info = true

  # Disk Configuration
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.disk_storage
    size    = var.disk_size
    cache   = "writeback"
  }

  # Cloud-init disk
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.disk_storage
  }

  # Network Configuration
  network {
    id       = 0
    model    = "virtio"
    bridge   = var.network_bridge
    tag      = var.network_vlan
    firewall = false
  }

  # Cloud-init Configuration
  ciuser     = var.ssh_user
  cipassword = ""
  sshkeys    = var.ssh_public_key

  # IP Configuration  
  ipconfig0  = "ip=${var.ip_address},gw=${var.gateway}"
  nameserver = var.nameserver
  
  # Additional cloud-init settings for NixOS
  cicustom   = ""
  ciupgrade  = false

  # NixOS will be configured via nixos-generators in Phase 2
  # For now, basic cloud-init with SSH key only

  # Tags
  tags = var.tags

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }

  # Cloud-init will complete automatically
}

# NixOS configuration will be handled by nixos-generators in Phase 2
# This will create NixOS ISO images that can be used as VM templates

# VM readiness will be verified manually or via separate tooling
