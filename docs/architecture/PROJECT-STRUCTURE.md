# Project Structure and Path Resolution

This document explains the improved project structure and path resolution system implemented to eliminate path dependencies and improve maintainability.

## 🏗️ Directory Structure

```
k8s-infra/
├── shared/                     # Shared utilities and configuration
│   ├── lib/                    # Shared libraries
│   │   └── paths.sh           # Path resolution and utilities
│   └── config/                # Centralized configuration
│       ├── defaults.env       # Default environment variables
│       ├── network.yaml       # Network configuration
│       └── storage.yaml       # Storage configuration
├── platforms/
│   ├── nixos/                 # NixOS-specific code
│   │   ├── scripts/           # NixOS build and deployment scripts
│   │   ├── templates/         # NixOS configuration templates
│   │   └── configs/           # Environment-specific configs
│   └── ubuntu/                # Ubuntu-specific code
│       ├── scripts/           # Ubuntu build and deployment scripts
│       ├── cloud-init/        # Cloud-init templates
│       └── templates/         # Ubuntu configuration templates
├── terraform/
│   ├── modules/               # Reusable Terraform modules
│   └── environments/          # Root modules for different environments
├── scripts/                   # General infrastructure scripts
├── docs/                      # Documentation
├── build/                     # Build artifacts (auto-created)
│   ├── isos/
│   ├── logs/
│   └── templates/
└── ops/                       # Operations tooling
    ├── .devcontainer/         # Development container setup
    └── monitoring/            # Monitoring configurations
```

## 🔧 Path Resolution System

### Core Components

1. **`shared/lib/paths.sh`**: Main path resolution library
2. **`shared/config/defaults.env`**: Default configuration values
3. **Auto-discovery**: Finds project root by looking for characteristic files

### Key Functions

```bash
# Initialize all project paths
init_project_paths()

# Find project root automatically
find_project_root()

# Find a script across all script directories
find_script "script-name.sh"

# Get platform-specific script directory
get_platform_scripts_dir "platform"

# Load shared configuration
load_shared_config()
```

### Environment Variables

All scripts now use standardized environment variables:

```bash
# Core paths
K8S_INFRA_ROOT                 # Project root directory
K8S_INFRA_SHARED_DIR           # Shared utilities directory
K8S_INFRA_BUILD_DIR            # Build artifacts directory

# Platform paths
K8S_INFRA_NIXOS_DIR            # NixOS platform directory
K8S_INFRA_UBUNTU_DIR           # Ubuntu platform directory
K8S_INFRA_TERRAFORM_DIR        # Terraform directory
K8S_INFRA_ROOT_MODULES_DIR     # Terraform root modules

# Build paths
K8S_INFRA_ISO_DIR              # ISO build directory
K8S_INFRA_LOG_DIR              # Logs directory
K8S_INFRA_TEMPLATES_DIR        # Templates directory
```

## 📝 Script Integration

### Standard Script Header

All scripts now use this standard header:

```bash
#!/bin/bash
set -euo pipefail

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shared/lib/paths.sh
source "$(dirname "$SCRIPT_DIR")/shared/lib/paths.sh"

# Use shared paths and configuration
# Variables like PROXMOX_HOST, STORAGE_POOL, etc. are now available
```

### Script Discovery

Instead of hardcoded paths:

```bash
# OLD - fragile
"$SCRIPT_DIR/other-script.sh"

# NEW - location-independent
"$(find_script "other-script.sh")"
```

### Platform-Specific Paths

```bash
# Automatically resolves to correct directory
UBUNTU_SCRIPTS_DIR="$(get_platform_scripts_dir "ubuntu")"
NIXOS_SCRIPTS_DIR="$(get_platform_scripts_dir "nixos")"
```

## 🎯 Benefits

### 1. Location Independence
- Scripts work from any directory
- No hardcoded relative paths
- Automatic project root discovery

### 2. Centralized Configuration
- Single source of truth for defaults
- Environment-specific overrides
- Consistent naming across platforms

### 3. Better Organization
- Platform-specific code grouped together
- Clear separation of concerns
- Reduced coupling between components

### 4. Easier Maintenance
- Changes to directory structure are isolated
- Scripts automatically adapt to new locations
- Consistent patterns across all scripts

## 🔍 Component Interfaces

### NixOS Platform
```
nixos/
├── scripts/
│   ├── create-proxmox-template.sh    # Creates NixOS Proxmox template
│   ├── generate-nixos-iso.sh         # Generates custom NixOS ISO
│   └── populate-nixos-configs.sh     # Populates config files
└── configs/                          # NixOS system configurations
```

**Interface**: Uses shared Proxmox configuration, outputs templates with standardized naming

### Ubuntu Platform
```
ubuntu/
├── scripts/
│   ├── create-ubuntu-template.sh     # Creates Ubuntu Proxmox template
│   ├── build-and-deploy-ubuntu.sh    # End-to-end Ubuntu deployment
│   └── test-ubuntu-infrastructure.sh # Tests Ubuntu infrastructure
└── cloud-init/                       # Ubuntu cloud-init configurations
```

**Interface**: Uses shared network/storage config, provides standardized server templates

### Shared Infrastructure
```
shared/
├── lib/paths.sh                      # Path resolution library
└── config/
    ├── defaults.env                  # Default values for all platforms
    ├── network.yaml                  # Network IP ranges and settings
    └── storage.yaml                  # Storage pools and sizing
```

**Interface**: Provides common configuration and utilities to all platforms

## 🚀 Usage Examples

### Running Scripts from Anywhere

```bash
# From project root
ubuntu/scripts/create-ubuntu-template.sh

# From any subdirectory
../../ubuntu/scripts/create-ubuntu-template.sh

# All paths resolve correctly automatically
```

### Cross-Platform Script Calls

```bash
# In build-and-deploy-nixos-template.sh
nixos_iso_script="$(find_script "generate-nixos-iso.sh")"
template_script="$(find_script "create-proxmox-template.sh")"

"$nixos_iso_script" --environment dev
"$template_script" --proxmox-host core
```

### Using Shared Configuration

```bash
# Automatically loaded from shared/config/defaults.env
echo "Proxmox host: $PROXMOX_HOST"
echo "Storage pool: $STORAGE_POOL" 
echo "Network bridge: $NETWORK_BRIDGE"
```

## 🧪 Testing

Run the path resolution test to verify everything works:

```bash
scripts/test-path-resolution.sh
```

This validates:
- ✅ Path resolution working correctly
- ✅ All scripts found in expected locations  
- ✅ Shared configuration loading
- ✅ Directory structure is valid
- ✅ Cross-platform script discovery

## 🔄 Migration Notes

### What Changed
1. **NixOS scripts moved**: `scripts/` → `nixos/scripts/`
2. **Shared library added**: New `shared/lib/paths.sh`
3. **Centralized config**: New `shared/config/` directory
4. **Environment variables**: Standardized `K8S_INFRA_*` variables

### What Stayed the Same
- All script functionality unchanged
- Command-line interfaces unchanged
- Configuration file formats unchanged
- No breaking changes to existing workflows

### Backward Compatibility
- Old hardcoded paths still work (but deprecated)
- Environment variable overrides still respected
- Existing tfvars and configuration files unchanged