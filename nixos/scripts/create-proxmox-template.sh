#!/usr/bin/env bash

# create-proxmox-template.sh
# Creates a single base NixOS template for Proxmox VMs

set -euo pipefail

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../shared/lib/paths.sh
source "$(dirname "$(dirname "$SCRIPT_DIR")")/shared/lib/paths.sh"

# Override defaults with script-specific values
TEMPLATE_ID_BASE="${TEMPLATE_ID_BASE:-9100}"
TEMPLATE_NAME="${NIXOS_TEMPLATE_NAME:-nixos-base-template}"
ISO_NAME="${ISO_NAME:-nixos-base-template.iso}"
DRY_RUN="${DRY_RUN:-false}"

# Use shared paths
BUILD_DIR="$K8S_INFRA_BUILD_DIR"
ISO_DIR="$K8S_INFRA_ISO_DIR"
LOG_DIR="$K8S_INFRA_LOG_DIR"
TEMPLATES_DIR="$K8S_INFRA_TEMPLATES_DIR"

# Additional colors (others defined in shared config)
BLUE='\033[0;34m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_DIR/template-creation.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_DIR/template-creation.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_DIR/template-creation.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_DIR/template-creation.log"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automate Proxmox template creation from generated NixOS ISOs.

OPTIONS:
    --proxmox-host HOST     Proxmox server hostname/IP (required)
    --proxmox-user USER     Proxmox username (default: $PROXMOX_USER)
    --proxmox-node NODE     Proxmox node name (default: auto-detect)
    --storage STORAGE       Storage pool for VM disks (default: $STORAGE_POOL)
    --iso-storage STORAGE   Storage for ISO files (default: $ISO_STORAGE)
    --template-id ID        Base VM ID for templates (default: $TEMPLATE_ID_BASE, auto-increments)
    --dry-run               Show what would be done without executing
    --help                  Show this help message

EXAMPLES:
    $0 --proxmox-host 192.168.1.100
    $0 --proxmox-host pve.local --storage local-lvm
    $0 --proxmox-host 10.0.0.10 --dry-run

REQUIREMENTS:
    - SSH access to Proxmox server
    - Generated NixOS ISOs in $ISO_DIR
    - Sufficient privileges to create VMs and templates

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --proxmox-host)
                PROXMOX_HOST="$2"
                shift 2
                ;;
            --proxmox-user)
                PROXMOX_USER="$2"
                shift 2
                ;;
            --proxmox-node)
                PROXMOX_NODE="$2"
                shift 2
                ;;
            --storage)
                STORAGE_POOL="$2"
                shift 2
                ;;
            --iso-storage)
                ISO_STORAGE="$2"
                shift 2
                ;;
            --template-id)
                TEMPLATE_ID_BASE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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

    # Validate required parameters
    if [[ -z "$PROXMOX_HOST" ]]; then
        log_error "Proxmox host is required. Use --proxmox-host option."
        usage
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if base template ISO exists
    if [[ ! -f "$ISO_DIR/$ISO_NAME" ]]; then
        log_error "Base template ISO not found: $ISO_DIR/$ISO_NAME"
        log_error "Run nixos-generate -f iso -c ./nixos/base-template.nix -o $ISO_DIR/$ISO_NAME first"
        exit 1
    fi

    # Check SSH connectivity to Proxmox
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH connection test'" &>/dev/null; then
        log_error "Cannot connect to Proxmox server via SSH: $PROXMOX_USER@$PROXMOX_HOST"
        log_error "Please ensure:"
        log_error "  1. SSH key authentication is set up"
        log_error "  2. Proxmox server is accessible"
        log_error "  3. User has sufficient privileges"
        exit 1
    fi

    # Auto-detect Proxmox node if not specified
    if [[ -z "$PROXMOX_NODE" ]]; then
        log_info "Auto-detecting Proxmox node..."
        PROXMOX_NODE=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "hostname")
        log_info "Detected Proxmox node: $PROXMOX_NODE"
    fi

    log_success "Prerequisites check passed"
}

# Setup build environment
setup_build_env() {
    log_info "Setting up build environment..."

    # Create directories
    mkdir -p "$LOG_DIR" "$TEMPLATES_DIR"

    # Initialize log file
    echo "=== Proxmox Template Creation Log - $(date) ===" > "$LOG_DIR/template-creation.log"

    log_success "Build environment ready"
}

# Find next available template ID
find_available_template_id() {
    local start_id="$1"
    local current_id="$start_id"
    
    log_info "Finding available template ID starting from $start_id..." >&2
    
    while ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $current_id" &>/dev/null; do
        log_info "Template ID $current_id is in use, trying next..." >&2
        ((current_id++))
        
        # Safety limit to prevent infinite loop
        if ((current_id > start_id + 100)); then
            log_error "Could not find available template ID after checking 100 IDs" >&2
            return 1
        fi
    done
    
    log_info "Found available template ID: $current_id" >&2
    echo "$current_id"
    return 0
}

# Execute Proxmox command
execute_proxmox_cmd() {
    local cmd="$1"
    local description="$2"

    log_info "$description"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $cmd"
        return 0
    fi

    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "$cmd" 2>&1 | tee -a "$LOG_DIR/template-creation.log"; then
        log_success "$description completed"
        return 0
    else
        log_error "$description failed"
        return 1
    fi
}

# Clean up old ISOs on Proxmox (keep 3 most recent)
cleanup_old_isos() {
    local iso_pattern="nixos-base-template*.iso"
    
    log_info "Cleaning up old ISOs (keeping 3 most recent)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would clean up old ISOs matching: $iso_pattern"
        return 0
    fi
    
    # List ISOs sorted by modification time (newest first), skip first 3, remove the rest
    local cleanup_cmd="cd /var/lib/vz/template/iso && ls -t $iso_pattern 2>/dev/null | tail -n +4 | xargs -r rm -f"
    
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "$cleanup_cmd"; then
        # Show what we kept
        local kept_isos
        kept_isos=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "cd /var/lib/vz/template/iso && ls -t $iso_pattern 2>/dev/null | head -3" || echo "None")
        log_info "Kept most recent ISOs: $kept_isos"
        log_success "Old ISO cleanup completed"
    else
        log_warning "ISO cleanup completed (no old ISOs to remove)"
    fi
    
    return 0
}

# Upload ISO to Proxmox
upload_iso() {
    local iso_file="$1"
    local iso_name
    iso_name=$(basename "$iso_file")

    log_info "Uploading ISO: $iso_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would upload: $iso_file to $PROXMOX_HOST:$ISO_STORAGE"
        return 0
    fi

    # Clean up old ISOs first (keep 3 most recent)
    cleanup_old_isos

    # Upload ISO (resolve symlinks and find actual ISO file)
    local real_iso_file
    real_iso_file=$(readlink -f "$iso_file")
    
    # If the resolved path is a directory, find the ISO file inside it
    if [[ -d "$real_iso_file" ]]; then
        real_iso_file=$(find "$real_iso_file" -name "*.iso" -type f | head -1)
    fi
    
    if [[ ! -f "$real_iso_file" ]]; then
        log_error "Could not find actual ISO file for: $iso_name"
        return 1
    fi
    
    if scp "$real_iso_file" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/template/iso/$iso_name"; then
        log_success "Uploaded ISO: $iso_name"
        return 0
    else
        log_error "Failed to upload ISO: $iso_name"
        return 1
    fi
}

# Create VM template
create_template() {
    local iso_file="$1"
    local vm_id="$2"
    local iso_name
    local template_name

    iso_name=$(basename "$iso_file")
    template_name="$TEMPLATE_NAME"

    log_info "Creating template: $template_name (VM ID: $vm_id)"

    # Upload ISO first
    if ! upload_iso "$iso_file"; then
        return 1
    fi

    # Create VM with proper display configuration and BIOS boot
    local create_cmd="qm create $vm_id --name $template_name --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --ostype l26 --vga qxl --bios seabios"
    if ! execute_proxmox_cmd "$create_cmd" "Creating VM $vm_id"; then
        return 1
    fi

    # Create 20GB disk for installation target (same as VM requirements)  
    local create_disk_cmd="qm set $vm_id --scsi0 $STORAGE_POOL:20"
    if ! execute_proxmox_cmd "$create_disk_cmd" "Creating 20GB target disk for VM $vm_id"; then
        return 1
    fi

    # Configure VM with ISO in CD drive and proper boot order
    local config_cmds=(
        "qm set $vm_id --ide0 $ISO_STORAGE:iso/$iso_name,media=cdrom"
        "qm set $vm_id --boot order=ide0\\;scsi0"
        "qm set $vm_id --ide2 $STORAGE_POOL:cloudinit"
        "qm set $vm_id --agent enabled=1"
        "qm set $vm_id --ciuser nixos"
        "qm set $vm_id --sshkey /root/.ssh/authorized_keys"
        "qm set $vm_id --ostype l26"
        "qm set $vm_id --args '-device virtio-rng-pci'"
    )

    for cmd in "${config_cmds[@]}"; do
        if ! execute_proxmox_cmd "$cmd" "Configuring VM $vm_id"; then
            return 1
        fi
    done

    # VM ready for automated installation
    log_info "VM $vm_id created and configured for automated NixOS installation"
    log_info ""
    log_info "Automated installation process includes:"
    log_info "  - systemd service automatically runs /etc/nixos-auto-install.sh on boot"
    log_info "  - LVM partitioning for disk resize capabilities"
    log_info "  - NixOS installation with GRUB bootloader (BIOS compatible)"
    log_info "  - Cloud-init, SSH, and Kubernetes-ready configuration"
    log_info "  - Automatic shutdown when installation completes"
    log_info ""
    
    # Don't convert to template - leave as VM for manual work
    return 0
}

# Create VM and wait for auto-installation to complete
create_and_install_vm() {
    local iso_name="$1"
    local vm_id="$2"
    
    log_info "Creating VM $vm_id for auto-installation..."
    
    # Create VM with auto-installation ISO
    local create_cmd="qm create $vm_id \\
        --name '$TEMPLATE_NAME-installer' \\
        --memory 4096 \\
        --cores 2 \\
        --net0 virtio,bridge=vmbr0 \\
        --scsi0 $STORAGE_POOL:20 \\
        --ide2 $ISO_STORAGE:iso/$iso_name,media=cdrom \\
        --boot order=ide2 \\
        --ostype l26 \\
        --agent enabled=1"
    
    if ! execute_proxmox_cmd "$create_cmd" "Creating VM $vm_id"; then
        return 1
    fi
    
    log_info "Starting VM $vm_id for auto-installation..."
    if ! execute_proxmox_cmd "qm start $vm_id" "Starting VM $vm_id"; then
        return 1
    fi
    
    # Monitor VM until it shuts down (installation complete)
    log_info "Monitoring VM $vm_id automated installation progress..."
    log_info "AUTOMATED INSTALLATION IN PROGRESS:"
    log_info "  - systemd service 'nixos-auto-install' is running automatically"
    log_info "  - NixOS will be installed with LVM partitioning and GRUB bootloader"
    log_info "  - VM will shut down automatically when installation completes"
    log_info "Waiting for automated installation to finish..."
    echo ""
    
    local max_wait=1800  # 30 minutes max
    local wait_interval=30
    local elapsed=0
    local prompted=false
    
    while [[ $elapsed -lt $max_wait ]]; do
        local status
        status=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $vm_id" | awk '{print $2}' 2>/dev/null || echo "unknown")
        
        case "$status" in
            "stopped")
                log_success "VM $vm_id has stopped - installation complete!"
                return 0
                ;;
            "running")
                log_info "Automated installation in progress... (${elapsed}s elapsed)"
                ;;
            *)
                log_warning "VM $vm_id status: $status (${elapsed}s elapsed)"
                ;;
        esac
        
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done
    
    log_error "Automated installation timeout after ${max_wait}s - VM may have failed"
    return 1
}

# Convert installed VM to template
convert_vm_to_template() {
    local vm_id="$1"
    
    log_info "Converting VM $vm_id to template..."
    
    # Remove ISO from VM
    if ! execute_proxmox_cmd "qm set $vm_id --ide2 none" "Removing installation ISO"; then
        log_warning "Failed to remove ISO, continuing..."
    fi
    
    # Convert to template
    if execute_proxmox_cmd "qm template $vm_id" "Converting VM $vm_id to template"; then
        # Rename template
        if execute_proxmox_cmd "qm set $vm_id --name '$TEMPLATE_NAME'" "Renaming template to $TEMPLATE_NAME"; then
            log_success "Template conversion complete!"
            return 0
        else
            log_warning "Template created but rename failed"
            return 0
        fi
    else
        log_error "Failed to convert VM to template"
        return 1
    fi
}

# Create single base template
create_base_template() {
    log_info "Creating base NixOS template with auto-installation..."

    # Find available template ID
    local template_id
    if ! template_id=$(find_available_template_id "$TEMPLATE_ID_BASE"); then
        return 1
    fi

    # Upload ISO first
    if ! upload_iso "$ISO_DIR/$ISO_NAME"; then
        log_error "Failed to upload ISO"
        return 1
    fi

    # Create VM and run auto-installation
    if ! create_and_install_vm "$ISO_NAME" "$template_id"; then
        log_error "Auto-installation failed"
        return 1
    fi
    
    # Convert to template
    if convert_vm_to_template "$template_id"; then
        # Create template info file
        {
            echo "{"
            echo "  \"template\": {"
            echo "    \"vm_id\": $template_id,"
            echo "    \"name\": \"$TEMPLATE_NAME\","
            echo "    \"iso\": \"$ISO_NAME\""
            echo "  },"
            echo "  \"created_at\": \"$(date -Iseconds)\","
            echo "  \"proxmox_host\": \"$PROXMOX_HOST\","
            echo "  \"proxmox_node\": \"$PROXMOX_NODE\""
            echo "}"
        } > "$TEMPLATES_DIR/base-template-info.json"

        log_success "Base template created successfully!"
        log_info "Template ID: $template_id"
        log_info "Template Name: $TEMPLATE_NAME"
        return 0
    else
        log_error "Failed to create base template"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting Proxmox template creation..."

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Setup build environment
    setup_build_env

    # Create base template
    if create_base_template; then
        log_success "Base template creation completed!"
        log_info "Template information saved to: $TEMPLATES_DIR/base-template-info.json"
        log_info "Next steps:"
        log_info "  1. Update terraform.tfvars to use vm_template = \"$TEMPLATE_NAME\""
        log_info "  2. Use nixos-generators for node-specific configurations"
        log_info "  3. Run terraform plan/apply to test deployment"
        
        if [[ -f "$TEMPLATES_DIR/base-template-info.json" ]]; then
            log_info "Base template details:"
            cat "$TEMPLATES_DIR/base-template-info.json" | jq -r '"  - VM ID: \(.template.vm_id) (\(.template.name))"' 2>/dev/null || \
            echo "  - VM ID: $(cat "$TEMPLATES_DIR/base-template-info.json" | grep vm_id | cut -d: -f2 | tr -d ' ,') ($TEMPLATE_NAME)"
        fi
    else
        log_error "Base template creation failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"