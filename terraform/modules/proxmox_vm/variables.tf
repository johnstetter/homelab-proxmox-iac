# VM Configuration
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "target_node" {
  description = "Proxmox node where the VM will be created"
  type        = string
}

variable "proxmox_host" {
  description = "Proxmox host IP for SSH commands"
  type        = string
}

variable "template" {
  description = "Template to clone from"
  type        = string
}

variable "full_clone" {
  description = "Create a full clone instead of linked clone"
  type        = bool
  default     = true
}

# Resource Configuration
variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size (e.g., '20G')"
  type        = string
  default     = "20G"
}

variable "disk_storage" {
  description = "Storage pool for the disk"
  type        = string
  default     = "local-lvm"
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_vlan" {
  description = "VLAN tag (optional)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IP address with CIDR (e.g., '192.168.1.10/24')"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "8.8.8.8"
}

# SSH Configuration
variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}

# NixOS Configuration
variable "nixos_config_path" {
  description = "Path to NixOS configuration file"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags for the VM"
  type        = string
  default     = ""
}

# Optional Configuration
variable "onboot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "agent" {
  description = "Enable QEMU guest agent"
  type        = number
  default     = 1
}

variable "balloon" {
  description = "Balloon memory in MB"
  type        = number
  default     = 0
}

variable "boot" {
  description = "Boot order"
  type        = string
  default     = "c"
}

variable "bootdisk" {
  description = "Boot disk"
  type        = string
  default     = "scsi0"
}

variable "scsihw" {
  description = "SCSI hardware type"
  type        = string
  default     = "virtio-scsi-pci"
}

variable "os_type" {
  description = "Operating system type"
  type        = string
  default     = "cloud-init"
}
