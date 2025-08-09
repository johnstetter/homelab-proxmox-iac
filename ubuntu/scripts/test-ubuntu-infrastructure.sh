#!/bin/bash
# Ubuntu Infrastructure Testing Script
# Validates template creation, deployment, and connectivity

set -euo pipefail

# Configuration
ENVIRONMENT="${ENVIRONMENT:-test}"
TEST_TEMPLATE_ID="${TEST_TEMPLATE_ID:-9001}"
TEST_TEMPLATE_NAME="${TEST_TEMPLATE_NAME:-ubuntu-25.04-test}"
SKIP_TEMPLATE="${SKIP_TEMPLATE:-false}"
SKIP_DEPLOY="${SKIP_DEPLOY:-false}"
CLEANUP_AFTER="${CLEANUP_AFTER:-false}"
PROXMOX_HOST="${PROXMOX_HOST:-core}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../shared/lib/paths.sh
source "$(dirname "$(dirname "$SCRIPT_DIR")")/shared/lib/paths.sh"

# Use shared paths
UBUNTU_SERVERS_DIR="${K8S_INFRA_ROOT_MODULES_DIR}/ubuntu-servers"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS+=("PASS: $1")
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS+=("FAIL: $1")
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log "Testing: $test_name"
    
    if eval "$test_command"; then
        success "$test_name"
        return 0
    else
        fail "$test_name"
        return 1
    fi
}

# Execute Proxmox command via SSH
execute_proxmox_cmd() {
    local cmd="$1"
    local description="$2"

    log "$description"
    
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "$cmd"; then
        success "$description completed"
        return 0
    else
        fail "$description failed"
        return 1
    fi
}

# Test template creation
test_template_creation() {
    if [[ "${SKIP_TEMPLATE}" == "true" ]]; then
        warning "Skipping template creation tests"
        return 0
    fi
    
    log "🔧 Testing Ubuntu Template Creation"
    
    # Check if template already exists
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEST_TEMPLATE_ID}/config" &>/dev/null; then
        warning "Test template ${TEST_TEMPLATE_ID} already exists, skipping creation"
    else
        run_test "Ubuntu template creation" \
            "TEMPLATE_ID=${TEST_TEMPLATE_ID} TEMPLATE_NAME=${TEST_TEMPLATE_NAME} PROXMOX_HOST=${PROXMOX_HOST} PROXMOX_USER=${PROXMOX_USER} PROXMOX_NODE=${PROXMOX_NODE} $(find_script "create-ubuntu-template.sh")"
    fi
    
    # Validate template
    run_test "Template exists in Proxmox" \
        "ssh '$PROXMOX_USER@$PROXMOX_HOST' 'pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEST_TEMPLATE_ID}/config' >/dev/null"
    
    run_test "Template has correct configuration" \
        "ssh '$PROXMOX_USER@$PROXMOX_HOST' 'pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEST_TEMPLATE_ID}/config | grep -q \"template: 1\"'"
}

# Test Terraform configuration
test_terraform_config() {
    log "🏗️  Testing Terraform Configuration"
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    run_test "Terraform configuration validation" \
        "terraform validate"
    
    run_test "Terraform formatting check" \
        "terraform fmt -check"
    
    # Create test environment file if it doesn't exist
    if [[ ! -f "environments/${ENVIRONMENT}.tfvars" ]]; then
        log "Creating test environment configuration"
        cp environments/dev.tfvars.example "environments/${ENVIRONMENT}.tfvars"
        
        # Update for testing (minimal resources)
        sed -i "s/server_count = 2/server_count = 1/" "environments/${ENVIRONMENT}.tfvars"
        sed -i "s/server_cores = 2/server_cores = 1/" "environments/${ENVIRONMENT}.tfvars"
        sed -i "s/server_memory = 2048/server_memory = 1024/" "environments/${ENVIRONMENT}.tfvars"
        sed -i "s/vm_template = \"ubuntu-25.04-cloud-init\"/vm_template = \"${TEST_TEMPLATE_NAME}\"/" "environments/${ENVIRONMENT}.tfvars"
    fi
    
    run_test "Terraform initialization" \
        "terraform init -reconfigure"
    
    run_test "Terraform plan generation" \
        "terraform plan -var-file=\"environments/${ENVIRONMENT}.tfvars\" -detailed-exitcode -out=test.tfplan"
}

# Test Terraform deployment
test_terraform_deployment() {
    if [[ "${SKIP_DEPLOY}" == "true" ]]; then
        warning "Skipping deployment tests"
        return 0
    fi
    
    log "🚀 Testing Terraform Deployment"
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    run_test "Terraform deployment" \
        "terraform apply test.tfplan"
    
    # Wait for VMs to boot
    log "Waiting 30 seconds for VMs to boot..."
    sleep 30
    
    run_test "Server output generation" \
        "terraform output ubuntu_servers >/dev/null"
    
    run_test "SSH key file generation" \
        "test -f ssh_keys/ubuntu_private_key.pem"
    
    run_test "SSH key permissions" \
        "test \$(stat -c '%a' ssh_keys/ubuntu_private_key.pem) = '600'"
    
    run_test "Ansible inventory generation" \
        "test -f inventory/hosts.yml"
}

# Test SSH connectivity
test_ssh_connectivity() {
    if [[ "${SKIP_DEPLOY}" == "true" ]]; then
        warning "Skipping SSH connectivity tests"
        return 0
    fi
    
    log "🔐 Testing SSH Connectivity"
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    # Get server IPs
    local server_ips
    if ! server_ips=$(terraform output -json server_ips | jq -r '.[]' 2>/dev/null); then
        fail "Could not retrieve server IPs"
        return 1
    fi
    
    for ip in $server_ips; do
        run_test "SSH connectivity to $ip" \
            "timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ssh_keys/ubuntu_private_key.pem ubuntu@$ip 'echo connected' >/dev/null 2>&1"
        
        run_test "Python availability on $ip" \
            "timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ssh_keys/ubuntu_private_key.pem ubuntu@$ip 'python3 --version' >/dev/null 2>&1"
        
        run_test "Sudo access on $ip" \
            "timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ssh_keys/ubuntu_private_key.pem ubuntu@$ip 'sudo whoami | grep root' >/dev/null 2>&1"
    done
}

# Test Ansible integration
test_ansible_integration() {
    if [[ "${SKIP_DEPLOY}" == "true" ]]; then
        warning "Skipping Ansible integration tests"
        return 0
    fi
    
    log "📋 Testing Ansible Integration"
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    # Check if ansible is available
    if ! command -v ansible &> /dev/null; then
        warning "Ansible not found, skipping Ansible tests"
        return 0
    fi
    
    run_test "Ansible inventory validation" \
        "ansible-inventory -i inventory/hosts.yml --list >/dev/null"
    
    run_test "Ansible ping test" \
        "timeout 30 ansible all -i inventory/hosts.yml -m ping >/dev/null 2>&1"
    
    run_test "Ansible fact gathering" \
        "timeout 30 ansible all -i inventory/hosts.yml -m setup -a 'filter=ansible_python*' >/dev/null 2>&1"
}

# Cleanup test resources
cleanup_resources() {
    if [[ "${CLEANUP_AFTER}" != "true" ]]; then
        log "Skipping cleanup (CLEANUP_AFTER=false)"
        return 0
    fi
    
    log "🧹 Cleaning Up Test Resources"
    
    cd "${UBUNTU_SERVERS_DIR}"
    
    # Destroy infrastructure
    if [[ -f "environments/${ENVIRONMENT}.tfvars" ]]; then
        run_test "Infrastructure cleanup" \
            "terraform destroy -var-file=\"environments/${ENVIRONMENT}.tfvars\" -auto-approve"
    fi
    
    # Remove test template (optional)
    if [[ "${SKIP_TEMPLATE}" != "true" ]]; then
        run_test "Template cleanup" \
            "ssh '$PROXMOX_USER@$PROXMOX_HOST' 'qm destroy ${TEST_TEMPLATE_ID} 2>/dev/null || true'"
    fi
    
    # Clean up test files
    rm -f test.tfplan
    rm -f "environments/${ENVIRONMENT}.tfvars"
}

# Show test results
show_results() {
    echo ""
    log "📊 Test Results Summary"
    echo "======================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed! Ubuntu infrastructure is working correctly.${NC}"
        return 0
    else
        echo -e "\n${RED}💥 Some tests failed. Please check the output above.${NC}"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
Ubuntu Infrastructure Testing Script

Usage: $0 [OPTIONS]

Options:
    -e, --environment ENV       Test environment name [default: test]
    -s, --skip-template         Skip template creation tests
    -d, --skip-deploy           Skip deployment tests
    -c, --cleanup               Clean up resources after testing
    -h, --help                  Show this help message

Environment Variables:
    ENVIRONMENT                 Test environment name
    TEST_TEMPLATE_ID           Template ID for testing [default: 9001]
    TEST_TEMPLATE_NAME         Template name for testing [default: ubuntu-25.04-test]
    SKIP_TEMPLATE              Skip template tests (true/false)
    SKIP_DEPLOY                Skip deployment tests (true/false)
    CLEANUP_AFTER              Clean up after tests (true/false)

Examples:
    $0                         Run all tests with defaults
    $0 -s                      Skip template creation, test deployment only
    $0 -d                      Test template creation only, skip deployment
    $0 -c                      Run all tests and cleanup afterwards
    $0 -e staging -c           Test staging environment and cleanup

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
        -d|--skip-deploy)
            SKIP_DEPLOY="true"
            shift
            ;;
        -c|--cleanup)
            CLEANUP_AFTER="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🧪 Ubuntu Infrastructure Testing"
    echo "Environment: ${ENVIRONMENT}"
    echo "Template ID: ${TEST_TEMPLATE_ID}"
    echo "Template Name: ${TEST_TEMPLATE_NAME}"
    echo ""
    
    # Validate prerequisites
    if ! command -v terraform &> /dev/null; then
        fail "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Test SSH connectivity to Proxmox
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH connection test'" &>/dev/null; then
        fail "Cannot connect to Proxmox server via SSH: $PROXMOX_USER@$PROXMOX_HOST"
        exit 1
    fi
    
    # Run test phases
    test_template_creation
    test_terraform_config
    test_terraform_deployment
    test_ssh_connectivity
    test_ansible_integration
    cleanup_resources
    
    # Show results and exit
    show_results
}

# Execute main function
main