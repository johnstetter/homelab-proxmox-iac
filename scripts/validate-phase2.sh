#!/usr/bin/env bash

# validate-phase2.sh
# Validates Phase 2 implementation and tests connectivity

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
NIXOS_DIR="$PROJECT_ROOT/nixos"
BUILD_DIR="$PROJECT_ROOT/build"

# Default values
TERRAFORM_DIR_OVERRIDE=""

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

Validate Phase 2 implementation and test connectivity.

OPTIONS:
    --terraform-dir DIR     Terraform directory (default: $TERRAFORM_DIR)
    --help                  Show this help message

EXAMPLES:
    $0                                    # Validate with default settings
    $0 --terraform-dir /path/to/terraform # Use custom terraform directory

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terraform-dir)
                TERRAFORM_DIR_OVERRIDE="$2"
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

    # Override terraform directory if specified
    if [[ -n "$TERRAFORM_DIR_OVERRIDE" ]]; then
        TERRAFORM_DIR="$TERRAFORM_DIR_OVERRIDE"
    fi
}

# Check NixOS configurations
check_nixos_configs() {
    log_info "Checking NixOS configurations..."
    local errors=0

    # Check if configurations exist and are populated
    local configs=(
        "$NIXOS_DIR/common/configuration.nix"
        "$NIXOS_DIR/dev/control.nix"
        "$NIXOS_DIR/dev/worker.nix"
        "$NIXOS_DIR/prod/control.nix"
        "$NIXOS_DIR/prod/worker.nix"
    )

    for config in "${configs[@]}"; do
        if [[ ! -f "$config" ]]; then
            log_error "Configuration file missing: $config"
            ((errors++))
        elif grep -q "^# .*config$" "$config" && [[ $(wc -l < "$config") -eq 1 ]]; then
            log_warning "Configuration file is just a placeholder: $config"
            ((errors++))
        else
            log_success "Configuration file exists and populated: $config"
        fi
    done

    return $errors
}

# Check generated ISOs
check_isos() {
    log_info "Checking generated ISOs..."
    local errors=0

    if [[ ! -d "$BUILD_DIR/isos" ]]; then
        log_warning "ISO directory not found: $BUILD_DIR/isos"
        log_info "Run ./scripts/generate-nixos-iso.sh to generate ISOs"
        return 1
    fi

    local iso_count
    iso_count=$(find "$BUILD_DIR/isos" -name "*.iso" | wc -l)
    
    if [[ $iso_count -eq 0 ]]; then
        log_warning "No ISOs found in $BUILD_DIR/isos"
        log_info "Run ./scripts/generate-nixos-iso.sh to generate ISOs"
        return 1
    else
        log_success "Found $iso_count ISO(s) in $BUILD_DIR/isos"
        find "$BUILD_DIR/isos" -name "*.iso" -exec basename {} \; | while read -r iso; do
            log_info "  - $iso"
        done
    fi

    return 0
}

# Check Proxmox templates
check_proxmox_templates() {
    log_info "Checking Proxmox templates..."

    if [[ ! -f "$BUILD_DIR/templates/base-template-info.json" ]]; then
        log_warning "Proxmox template mapping not found"
        log_info "Run ./scripts/create-proxmox-template.sh to create templates"
        return 1
    fi

    log_success "Proxmox template mapping found"
    
    if command -v jq &> /dev/null; then
        local template_count
        template_count=$(jq '.templates | length' "$BUILD_DIR/templates/base-template-info.json" 2>/dev/null || echo "0")
        log_info "Templates created: $template_count"
    fi

    return 0
}

# Check Terraform configuration
check_terraform() {
    log_info "Checking Terraform configuration..."
    local errors=0

    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi

    # Check required files
    local required_files=(
        "$TERRAFORM_DIR/main.tf"
        "$TERRAFORM_DIR/variables.tf"
        "$TERRAFORM_DIR/providers.tf"
        "$TERRAFORM_DIR/versions.tf"
        "$TERRAFORM_DIR/outputs.tf"
        "$TERRAFORM_DIR/environments/dev.tfvars.example"
        "$TERRAFORM_DIR/environments/prod.tfvars.example"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required Terraform file missing: $file"
            ((errors++))
        else
            log_success "Terraform file exists: $(basename "$file")"
        fi
    done

    # Check if terraform.tfvars exists
    if [[ -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        log_success "Terraform variables file exists: terraform.tfvars"
    else
        log_warning "Terraform variables file not found: terraform.tfvars"
        log_info "Copy environments/dev.tfvars.example to terraform.tfvars and configure"
    fi

    # Validate Terraform syntax
    if command -v terraform &> /dev/null; then
        log_info "Validating Terraform syntax..."
        if (cd "$TERRAFORM_DIR" && terraform validate) &>/dev/null; then
            log_success "Terraform configuration is valid"
        else
            log_error "Terraform configuration validation failed"
            ((errors++))
        fi
    else
        log_warning "Terraform not found, skipping syntax validation"
    fi

    return $errors
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    local errors=0

    # Check if nixos-generators is available
    if command -v nixos-generators &> /dev/null; then
        log_success "nixos-generators is available"
    else
        log_warning "nixos-generators not found"
        log_info "Install with: nix-env -iA nixpkgs.nixos-generators"
    fi

    # Check if Nix is available
    if command -v nix &> /dev/null; then
        log_success "Nix package manager is available"
    else
        log_warning "Nix package manager not found"
        log_info "Install from: https://nixos.org/download.html"
    fi

    # Check if Terraform is available
    if command -v terraform &> /dev/null; then
        local tf_version
        tf_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | cut -d' ' -f2)
        log_success "Terraform is available: $tf_version"
    else
        log_warning "Terraform not found"
        log_info "Install from: https://www.terraform.io/downloads"
    fi

    return $errors
}

# Test connectivity (if terraform.tfvars exists)
test_connectivity() {
    log_info "Testing connectivity..."

    if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        log_warning "terraform.tfvars not found, skipping connectivity tests"
        return 0
    fi

    # Extract Proxmox host from terraform.tfvars
    local proxmox_url
    if proxmox_url=$(grep -E '^proxmox_api_url' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 2>/dev/null); then
        local proxmox_host
        proxmox_host=$(echo "$proxmox_url" | sed -E 's|https?://([^:/]+).*|\1|')
        
        log_info "Testing connectivity to Proxmox: $proxmox_host"
        
        if ping -c 1 -W 5 "$proxmox_host" &>/dev/null; then
            log_success "Proxmox host is reachable: $proxmox_host"
        else
            log_warning "Proxmox host is not reachable: $proxmox_host"
        fi
        
        # Test API endpoint
        if curl -k -s --connect-timeout 5 "$proxmox_url/version" &>/dev/null; then
            log_success "Proxmox API is accessible"
        else
            log_warning "Proxmox API is not accessible"
        fi
    else
        log_warning "Could not extract Proxmox URL from terraform.tfvars"
    fi

    return 0
}

# Generate validation report
generate_report() {
    local total_errors="$1"
    
    log_info "=== Phase 2 Validation Report ==="
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "✅ Phase 2 validation passed!"
        log_info "Your NixOS Kubernetes infrastructure is ready for deployment."
        log_info ""
        log_info "Next steps:"
        log_info "  1. Configure terraform.tfvars with your environment settings"
        log_info "  2. Run 'terraform init' in the terraform directory"
        log_info "  3. Run 'terraform plan' to review the deployment plan"
        log_info "  4. Run 'terraform apply' to deploy the infrastructure"
        log_info "  5. Proceed to Phase 3: Kubernetes Installation"
    else
        log_error "❌ Phase 2 validation failed with $total_errors error(s)"
        log_info "Please address the issues above before proceeding."
        log_info ""
        log_info "Common fixes:"
        log_info "  - Run ./scripts/populate-nixos-configs.sh to create configurations"
        log_info "  - Run ./scripts/generate-nixos-iso.sh to create ISOs"
        log_info "  - Run ./scripts/create-proxmox-template.sh to create templates"
        log_info "  - Copy environments/dev.tfvars.example to terraform.tfvars and configure"
    fi
}

# Main execution
main() {
    log_info "Starting Phase 2 validation..."

    # Parse arguments
    parse_args "$@"

    local total_errors=0

    # Run validation checks
    check_prerequisites
    
    if ! check_nixos_configs; then
        ((total_errors++))
    fi
    
    check_isos  # Non-critical
    check_proxmox_templates  # Non-critical
    
    if ! check_terraform; then
        ((total_errors++))
    fi
    
    test_connectivity  # Non-critical

    # Generate report
    generate_report $total_errors

    exit $total_errors
}

# Run main function with all arguments
main "$@"
