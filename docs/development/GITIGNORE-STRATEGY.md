# .gitignore Strategy

This document explains the consolidated .gitignore strategy for the k8s-infra project.

## Overview

The project uses a single, comprehensive `.gitignore` file at the root level instead of multiple scattered files to:

- **Reduce duplication**: Eliminate redundant ignore patterns across subdirectories
- **Improve maintainability**: Single source of truth for ignore patterns
- **Enhance security**: Comprehensive coverage of sensitive file patterns
- **Support development**: Cover all tools and IDEs used in infrastructure development

## Structure

The root `.gitignore` is organized into logical sections:

### 🏗️ Terraform
- State files (`.tfstate`, `.tfstate.*`)
- Terraform directories (`.terraform/`)
- Variable files (`*.tfvars`, `*.tfvars.json`)
- Plan files (`*.tfplan`)
- Override files (`override.tf`, `*_override.tf`)
- CLI configuration (`.terraformrc`, `terraform.rc`)

### 🔧 Generated Infrastructure Files
- SSH keys (`**/ssh_keys/`, `*.pem`, `*.key`)
- Generated inventory files (`**/inventory/hosts.*`)
- Generated kubeconfig files (`**/kubeconfig/`)
- Build artifacts (`build/`, `dist/`)
- Test environments (`test-vm/`)

### ☁️ Cloud and Container Images
- ISO files (`*.iso`)
- Container images (`*.tar`, `*.tar.gz`)
- VM disk images (`*.qcow2`, `*.vmdk`, `*.vdi`)

### 🔒 Secrets and Environment Files
- Environment variables (`.env`, `.env.*`)
- Secret files (`secrets/`, `*.secret`)
- Certificate files (`*.crt`, `*.cert`, `*.p12`)

### 💻 Development and IDE
- VS Code (selective ignore - keeps shareable configs)
- JetBrains IDEs (`.idea/`, `*.iml`)
- Vim (`*.swp`, `*.swo`)
- Emacs (`*~`, `\#*\#`)
- Sublime Text (`*.sublime-project`)

### 🖥️ Operating System
- macOS (`.DS_Store`, `.Spotlight-V100`)
- Windows (`Thumbs.db`, `Desktop.ini`)
- Linux (`*~`, `.fuse_hidden*`)

### 🐍 Languages and Frameworks
- Python (`__pycache__/`, `*.py[cod]`, `venv/`)
- Node.js (`node_modules/`, `npm-debug.log*`)
- Ansible (`*.retry`, `.ansible/`)
- NixOS (`result`, `result-*`)

### 📝 Logs and Temporary Files
- Log files (`*.log`, `logs/`)
- Temporary files (`*.tmp`, `*.backup`, `*.bak`)
- Cache directories (`.cache/`, `cache/`)

### 📚 Documentation Build
- Sphinx (`docs/_build/`)
- MkDocs (`site/`)

### 🎯 Project Specific
- Cloud-init generated files (keeps templates)
- Proxmox specific files (`*.qcow2`, `vm-*-disk-*`)
- Monitoring data (`prometheus/`, `grafana/data/`)

### 🛡️ Security
- Pattern-based secret detection (`*secret*`, `*token*`, `*password*`)
- Keeps example and template files (`!*secret*.example`)

## Key Improvements

### 🔄 Before (Multiple Files)
- `/terraform/.gitignore` (35 lines)
- `/root-modules/nixos-kubernetes/.gitignore` (35 lines)
- Root `.gitignore` (88 lines)
- **Total**: 158 lines across 3 files with significant duplication

### ✨ After (Single File)
- Root `.gitignore` (281 lines)
- **Total**: 281 lines in 1 file with comprehensive coverage

### Benefits:
1. **Eliminated Duplication**: Removed identical patterns across files
2. **Enhanced Security**: Added comprehensive secret detection patterns
3. **Better IDE Support**: Covers all major editors and IDEs
4. **Improved Maintainability**: Single file to update
5. **Project Awareness**: Specific patterns for infrastructure tools

## Directory Structure

The following directories have `.gitkeep` files to maintain structure:

```
root-modules/
├── template/
│   ├── inventory/.gitkeep
│   └── ssh_keys/.gitkeep
└── ubuntu-servers/
    ├── inventory/.gitkeep
    └── ssh_keys/.gitkeep
```

## Example and Template Files

The `.gitignore` uses negation patterns (`!`) to explicitly include:

- `*.tfvars.example` and `*.tfvars.template`
- `*.key.example` and `*.key.template`
- `*.env.example` and `*.env.template`
- `*secret*.example` and similar patterns

This ensures documentation and example files are always tracked while protecting actual secrets.

## Best Practices

### ✅ Do
- Use the comprehensive root `.gitignore`
- Add example/template files for sensitive configurations
- Use `.gitkeep` for empty directories that need to be tracked
- Test ignore patterns with `git check-ignore <file>`

### ❌ Don't
- Create additional `.gitignore` files in subdirectories (unless absolutely necessary)
- Commit actual secrets, tokens, or passwords
- Ignore entire directories if only specific files should be ignored

## Testing Ignore Patterns

Test if a file would be ignored:
```bash
git check-ignore path/to/file
```

List all ignored files:
```bash
git ls-files --others --ignored --exclude-standard
```

## Maintenance

When adding new tools or patterns:

1. Add to the appropriate section in root `.gitignore`
2. Use `**` patterns for recursive matching
3. Include both positive and negative patterns as needed
4. Document project-specific patterns in this file