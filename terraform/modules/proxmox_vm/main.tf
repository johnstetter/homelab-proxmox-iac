# Proxmox VM Resource
resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.template
  
  # VM Configuration
  cores    = var.cores
  memory   = var.memory
  onboot   = var.onboot
  agent    = var.agent
  balloon  = var.balloon
  boot     = var.boot
  bootdisk = var.bootdisk
  scsihw   = var.scsihw
  os_type  = var.os_type
  
  # Disk Configuration
  disk {
    slot     = 0
    type     = "scsi"
    storage  = var.disk_storage
    size     = var.disk_size
    format   = "raw"
    cache    = "writeback"
    backup   = true
    replicate = true
  }
  
  # Network Configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.network_vlan
  }
  
  # Cloud-init Configuration
  ciuser     = var.ssh_user
  cipassword = ""
  sshkeys    = var.ssh_public_key
  
  # IP Configuration
  ipconfig0 = "ip=${var.ip_address},gw=${var.gateway}"
  nameserver = var.nameserver
  
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
  
  # Wait for cloud-init to complete
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file("${path.root}/ssh_keys/k8s_private_key.pem")
    host        = split("/", var.ip_address)[0]
    timeout     = "5m"
  }
  
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "echo 'Cloud-init completed successfully'"
    ]
  }
}

# NixOS configuration will be handled by nixos-generators in Phase 2
# This will create NixOS ISO images that can be used as VM templates

# Wait for VM to be ready
resource "null_resource" "wait_for_vm" {
  depends_on = [proxmox_vm_qemu.vm]
  
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file("${path.root}/ssh_keys/k8s_private_key.pem")
    host        = split("/", var.ip_address)[0]
    timeout     = "10m"
  }
  
  provisioner "remote-exec" {
    inline = [
      "echo 'VM is ready and accessible via SSH'",
      "sudo systemctl is-active --quiet cloud-init && echo 'Cloud-init is active' || echo 'Cloud-init not found'",
      "uptime"
    ]
  }
}
