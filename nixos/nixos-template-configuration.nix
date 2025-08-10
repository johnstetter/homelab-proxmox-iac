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

  # Set state version (use 25.05 for current stable)
  system.stateVersion = "25.05";
}