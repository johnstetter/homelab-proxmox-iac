#!/usr/bin/env bash

# create-proxmox-templates.sh
# Automates Proxmox template creation from generated NixOS ISOs

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
ISO_DIR="$BUILD_DIR/isos"
LOG_DIR="$BUILD_DIR/logs"
TEMPLATES_DIR="$BUILD_DIR/templates"

# Default values
PROXMOX_HOST=""
PROXMOX_USER="root@pam"
PROXMOX_NODE=""
STORAGE_POOL="local"
ISO_STORAGE="local"
TEMPLATE_START_ID=9000
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    --template-start-id ID  Starting VM ID for templates (default: $TEMPLATE_START_ID)
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
            --template-start-id)
                TEMPLATE_START_ID="$2"
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

    # Check if ISOs exist
    if [[ ! -d "$ISO_DIR" ]] || [[ -z "$(ls -A "$ISO_DIR" 2>/dev/null)" ]]; then
        log_error "No ISOs found in $ISO_DIR"
        log_error "Run ./scripts/generate-nixos-isos.sh first"
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

    # Check if ISO already exists
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "test -f /var/lib/vz/template/iso/$iso_name"; then
        log_warning "ISO already exists on Proxmox: $iso_name"
        return 0
    fi

    # Upload ISO
    if scp "$iso_file" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/template/iso/"; then
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
    local node_type
    local env

    iso_name=$(basename "$iso_file")
    
    # Extract node type and environment from ISO name
    if [[ "$iso_name" =~ nixos-k8s-([^-]+)-([^.]+)\.iso ]]; then
        node_type="${BASH_REMATCH[1]}"
        env="${BASH_REMATCH[2]}"
        template_name="nixos-2311-k8s-$node_type-$env"
    else
        log_error "Cannot parse ISO name: $iso_name"
        return 1
    fi

    log_info "Creating template: $template_name (VM ID: $vm_id)"

    # Upload ISO first
    if ! upload_iso "$iso_file"; then
        return 1
    fi

    # Create VM
    local create_cmd="qm create $vm_id --name $template_name --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --ostype l26"
    if ! execute_proxmox_cmd "$create_cmd" "Creating VM $vm_id"; then
        return 1
    fi

    # Import disk from ISO
    local import_cmd="qm importdisk $vm_id /var/lib/vz/template/iso/$iso_name $STORAGE_POOL"
    if ! execute_proxmox_cmd "$import_cmd" "Importing disk for VM $vm_id"; then
        return 1
    fi

    # Configure VM
    local config_cmds=(
        "qm set $vm_id --scsi0 $STORAGE_POOL:vm-$vm_id-disk-0"
        "qm set $vm_id --boot c --bootdisk scsi0"
        "qm set $vm_id --ide2 $STORAGE_POOL:cloudinit"
        "qm set $vm_id --serial0 socket --vga serial0"
        "qm set $vm_id --agent enabled=1"
        "qm set $vm_id --ciuser nixos"
        "qm set $vm_id --sshkey /root/.ssh/authorized_keys"
    )

    for cmd in "${config_cmds[@]}"; do
        if ! execute_proxmox_cmd "$cmd" "Configuring VM $vm_id"; then
            return 1
        fi
    done

    # Convert to template
    local template_cmd="qm template $vm_id"
    if ! execute_proxmox_cmd "$template_cmd" "Converting VM $vm_id to template"; then
        return 1
    fi

    # Save template information
    local template_info="{\"vm_id\": $vm_id, \"name\": \"$template_name\", \"iso\": \"$iso_name\", \"node_type\": \"$node_type\", \"environment\": \"$env\"}"
    echo "$template_info" >> "$TEMPLATES_DIR/template-info.json"

    log_success "Created template: $template_name"
    return 0
}

# Create all templates
create_templates() {
    local vm_id=$TEMPLATE_START_ID
    local success_count=0
    local failed_count=0
    local template_mapping=()

    log_info "Creating Proxmox templates from ISOs..."

    # Process each ISO file
    for iso_file in "$ISO_DIR"/*.iso; do
        if [[ ! -f "$iso_file" ]]; then
            log_warning "No ISO files found in $ISO_DIR"
            continue
        fi

        local iso_name
        iso_name=$(basename "$iso_file")
        
        log_info "Processing ISO: $iso_name"

        # Check if VM ID is already in use
        while ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $vm_id" &>/dev/null; do
            log_warning "VM ID $vm_id already in use, trying next ID"
            ((vm_id++))
        done

        if create_template "$iso_file" "$vm_id"; then
            template_mapping+=("$iso_name:$vm_id")
            ((success_count++))
        else
            ((failed_count++))
        fi

        ((vm_id++))
    done

    # Create template mapping file
    if [[ ${#template_mapping[@]} -gt 0 ]]; then
        {
            echo "{"
            echo "  \"templates\": ["
            for i in "${!template_mapping[@]}"; do
                local mapping="${template_mapping[$i]}"
                local iso_name="${mapping%:*}"
                local template_id="${mapping#*:}"
                echo "    {\"iso\": \"$iso_name\", \"vm_id\": $template_id}$([ $i -lt $((${#template_mapping[@]} - 1)) ] && echo ",")"
            done
            echo "  ],"
            echo "  \"created_at\": \"$(date -Iseconds)\","
            echo "  \"proxmox_host\": \"$PROXMOX_HOST\","
            echo "  \"proxmox_node\": \"$PROXMOX_NODE\""
            echo "}"
        } > "$TEMPLATES_DIR/proxmox-template-ids.json"
    fi

    # Summary
    log_info "Template creation summary:"
    log_info "  Successful: $success_count"
    log_info "  Failed: $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        log_error "Some templates failed to create. Check logs for details."
        return 1
    fi

    return 0
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

    # Create templates
    if create_templates; then
        log_success "All templates created successfully!"
        log_info "Template information saved to: $TEMPLATES_DIR/proxmox-template-ids.json"
        log_info "Next steps:"
        log_info "  1. Update terraform.tfvars with template names"
        log_info "  2. Run terraform plan/apply to test deployment"
        
        if [[ -f "$TEMPLATES_DIR/proxmox-template-ids.json" ]]; then
            log_info "Available templates:"
            cat "$TEMPLATES_DIR/proxmox-template-ids.json" | jq -r '.templates[] | "  - VM ID \(.vm_id): \(.iso)"' 2>/dev/null || \
            grep -o '"vm_id": [0-9]*' "$TEMPLATES_DIR/proxmox-template-ids.json" | sed 's/"vm_id": /  - VM ID /'
        fi
    else
        log_error "Template creation failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"