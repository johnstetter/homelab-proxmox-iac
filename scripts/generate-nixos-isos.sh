#!/usr/bin/env bash

# generate-nixos-isos.sh
# Generates NixOS ISOs using nixos-generators with cloud-init support

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NIXOS_DIR="$PROJECT_ROOT/nixos"
BUILD_DIR="$PROJECT_ROOT/build"
ISO_DIR="$BUILD_DIR/isos"
LOG_DIR="$BUILD_DIR/logs"

# Default values
NODE_TYPE=""
ENVIRONMENT=""
OUTPUT_DIR="$ISO_DIR"
NIXOS_VERSION="23.11"
CLEAN_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_DIR/iso-generation.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_DIR/iso-generation.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_DIR/iso-generation.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_DIR/iso-generation.log"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate NixOS ISOs using nixos-generators with cloud-init support.

OPTIONS:
    --type TYPE         Node type (control|worker|all)
    --env ENV           Environment (dev|prod|all)
    --output-dir DIR    Output directory for ISOs (default: $ISO_DIR)
    --nixos-version VER NixOS version (default: $NIXOS_VERSION)
    --clean             Clean build directory before generation
    --help              Show this help message

EXAMPLES:
    $0                                    # Generate all ISOs
    $0 --type control --env dev          # Generate dev control plane ISO
    $0 --type worker --env prod          # Generate prod worker ISO
    $0 --clean --output-dir /tmp/isos    # Clean build and custom output

REQUIREMENTS:
    - Nix package manager must be installed
    - NixOS configurations must exist in $NIXOS_DIR

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                NODE_TYPE="$2"
                shift 2
                ;;
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --nixos-version)
                NIXOS_VERSION="$2"
                shift 2
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
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

    # Validate node type
    if [[ -n "$NODE_TYPE" && "$NODE_TYPE" != "control" && "$NODE_TYPE" != "worker" && "$NODE_TYPE" != "all" ]]; then
        log_error "Invalid node type: $NODE_TYPE. Must be 'control', 'worker', or 'all'"
        exit 1
    fi

    # Validate environment
    if [[ -n "$ENVIRONMENT" && "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "all" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'dev', 'prod', or 'all'"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Nix is available
    if ! command -v nix &> /dev/null; then
        log_error "Nix package manager is not installed. Please install it first:"
        log_error "  curl -L https://nixos.org/nix/install | sh"
        log_error "  source ~/.nix-profile/etc/profile.d/nix.sh"
        exit 1
    fi

    # Check if NixOS configurations exist
    if [[ ! -d "$NIXOS_DIR" ]]; then
        log_error "NixOS configuration directory not found: $NIXOS_DIR"
        log_error "Run ./scripts/populate-nixos-configs.sh first"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Setup build environment
setup_build_env() {
    log_info "Setting up build environment..."

    # Clean build directory if requested
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        log_info "Cleaning build directory..."
        rm -rf "$BUILD_DIR"
    fi

    # Create directories
    mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

    # Initialize log file
    echo "=== NixOS ISO Generation Log - $(date) ===" > "$LOG_DIR/iso-generation.log"

    log_success "Build environment ready"
}

# Create ISO configuration
create_iso_config() {
    local node_type="$1"
    local env="$2"
    local config_file="$BUILD_DIR/iso-config-$env-$node_type.nix"

    log_info "Creating ISO configuration for $env $node_type..."

    cat > "$config_file" << EOF
# NixOS ISO configuration for $env $node_type
{ config, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    $NIXOS_DIR/$env/$node_type.nix
  ];

  # ISO-specific configuration
  isoImage = {
    isoName = "nixos-k8s-$node_type-$env-\${config.system.nixos.label}-\${pkgs.stdenv.hostPlatform.system}.iso";
    volumeID = "NIXOS_K8S_\${pkgs.lib.toUpper "$env"}_\${pkgs.lib.toUpper "$node_type"}";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # Cloud-init configuration for automated deployment
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [ "NoCloud" "ConfigDrive" "OpenStack" "Ec2" ];
      cloud_init_modules = [
        "migrator"
        "seed_random"
        "bootcmd"
        "write-files"
        "growpart"
        "resizefs"
        "disk_setup"
        "mounts"
        "set_hostname"
        "update_hostname"
        "update_etc_hosts"
        "ca-certs"
        "rsyslog"
        "users-groups"
        "ssh"
      ];
      cloud_config_modules = [
        "emit_upstart"
        "snap"
        "ssh-import-id"
        "locale"
        "set-passwords"
        "grub-dpkg"
        "apt-pipelining"
        "apt-configure"
        "ubuntu-advantage"
        "ntp"
        "timezone"
        "disable-ec2-metadata"
        "runcmd"
        "byobu"
      ];
      cloud_final_modules = [
        "package-update-upgrade-install"
        "fan"
        "landscape"
        "lxd"
        "ubuntu-drivers"
        "puppet"
        "chef"
        "mcollective"
        "salt-minion"
        "rightscale_userdata"
        "scripts-vendor"
        "scripts-per-once"
        "scripts-per-boot"
        "scripts-per-instance"
        "scripts-user"
        "ssh-authkey-fingerprints"
        "keys-to-console"
        "phone-home"
        "final-message"
        "power-state-change"
      ];
    };
  };

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Networking configuration
  networking = {
    useDHCP = true;
    firewall.enable = false; # Will be configured by cloud-init
  };

  # Additional packages for ISO
  environment.systemPackages = with pkgs; [
    cloud-init
    cloud-utils
    parted
    gptfdisk
    dosfstools
  ];

  # Auto-login for installation
  services.getty.autologinUser = "nixos";

  # System configuration
  system.stateVersion = "$NIXOS_VERSION";
}
EOF

    echo "$config_file"
}

# Generate ISO
generate_iso() {
    local node_type="$1"
    local env="$2"
    local iso_name="nixos-k8s-$node_type-$env.iso"
    local iso_path="$OUTPUT_DIR/$iso_name"

    log_info "Generating ISO: $iso_name"

    # Create ISO configuration
    local config_file
    config_file=$(create_iso_config "$node_type" "$env")

    # Generate ISO using nixos-generators via nix run
    log_info "Running nixos-generators via nix run..."
    if NIX_PATH="nixos-config=$config_file:nixpkgs=channel:nixos-unstable" nix --extra-experimental-features 'nix-command flakes' run 'github:nix-community/nixos-generators' -- -f iso -o "$iso_path" 2>&1 | tee -a "$LOG_DIR/iso-generation.log"; then
        log_success "Generated ISO: $iso_path"
        
        # Get ISO size
        local iso_size
        iso_size=$(du -h "$iso_path" | cut -f1)
        log_info "ISO size: $iso_size"
        
        return 0
    else
        log_error "Failed to generate ISO: $iso_name"
        return 1
    fi
}

# Generate ISOs based on parameters
generate_isos() {
    local types=()
    local envs=()
    local failed_count=0
    local success_count=0

    # Determine which types to build
    if [[ -z "$NODE_TYPE" || "$NODE_TYPE" == "all" ]]; then
        types=("control" "worker")
    else
        types=("$NODE_TYPE")
    fi

    # Determine which environments to build
    if [[ -z "$ENVIRONMENT" || "$ENVIRONMENT" == "all" ]]; then
        envs=("dev" "prod")
    else
        envs=("$ENVIRONMENT")
    fi

    log_info "Building ISOs for types: ${types[*]}, environments: ${envs[*]}"

    # Generate ISOs
    for env in "${envs[@]}"; do
        for type in "${types[@]}"; do
            # Check if configuration exists
            local config_file="$NIXOS_DIR/$env/$type.nix"
            if [[ ! -f "$config_file" ]]; then
                log_warning "Configuration not found: $config_file, skipping..."
                continue
            fi

            if generate_iso "$type" "$env"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        done
    done

    # Summary
    log_info "ISO generation summary:"
    log_info "  Successful: $success_count"
    log_info "  Failed: $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        log_error "Some ISOs failed to generate. Check logs for details."
        return 1
    fi

    return 0
}

# Main execution
main() {
    log_info "Starting NixOS ISO generation..."

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Setup build environment
    setup_build_env

    # Generate ISOs
    if generate_isos; then
        log_success "All ISOs generated successfully!"
        log_info "ISOs are available in: $OUTPUT_DIR"
        log_info "Next steps:"
        log_info "  1. Upload ISOs to Proxmox storage"
        log_info "  2. Run ./scripts/create-proxmox-templates.sh"
    else
        log_error "ISO generation failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"