#!/usr/bin/env bash

# generate-nixos-isos.sh  
# Generates a single base NixOS ISO for VM template creation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NIXOS_DIR="$PROJECT_ROOT/nixos"
BUILD_DIR="$PROJECT_ROOT/build"
ISO_DIR="$BUILD_DIR/isos"
LOG_DIR="$BUILD_DIR/logs"

# Default values
OUTPUT_DIR="$ISO_DIR"
NIXOS_VERSION="24.11"
CLEAN_BUILD=false
ISO_NAME="nixos-base-template.iso"

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

Generate single base NixOS ISO using nixos-generators with automated installation.

OPTIONS:
    --output-dir DIR    Output directory for ISO (default: $ISO_DIR)
    --nixos-version VER NixOS version (default: $NIXOS_VERSION)
    --clean             Clean build directory before generation
    --help              Show this help message

EXAMPLES:
    $0                                    # Generate base template ISO
    $0 --clean --output-dir /tmp/isos    # Clean build and custom output

REQUIREMENTS:
    - Nix package manager must be installed
    - NixOS configuration must exist at $NIXOS_DIR/base-template.nix

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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

    # Check if nixos-generate is available
    if ! command -v nixos-generate &> /dev/null; then
        log_error "nixos-generators is not installed. Please install it first:"
        log_error "  nix-env -iA nixos.nixos-generators"
        exit 1
    fi

    # Check if NixOS configuration exists
    if [[ ! -f "$NIXOS_DIR/base-template.nix" ]]; then
        log_error "NixOS configuration not found: $NIXOS_DIR/base-template.nix"
        log_error "This file should contain the base template configuration with automated installation"
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

# Generate single base ISO
generate_base_iso() {
    local iso_path="$OUTPUT_DIR/$ISO_NAME"
    
    log_info "Generating base template ISO: $ISO_NAME"
    
    # Remove existing ISO if it exists (overwrite approach)
    if [[ -f "$iso_path" ]]; then
        log_info "Removing existing ISO: $ISO_NAME"
        rm -f "$iso_path"
    fi

    # Get current commit SHA
    local commit_sha
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        commit_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        log_info "Building ISO from commit: $commit_sha"
    else
        commit_sha="unknown"
        log_warning "Not in a git repository, commit SHA will be 'unknown'"
    fi
    
    # Generate ISO using nixos-generators with commit info
    log_info "Running nixos-generate with base-template.nix..."
    if NIX_BUILD_COMMIT_SHA="$commit_sha" nixos-generate -f iso -c "$NIXOS_DIR/base-template.nix" -o "$iso_path" 2>&1 | tee -a "$LOG_DIR/iso-generation.log"; then
        # nixos-generate creates a symlink to the actual ISO, resolve it
        if [[ -L "$iso_path" ]]; then
            local real_iso_dir
            real_iso_dir=$(readlink -f "$iso_path")
            log_info "Resolving symlink: $iso_path -> $real_iso_dir"
            
            # Find the actual ISO file in the directory structure
            local actual_iso
            if [[ -d "$real_iso_dir" ]]; then
                # Look for ISO file in the directory or subdirectories
                actual_iso=$(find "$real_iso_dir" -name "*.iso" -type f | head -1)
            else
                actual_iso="$real_iso_dir"
            fi
            
            if [[ -f "$actual_iso" ]]; then
                log_info "Found actual ISO: $actual_iso"
                # Copy the actual ISO to the expected location
                cp "$actual_iso" "$iso_path.tmp"
                rm "$iso_path"
                mv "$iso_path.tmp" "$iso_path"
            else
                log_error "Could not find actual ISO file in: $real_iso_dir"
                return 1
            fi
        fi
        
        log_success "Generated ISO: $iso_path"
        
        # Get ISO size
        local iso_size
        iso_size=$(du -h "$iso_path" | cut -f1)
        log_info "ISO size: $iso_size"
        
        return 0
    else
        log_error "Failed to generate base template ISO"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting NixOS base template ISO generation..."

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Setup build environment
    setup_build_env

    # Generate base ISO
    if generate_base_iso; then
        log_success "Base template ISO generated successfully!"
        log_info "ISO is available at: $OUTPUT_DIR/$ISO_NAME"
        log_info "Next steps:"
        log_info "  1. Run ./scripts/create-proxmox-template.sh --proxmox-host <host>"
        log_info "  2. Complete manual NixOS installation on VM 9000"
        log_info "  3. Convert VM to template when installation is complete"
    else
        log_error "ISO generation failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"