#!/usr/bin/env bash

# populate-nixos-configs.sh
# Populates NixOS configuration files with Kubernetes components

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NIXOS_DIR="$PROJECT_ROOT/nixos"

# Default values
FORCE=false
TARGET_ENV=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Populate NixOS configuration files with Kubernetes components.

OPTIONS:
    --force         Overwrite existing configurations
    --env ENV       Target specific environment (dev|prod|all)
    --help          Show this help message

EXAMPLES:
    $0                          # Populate all configurations
    $0 --env dev               # Populate only dev configurations
    $0 --force --env prod      # Force overwrite prod configurations

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --env)
                TARGET_ENV="$2"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate environment
    if [[ -n "$TARGET_ENV" && "$TARGET_ENV" != "dev" && "$TARGET_ENV" != "prod" && "$TARGET_ENV" != "all" ]]; then
        log_error "Invalid environment: $TARGET_ENV. Must be 'dev', 'prod', or 'all'"
        exit 1
    fi
}

# Check if file should be overwritten
should_overwrite() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 0  # File doesn't exist, safe to create
    fi
    
    if [[ "$FORCE" == "true" ]]; then
        return 0  # Force flag set, overwrite
    fi
    
    # Check if file is just a placeholder
    if grep -q "^# .*config$" "$file" && [[ $(wc -l < "$file") -eq 1 ]]; then
        return 0  # Just a placeholder comment, safe to overwrite
    fi
    
    return 1  # File exists and has content, don't overwrite
}

# Create common NixOS configuration
create_common_config() {
    local config_file="$NIXOS_DIR/common/configuration.nix"
    
    if ! should_overwrite "$config_file"; then
        log_warning "Skipping $config_file (already exists, use --force to overwrite)"
        return
    fi
    
    log_info "Creating common NixOS configuration..."
    
    cat > "$config_file" << 'EOF'
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
EOF

    log_success "Created common configuration: $config_file"
}

# Create control plane configuration
create_control_config() {
    local env="$1"
    local config_file="$NIXOS_DIR/$env/control.nix"
    
    if ! should_overwrite "$config_file"; then
        log_warning "Skipping $config_file (already exists, use --force to overwrite)"
        return
    fi
    
    log_info "Creating $env control plane configuration..."
    
    cat > "$config_file" << EOF
# $env environment control plane configuration
{ config, pkgs, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Hostname override
  networking.hostName = "k8s-$env-control";

  # Kubernetes control plane configuration
  services.kubernetes = {
    roles = [ "master" ];
    masterAddress = "k8s-$env-control";
    
    # API Server configuration
    apiserver = {
      enable = true;
      advertiseAddress = "0.0.0.0";
      allowPrivileged = true;
      authorizationMode = [ "RBAC" "Node" ];
      enable = true;
      etcd = {
        servers = [ "https://127.0.0.1:2379" ];
        caFile = "/var/lib/kubernetes/ca.pem";
        certFile = "/var/lib/kubernetes/kubernetes.pem";
        keyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      };
      serviceClusterIpRange = "10.96.0.0/12";
      securePort = 6443;
      tlsCertFile = "/var/lib/kubernetes/kubernetes.pem";
      tlsPrivateKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      clientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeletClientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeletClientCertFile = "/var/lib/kubernetes/kubernetes.pem";
      kubeletClientKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      serviceAccountKeyFile = "/var/lib/kubernetes/service-account.pem";
      serviceAccountSigningKeyFile = "/var/lib/kubernetes/service-account-key.pem";
    };

    # Controller Manager configuration
    controllerManager = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      serviceCidr = "10.96.0.0/12";
      tlsCertFile = "/var/lib/kubernetes/kube-controller-manager.pem";
      tlsPrivateKeyFile = "/var/lib/kubernetes/kube-controller-manager-key.pem";
      serviceAccountPrivateKeyFile = "/var/lib/kubernetes/service-account-key.pem";
      rootCaFile = "/var/lib/kubernetes/ca.pem";
    };

    # Scheduler configuration
    scheduler = {
      enable = true;
      bindAddress = "0.0.0.0";
    };

    # Etcd configuration
    etcd = {
      enable = true;
      listenClientUrls = [ "https://127.0.0.1:2379" ];
      listenPeerUrls = [ "https://127.0.0.1:2380" ];
      advertiseClientUrls = [ "https://127.0.0.1:2379" ];
      initialAdvertisePeerUrls = [ "https://127.0.0.1:2380" ];
      initialCluster = [ "k8s-$env-control=https://127.0.0.1:2380" ];
      dataDir = "/var/lib/etcd";
      certFile = "/var/lib/kubernetes/kubernetes.pem";
      keyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      trustedCaFile = "/var/lib/kubernetes/ca.pem";
      peerCertFile = "/var/lib/kubernetes/kubernetes.pem";
      peerKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      peerTrustedCaFile = "/var/lib/kubernetes/ca.pem";
    };

    # Kubelet configuration
    kubelet = {
      enable = true;
      registerNode = true;
      address = "0.0.0.0";
      port = 10250;
      clusterDns = "10.96.0.10";
      clusterDomain = "cluster.local";
      networkPlugin = "cni";
      cniConfDir = "/etc/cni/net.d";
      cniBinDir = "/opt/cni/bin";
      tlsCertFile = "/var/lib/kubelet/kubelet.pem";
      tlsPrivateKeyFile = "/var/lib/kubelet/kubelet-key.pem";
      clientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeconfig = "/var/lib/kubelet/kubeconfig";
    };

    # Kube-proxy configuration
    proxy = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      kubeconfig = "/var/lib/kube-proxy/kubeconfig";
    };
  };

  # Additional firewall rules for control plane
  networking.firewall.allowedTCPPorts = [ 
    6443   # Kubernetes API server
    2379   # etcd client requests
    2380   # etcd peer communication
    10250  # Kubelet API
    10251  # kube-scheduler
    10252  # kube-controller-manager
  ];

  # CNI plugins
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
  ];

  # Environment-specific settings
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    K8S_ENV = "$env";
  };
}
EOF

    log_success "Created $env control plane configuration: $config_file"
}

# Create worker configuration
create_worker_config() {
    local env="$1"
    local config_file="$NIXOS_DIR/$env/worker.nix"
    
    if ! should_overwrite "$config_file"; then
        log_warning "Skipping $config_file (already exists, use --force to overwrite)"
        return
    fi
    
    log_info "Creating $env worker configuration..."
    
    cat > "$config_file" << EOF
# $env environment worker node configuration
{ config, pkgs, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Hostname override
  networking.hostName = "k8s-$env-worker";

  # Kubernetes worker node configuration
  services.kubernetes = {
    roles = [ "node" ];
    masterAddress = "k8s-$env-control";

    # Kubelet configuration
    kubelet = {
      enable = true;
      registerNode = true;
      address = "0.0.0.0";
      port = 10250;
      clusterDns = "10.96.0.10";
      clusterDomain = "cluster.local";
      networkPlugin = "cni";
      cniConfDir = "/etc/cni/net.d";
      cniBinDir = "/opt/cni/bin";
      tlsCertFile = "/var/lib/kubelet/kubelet.pem";
      tlsPrivateKeyFile = "/var/lib/kubelet/kubelet-key.pem";
      clientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeconfig = "/var/lib/kubelet/kubeconfig";
      
      # Worker-specific settings
      maxPods = 110;
      containerRuntime = "containerd";
      containerRuntimeEndpoint = "unix:///run/containerd/containerd.sock";
    };

    # Kube-proxy configuration
    proxy = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      kubeconfig = "/var/lib/kube-proxy/kubeconfig";
    };
  };

  # Worker node firewall rules
  networking.firewall.allowedTCPPorts = [ 
    10250  # Kubelet API
    30000  # NodePort services start
    32767  # NodePort services end
  ];

  networking.firewall.allowedTCPPortRanges = [
    { from = 30000; to = 32767; }  # NodePort services
  ];

  # CNI plugins
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
  ];

  # Environment-specific settings
  environment.variables = {
    K8S_ENV = "$env";
    NODE_ROLE = "worker";
  };

  # Additional worker node optimizations
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 524288;
  };
}
EOF

    log_success "Created $env worker configuration: $config_file"
}

# Main execution
main() {
    log_info "Starting NixOS configuration population..."
    
    # Parse arguments
    parse_args "$@"
    
    # Create directories if they don't exist
    mkdir -p "$NIXOS_DIR"/{common,dev,prod}
    
    # Create common configuration
    create_common_config
    
    # Create environment-specific configurations
    if [[ -z "$TARGET_ENV" || "$TARGET_ENV" == "all" || "$TARGET_ENV" == "dev" ]]; then
        create_control_config "dev"
        create_worker_config "dev"
    fi
    
    if [[ -z "$TARGET_ENV" || "$TARGET_ENV" == "all" || "$TARGET_ENV" == "prod" ]]; then
        create_control_config "prod"
        create_worker_config "prod"
    fi
    
    log_success "NixOS configuration population completed!"
    log_info "Next steps:"
    log_info "  1. Review and customize the generated configurations"
    log_info "  2. Run ./scripts/generate-nixos-isos.sh to create ISOs"
    log_info "  3. Run ./scripts/create-proxmox-templates.sh to create VM templates"
}

# Run main function with all arguments
main "$@"
