# Automated NixOS template with installation script
# This creates an ISO that can automatically install itself

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Add installation tools
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    parted
    gptfdisk
    lvm2
  ];

  # Create automated installation script
  environment.etc."nixos-auto-install.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      echo "Starting automated NixOS installation..."

      # Partition disk with LVM (MBR for BIOS boot)
      # Clear any existing partition table first
      dd if=/dev/zero of=/dev/sda bs=1M count=1
      
      # Create MBR partition table with fdisk
      fdisk /dev/sda << EOF
o
n
p
1

+512M
a
n
p
2


t
2
8e
w
EOF

      # Set up LVM
      pvcreate /dev/sda2
      vgcreate nixos-vg /dev/sda2
      lvcreate -L 4G -n swap nixos-vg
      lvcreate -l 100%FREE -n root nixos-vg

      # Format filesystems
      mkfs.ext4 -L boot /dev/sda1
      mkfs.ext4 -L nixos /dev/nixos-vg/root
      mkswap -L swap /dev/nixos-vg/swap

      # Mount filesystems
      mount /dev/nixos-vg/root /mnt
      swapon /dev/nixos-vg/swap
      mkdir -p /mnt/boot
      mount /dev/sda1 /mnt/boot

      # Generate hardware config
      nixos-generate-config --root /mnt

      # Copy our pre-made configuration
      cp /etc/nixos/template-configuration.nix /mnt/etc/nixos/configuration.nix

      # Install NixOS
      nixos-install --no-root-passwd --root /mnt

      echo "Installation complete! Shutting down..."
      poweroff
    '';
    mode = "0755";
  };

  # Pre-made configuration that gets copied during installation
  environment.etc."nixos/template-configuration.nix" = {
    text = ''
      { config, lib, pkgs, ... }:

      {
        imports = [
          ./hardware-configuration.nix
        ];

        # Boot loader configuration for BIOS (force BIOS mode)
        boot.loader.grub.enable = true;
        boot.loader.grub.device = "/dev/sda";
        boot.loader.grub.efiSupport = false;
        boot.loader.efi.canTouchEfiVariables = false;

        # Network configuration - let cloud-init handle networking
        networking.useDHCP = false;
        networking.networkmanager.enable = false;
        networking.useNetworkd = true;

        # Set timezone
        time.timeZone = "America/Chicago";

        # SSH configuration
        services.openssh.enable = true;
        services.openssh.settings.PermitRootLogin = "yes";

        # Enable QEMU guest agent for Proxmox
        services.qemuGuest.enable = true;

        # Enable cloud-init for VM customization
        services.cloud-init.enable = true;

        # User configuration - ensure nixos user has sudo access
        users.users.nixos = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
        };
        
        # Enable sudo for wheel group without password
        security.sudo = {
          enable = true;
          wheelNeedsPassword = false;
        };

        # System packages
        environment.systemPackages = with pkgs; [
          vim
          git
          curl
          wget
        ];

        # Set state version (use 24.11 for current stable)
        system.stateVersion = "24.11";
      }
    '';
  };

  # Set state version for the ISO  
  system.stateVersion = "24.11";
}