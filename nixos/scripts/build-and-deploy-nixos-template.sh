#!/usr/bin/env bash

# build-and-deploy-nixos-template.sh
# Complete NixOS pipeline: generate ISO and deploy template to Proxmox in one command

set -euo pipefail

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../shared/lib/paths.sh
source "$(dirname "$(dirname "$SCRIPT_DIR")")/shared/lib/paths.sh"

# Default values (can be overridden by shared config)
STORAGE_POOL="local-lvm"
ISO_STORAGE="local"
TEMPLATE_ID_BASE=9100
CLEAN_BUILD=false
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
Usage: $0 --proxmox-host HOST [OPTIONS]

Complete pipeline to generate NixOS ISO and deploy template to Proxmox.

REQUIRED:
    --proxmox-host HOST     Proxmox server hostname or IP

OPTIONS:
    --proxmox-user USER     Proxmox SSH username (default: root)
    --proxmox-node NODE     Proxmox node name (auto-detect if not specified)
    --storage POOL          Storage pool for VM disks (default: local-zfs-tank)
    --iso-storage STORAGE   Storage for ISO files (default: local)
    --template-id ID        Starting template ID (default: 9100)
    --clean                 Clean build directory before ISO generation
    --dry-run              Show what would be done without executing
    --help                 Show this help message

EXAMPLES:
    $0 --proxmox-host 192.168.1.5
    $0 --proxmox-host pve.local --clean --storage local-lvm
    $0 --proxmox-host 192.168.1.5 --template-id 9200 --dry-run

This script will:
    1. Generate NixOS ISO with automated installation and commit SHA embedded
    2. Upload ISO to Proxmox
    3. Create VM and boot it with systemd-managed auto-installation
    4. Monitor automated systemd service progress (no manual intervention needed)
    5. Wait for VM shutdown signal when automated installation completes
    6. Convert completed VM to template
    7. Clean up temporary files

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
            --clean)
                CLEAN_BUILD=true
                shift
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

    # Validate required arguments
    if [[ -z "$PROXMOX_HOST" ]]; then
        log_error "Proxmox host is required. Use --proxmox-host HOST"
        usage
        exit 1
    fi
}

# Step 1: Generate ISO
generate_iso() {
    log_info "=== STEP 1: Generating NixOS ISO ==="
    
    local iso_args=()
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        iso_args+=(--clean)
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: ./scripts/generate-nixos-iso.sh ${iso_args[*]}"
        return 0
    fi
    
    if "$(find_script "generate-nixos-iso.sh")" "${iso_args[@]}"; then
        log_success "ISO generation completed"
        return 0
    else
        log_error "ISO generation failed"
        return 1
    fi
}

# Step 2: Deploy template to Proxmox
deploy_template() {
    log_info "=== STEP 2: Deploying template to Proxmox ==="
    
    local template_args=(
        --proxmox-host "$PROXMOX_HOST"
        --proxmox-user "$PROXMOX_USER"
        --storage "$STORAGE_POOL"
        --iso-storage "$ISO_STORAGE"
        --template-id "$TEMPLATE_ID_BASE"
    )
    
    if [[ -n "$PROXMOX_NODE" ]]; then
        template_args+=(--proxmox-node "$PROXMOX_NODE")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        template_args+=(--dry-run)
    fi
    
    if "$(find_script "create-proxmox-template.sh")" "${template_args[@]}"; then
        log_success "Template deployment completed"
        return 0
    else
        log_error "Template deployment failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting complete NixOS template build and deployment pipeline..."
    echo ""
    
    # Parse arguments
    parse_args "$@"
    
    # Show configuration
    log_info "Configuration:"
    log_info "  Proxmox Host: $PROXMOX_HOST"
    log_info "  Proxmox User: $PROXMOX_USER"
    log_info "  Storage Pool: $STORAGE_POOL"
    log_info "  ISO Storage: $ISO_STORAGE"
    log_info "  Template ID: $TEMPLATE_ID_BASE+"
    log_info "  Clean Build: $CLEAN_BUILD"
    log_info "  Dry Run: $DRY_RUN"
    echo ""
    
    # Step 1: Generate ISO
    if ! generate_iso; then
        log_error "Pipeline failed at ISO generation step"
        exit 1
    fi
    
    echo ""
    
    # Step 2: Deploy template
    if ! deploy_template; then
        log_error "Pipeline failed at template deployment step"
        exit 1
    fi
    
    echo ""
    log_success "Complete pipeline finished successfully!"
    log_info "Template is ready for use with Terraform"
    log_info "Next steps:"
    log_info "  cd terraform/"
    log_info "  terraform apply -var-file=\"environments/dev.tfvars\""
}

# Run main function with all arguments
main "$@"