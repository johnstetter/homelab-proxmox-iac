# Base NixOS template configuration for VM templates
# This gets baked into the ISO and provides the default configuration.nix

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Boot loader configuration for EFI (will be used after installation)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking.useDHCP = true;
  networking.networkmanager.enable = false;

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
    parted  # Add parted for easier partitioning
  ];

  # Pre-seed the installation configuration
  # This creates a default configuration.nix that will be used during installation
  system.extraSystemBuilderCmds = ''
    mkdir -p $out/etc/nixos
    cat > $out/etc/nixos/configuration.nix << 'EOF'
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
  networking.networkmanager.enable = false;

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

  # Set state version
  system.stateVersion = "24.11";
}
EOF
  '';

  # Set state version for the ISO
  system.stateVersion = "24.11";
}