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

  # Create build info file with commit SHA
  environment.etc."nixos-build-info" = {
    text = ''
      BUILD_TIMESTAMP=${builtins.toString builtins.currentTime}
      COMMIT_SHA=${builtins.getEnv "NIX_BUILD_COMMIT_SHA"}
      BUILD_DATE=${builtins.readFile "${pkgs.runCommand "build-date" {} "date '+%Y-%m-%d %H:%M:%S UTC' > $out"}"}
    '';
    mode = "0644";
  };

  # Create automated installation script
  environment.etc."nixos-auto-install.sh" = {
    text = ''
set -euo pipefail

echo "Starting automated NixOS installation..."

# Wait a bit for system to fully initialize
sleep 10

# Verify we're in a live environment
if [[ -f /run/current-system ]]; then
  echo "Already installed system detected, aborting auto-install"
  exit 0
fi

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

      # Create roles directory and copy role configurations
      mkdir -p /mnt/etc/nixos/roles
      cp /etc/nixos/roles/*.nix /mnt/etc/nixos/roles/ 2>/dev/null || true
      
      
      # Copy build info to installed system
      cp /etc/nixos-build-info /mnt/etc/nixos-build-info

      # Install NixOS
      nixos-install --no-root-passwd --root /mnt

      echo "Installation complete! Shutting down..."
      poweroff
    '';
    mode = "0755";
  };

  # Copy role configurations to ISO for installation
  environment.etc."nixos/roles/control-plane.nix".source = ./roles/control-plane.nix;
  environment.etc."nixos/roles/worker.nix".source = ./roles/worker.nix;

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

        # Enable cloud-init for VM customization and role assignment
        services.cloud-init = {
          enable = true;
          network.enable = true;
        };

        # User configuration - ensure nixos user has sudo access
        users.users.nixos = {
          isNormalUser = true;
          extraGroups = [ "wheel" "docker" ];
        };
        
        # Enable sudo for wheel group without password
        security.sudo = {
          enable = true;
          wheelNeedsPassword = false;
        };

        # System packages - including Kubernetes prerequisites
        environment.systemPackages = with pkgs; [
          vim
          git
          curl
          wget
          htop
          jq
          yq
          kubectl
          docker
          containerd
          cri-tools
          ethtool
          socat
          conntrack-tools
          ipset
          iptables
          python3
          python3Packages.pip
          tree
          rsync
          dig
        ];

        # Container runtime configuration
        virtualisation = {
          docker = {
            enable = true;
            daemon.settings = {
              exec-opts = [ "native.cgroupdriver=systemd" ];
              log-driver = "json-file";
              log-opts = {
                max-size = "100m";
              };
              storage-driver = "overlay2";
            };
          };
          containerd = {
            enable = true;
            settings = {
              plugins."io.containerd.grpc.v1.cri" = {
                systemd_cgroup = true;
                sandbox_image = "registry.k8s.io/pause:3.9";
              };
            };
          };
        };

        # Kernel modules for Kubernetes
        boot.kernelModules = [ "br_netfilter" "overlay" "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" ];
        
        # Sysctl settings for Kubernetes
        boot.kernel.sysctl = {
          "net.bridge.bridge-nf-call-iptables" = 1;
          "net.bridge.bridge-nf-call-ip6tables" = 1;
          "net.ipv4.ip_forward" = 1;
          "net.ipv4.conf.all.forwarding" = 1;
          "net.ipv6.conf.all.forwarding" = 1;
        };

        # Kubernetes kernel parameters
        boot.kernelParams = [ "cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory" ];

        # Firewall configuration for Kubernetes
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [ 22 80 443 6443 2379 2380 10250 10251 10252 ];
          allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
        };

        # Note: nixos user groups configured in installed template

        # Disable swap (required for Kubernetes)
        swapDevices = [ ];

        # TODO: Add role assignment script later

        # Set state version (use 24.11 for current stable)
        system.stateVersion = "24.11";
      }
    '';
  };

  # Auto-installation service - ENABLED for testing
  systemd.services.nixos-auto-install = {
    description = "Automated NixOS Installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos-auto-install.sh";
      StandardOutput = "journal";
      StandardError = "journal";
      RemainAfterExit = true;
    };
    # Only run if we're booted from ISO (not an installed system)
    unitConfig = {
      ConditionPathExists = "!/etc/nixos/hardware-configuration.nix";
      ConditionPathExists = "/etc/nixos-auto-install.sh";
    };
  };

  # Set state version for the ISO  
  system.stateVersion = "24.11";
}