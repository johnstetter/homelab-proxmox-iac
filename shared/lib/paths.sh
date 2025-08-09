#!/bin/bash
# Shared Path Resolution Library
# Makes all scripts location-independent by providing standard path discovery functions

# Find the project root by looking for characteristic files/directories
find_project_root() {
    local current_dir="${1:-}"
    
    # If no directory provided, start from script's location
    if [[ -z "$current_dir" ]]; then
        current_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    fi
    
    # Walk up the directory tree looking for project root indicators
    while [[ "$current_dir" != "/" ]]; do
        # Look for characteristic files that indicate project root
        if [[ -f "$current_dir/.git/config" ]] && [[ -d "$current_dir/root-modules" ]] && [[ -d "$current_dir/shared" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Fallback: if we can't find the root, assume we're already there
    echo "$(pwd)"
    return 1
}

# Initialize standard project paths
init_project_paths() {
    # Find project root
    export K8S_INFRA_ROOT="${K8S_INFRA_ROOT:-$(find_project_root)}"
    
    # Standard directory paths
    export K8S_INFRA_SHARED_DIR="${K8S_INFRA_ROOT}/shared"
    export K8S_INFRA_SCRIPTS_DIR="${K8S_INFRA_ROOT}/scripts"
    export K8S_INFRA_BUILD_DIR="${K8S_INFRA_ROOT}/build"
    export K8S_INFRA_DOCS_DIR="${K8S_INFRA_ROOT}/docs"
    
    # Platform-specific paths
    export K8S_INFRA_NIXOS_DIR="${K8S_INFRA_ROOT}/nixos"
    export K8S_INFRA_UBUNTU_DIR="${K8S_INFRA_ROOT}/ubuntu"
    export K8S_INFRA_TERRAFORM_DIR="${K8S_INFRA_ROOT}/terraform"
    export K8S_INFRA_ROOT_MODULES_DIR="${K8S_INFRA_ROOT}/root-modules"
    export K8S_INFRA_SHARED_MODULES_DIR="${K8S_INFRA_ROOT}/shared-modules"
    
    # Build and output paths
    export K8S_INFRA_ISO_DIR="${K8S_INFRA_BUILD_DIR}/isos"
    export K8S_INFRA_LOG_DIR="${K8S_INFRA_BUILD_DIR}/logs"
    export K8S_INFRA_TEMPLATES_DIR="${K8S_INFRA_BUILD_DIR}/templates"
    
    # Create directories if they don't exist
    mkdir -p "$K8S_INFRA_BUILD_DIR" "$K8S_INFRA_ISO_DIR" "$K8S_INFRA_LOG_DIR" "$K8S_INFRA_TEMPLATES_DIR"
}

# Get platform-specific script directory
get_platform_scripts_dir() {
    local platform="$1"
    
    case "$platform" in
        "nixos")
            echo "${K8S_INFRA_NIXOS_DIR}/scripts"
            ;;
        "ubuntu")
            echo "${K8S_INFRA_UBUNTU_DIR}/scripts"
            ;;
        "terraform"|"")
            echo "${K8S_INFRA_SCRIPTS_DIR}"
            ;;
        *)
            echo "${K8S_INFRA_SCRIPTS_DIR}"
            ;;
    esac
}

# Find a script by name across all script directories
find_script() {
    local script_name="$1"
    local search_dirs=(
        "${K8S_INFRA_SCRIPTS_DIR}"
        "${K8S_INFRA_NIXOS_DIR}/scripts"
        "${K8S_INFRA_UBUNTU_DIR}/scripts"
    )
    
    for dir in "${search_dirs[@]}"; do
        if [[ -f "$dir/$script_name" ]]; then
            echo "$dir/$script_name"
            return 0
        fi
    done
    
    return 1
}

# Load shared configuration file
load_shared_config() {
    local config_file="${K8S_INFRA_SHARED_DIR}/config/defaults.env"
    
    if [[ -f "$config_file" ]]; then
        # Source the config file
        set -a  # automatically export all variables
        # shellcheck source=/dev/null
        source "$config_file"
        set +a  # turn off automatic export
    fi
}

# Validate that all required paths exist
validate_project_paths() {
    local required_dirs=(
        "$K8S_INFRA_ROOT"
        "$K8S_INFRA_SHARED_DIR"
        "$K8S_INFRA_BUILD_DIR"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "ERROR: Required directory not found: $dir" >&2
            return 1
        fi
    done
    
    return 0
}

# Debug function to show all paths
debug_paths() {
    echo "=== K8S Infrastructure Paths ==="
    echo "Project Root: $K8S_INFRA_ROOT"
    echo "Shared Dir:   $K8S_INFRA_SHARED_DIR"
    echo "Scripts Dir:  $K8S_INFRA_SCRIPTS_DIR"
    echo "Build Dir:    $K8S_INFRA_BUILD_DIR"
    echo "NixOS Dir:    $K8S_INFRA_NIXOS_DIR"
    echo "Ubuntu Dir:   $K8S_INFRA_UBUNTU_DIR"
    echo "Terraform:    $K8S_INFRA_TERRAFORM_DIR"
    echo "Root Modules: $K8S_INFRA_ROOT_MODULES_DIR"
    echo "================================"
}

# Initialize paths when this library is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced, initialize paths
    init_project_paths
    
    # Load shared configuration if available
    load_shared_config
    
    # Validate paths
    if ! validate_project_paths; then
        echo "WARNING: Project path validation failed" >&2
    fi
fi