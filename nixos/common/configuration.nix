# Common NixOS configuration for Kubernetes infrastructure
{ config, pkgs, ... }:

{
  imports = [ ];

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.kernelParams = [ "cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory" ];

  # Network configuration
  networking = {
    hostName = "nixos-k8s";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 6443 2379 2380 10250 10251 10252 ];
      allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
    };
  };

  # System packages
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
  ];

  # Container runtime
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

  # Kubernetes prerequisites
  services.kubernetes = {
    roles = [ ];  # Will be overridden in specific configs
    package = pkgs.kubernetes;
    clusterCidr = "10.244.0.0/16";
    serviceCidr = "10.96.0.0/12";
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Cloud-init support
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      # SSH keys will be managed by cloud-init
    ];
  };
  
  # Ansible user for automation
  users.users.ansible = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    description = "Ansible automation user";
    openssh.authorizedKeys.keys = [
      # SSH keys will be managed by cloud-init
    ];
  };

  # Sudo configuration
  security.sudo.wheelNeedsPassword = false;

  # System configuration
  system.stateVersion = "23.11";
  
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

  # Disable swap (required for Kubernetes)
  swapDevices = [ ];
}
