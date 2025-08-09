#!/bin/bash
# End-to-End Ubuntu Infrastructure Build and Deployment Script
# Creates template, deploys servers, and generates Ansible inventory

set -euo pipefail

# Configuration
ENVIRONMENT="${ENVIRONMENT:-dev}"
SKIP_TEMPLATE="${SKIP_TEMPLATE:-false}"
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
TERRAFORM_ACTION="${TERRAFORM_ACTION:-apply}"  # apply, plan, destroy
PROXMOX_HOST="${PROXMOX_HOST:-core}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_NODE="${PROXMOX_NODE:-core}"

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../shared/lib/paths.sh
source "$(dirname "$(dirname "$SCRIPT_DIR")")/shared/lib/paths.sh"

# Use shared paths
UBUNTU_SERVERS_DIR="${K8S_INFRA_TERRAFORM_DIR}/projects/ubuntu-servers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Validate environment
validate_environment() {
    log "Validating environment..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed or not in PATH"
    fi
    
    # Check if required directories exist
    if [[ ! -d "${UBUNTU_SERVERS_DIR}" ]]; then
        error "Ubuntu servers directory not found: ${UBUNTU_SERVERS_DIR}"
    fi
    
    # Check if environment tfvars exists
    local tfvars_file="${UBUNTU_SERVERS_DIR}/environments/${ENVIRONMENT}.tfvars"
    if [[ ! -f "${tfvars_file}" ]]; then
        error "Environment file not found: ${tfvars_file}"
    fi
    
    success "Environment validation passed"
}

# Create Ubuntu template
create_template() {
    if [[ "${SKIP_TEMPLATE}" == "true" ]]; then
        warning "Skipping template creation (SKIP_TEMPLATE=true)"
        return
    fi
    
    log "Creating Ubuntu template..."
    
    local template_script="${SCRIPT_DIR}/create-ubuntu-template.sh"
    if [[ ! -f "${template_script}" ]]; then
        error "Template creation script not found: ${template_script}"
    fi
    
    # Pass Proxmox configuration to template script
    if ! PROXMOX_HOST="${PROXMOX_HOST}" PROXMOX_USER="${PROXMOX_USER}" PROXMOX_NODE="${PROXMOX_NODE}" "${template_script}"; then
        error "Template creation failed"
    fi
    
    success "Ubuntu template created successfully"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    if [[ "${SKIP_TERRAFORM}" == "true" ]]; then
        warning "Skipping Terraform deployment (SKIP_TERRAFORM=true)"
        return
    fi
    
    log "Deploying Ubuntu infrastructure with Terraform..."
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    if ! terraform init; then
        error "Terraform initialization failed"
    fi
    
    # Validate configuration
    log "Validating Terraform configuration..."
    if ! terraform validate; then
        error "Terraform validation failed"
    fi
    
    local tfvars_file="environments/${ENVIRONMENT}.tfvars"
    
    case "${TERRAFORM_ACTION}" in
        "plan")
            log "Creating Terraform plan..."
            terraform plan -var-file="${tfvars_file}"
            ;;
        "apply")
            log "Applying Terraform configuration..."
            if ! terraform apply -var-file="${tfvars_file}" -auto-approve; then
                error "Terraform apply failed"
            fi
            success "Infrastructure deployed successfully"
            ;;
        "destroy")
            log "Destroying infrastructure..."
            if ! terraform destroy -var-file="${tfvars_file}" -auto-approve; then
                error "Terraform destroy failed"
            fi
            success "Infrastructure destroyed successfully"
            ;;
        *)
            error "Unknown Terraform action: ${TERRAFORM_ACTION}"
            ;;
    esac
}

# Display deployment summary
show_summary() {
    log "Deployment Summary"
    echo "===================="
    echo "Environment: ${ENVIRONMENT}"
    echo "Template Creation: $([ "${SKIP_TEMPLATE}" == "true" ] && echo "Skipped" || echo "Completed")"
    echo "Terraform Action: ${TERRAFORM_ACTION}"
    echo ""
    
    if [[ "${TERRAFORM_ACTION}" == "apply" && "${SKIP_TERRAFORM}" != "true" ]]; then
        cd "${UBUNTU_SERVERS_DIR}"
        
        echo "🖥️  Server Information:"
        if terraform output -json ubuntu_servers &>/dev/null; then
            terraform output ubuntu_servers
        fi
        
        echo ""
        echo "🔑 SSH Connection:"
        if terraform output -json ssh_connection_commands &>/dev/null; then
            terraform output -json ssh_connection_commands | jq -r '.[]'
        fi
        
        echo ""
        echo "📋 Ansible Inventory:"
        local inventory_file=$(terraform output -raw ansible_inventory_file 2>/dev/null || echo "inventory/hosts.yml")
        if [[ -f "${inventory_file}" ]]; then
            echo "Generated at: ${inventory_file}"
        fi
    fi
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Verify servers are accessible via SSH"
    echo "2. Run Ansible playbooks against the inventory"
    echo "3. Configure your applications and services"
}

# Main execution
main() {
    echo "🚀 Ubuntu Infrastructure Build and Deploy"
    echo "Environment: ${ENVIRONMENT}"
    echo "Template Creation: $([ "${SKIP_TEMPLATE}" == "true" ] && echo "Skip" || echo "Create")"
    echo "Terraform Action: ${TERRAFORM_ACTION}"
    echo ""
    
    validate_environment
    create_template
    deploy_infrastructure
    show_summary
    
    success "Ubuntu infrastructure deployment completed!"
}

# Help function
show_help() {
    cat << EOF
Ubuntu Infrastructure Build and Deploy Script

Usage: $0 [OPTIONS]

Options:
    -e, --environment ENV       Environment to deploy (dev, staging, prod) [default: dev]
    -s, --skip-template         Skip Ubuntu template creation
    -t, --skip-terraform        Skip Terraform deployment
    -a, --action ACTION         Terraform action: plan, apply, destroy [default: apply]
    -h, --help                  Show this help message

Environment Variables:
    ENVIRONMENT                 Same as --environment
    SKIP_TEMPLATE              Same as --skip-template (true/false)
    SKIP_TERRAFORM             Same as --skip-terraform (true/false)
    TERRAFORM_ACTION           Same as --action

Examples:
    $0                         Deploy dev environment with template creation
    $0 -e prod                 Deploy production environment
    $0 -s                      Skip template creation, only deploy
    $0 -a plan                 Create deployment plan only
    $0 -a destroy              Destroy infrastructure
    $0 -s -t                   Skip everything (validation only)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--skip-template)
            SKIP_TEMPLATE="true"
            shift
            ;;
        -t|--skip-terraform)
            SKIP_TERRAFORM="true"
            shift
            ;;
        -a|--action)
            TERRAFORM_ACTION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Execute main function
main