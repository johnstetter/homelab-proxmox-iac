# Infrastructure Development Container

This devcontainer provides a complete development environment for infrastructure as code projects with Terraform, NixOS, Ubuntu, and cloud platforms.

## Features

### 🔧 Version Managers
- **tfenv** - Terraform version management
- **pyenv** - Python version management with Python 3.11.7

### 🏗️ Infrastructure Tools
- **Terraform** - Infrastructure as Code
- **Ansible** - Configuration management
- **Packer** - Image building
- **kubectl** - Kubernetes CLI
- **Helm** - Kubernetes package manager
- **NixOS generators** - NixOS system configuration

### ☁️ Cloud Platforms
- **AWS CLI** - Amazon Web Services
- **Azure CLI** - Microsoft Azure
- **HashiCorp Vault** - Secrets management

### 🔒 Security Scanners
- **checkov** - Infrastructure security scanner
- **tfsec** - Terraform security scanner
- **terrascan** - Multi-cloud security scanner
- **trivy** - Container and filesystem scanner
- **safety** - Python dependency scanner
- **bandit** - Python security linter

### 🛠️ Development Tools
- **shellcheck** - Shell script linter
- **shfmt** - Shell formatter
- **hadolint** - Dockerfile linter
- **yamllint** - YAML linter
- **ansible-lint** - Ansible playbook linter
- **black** - Python formatter
- **pylint** - Python linter
- **pre-commit** - Git pre-commit hooks

### 📊 Policy & Compliance
- **OPA (Open Policy Agent)** - Policy engine
- **conftest** - Policy testing

## Quick Start

1. **Open in VS Code**: Use "Remote-Containers: Reopen in Container"
2. **Wait for setup**: The container will automatically run setup scripts
3. **Start developing**: All tools are pre-configured and ready to use

## Useful Commands

### Terraform
```bash
tf init          # Initialize Terraform
tf plan          # Plan infrastructure changes
tf apply         # Apply changes
tf destroy       # Destroy infrastructure
tfv              # Validate configuration
tff              # Format code
```

### Security Scanning
```bash
scan-all         # Run all security scans
tfscan           # Terraform security scan
checksec         # Checkov infrastructure scan
trivy-fs         # Trivy filesystem scan
```

### Code Formatting
```bash
format-all       # Format all code
```

### Ansible
```bash
ans              # Ansible ad-hoc commands
ansp             # Ansible playbook
```

### Kubernetes
```bash
k                # kubectl
h                # helm
```

## Directory Structure

```
/workspace/
├── .devcontainer/       # Container configuration
├── terraform/           # Terraform configurations
├── root-modules/        # Terraform root modules
├── shared-modules/      # Shared Terraform modules
├── scripts/            # Shell scripts
├── ubuntu/             # Ubuntu configurations
├── nixos/              # NixOS configurations
└── docs/               # Documentation
```

## Environment Variables

- `TF_PLUGIN_CACHE_DIR` - Terraform plugin cache
- `ANSIBLE_HOST_KEY_CHECKING=False` - Skip SSH host key checking
- `PYTHONPATH=/workspace` - Python path
- Various tool paths added to `$PATH`

## SSH Configuration

The container includes SSH configuration for common infrastructure hosts:
- `core` - Proxmox server (192.168.1.100)
- `pve` - Proxmox alternative name

## VS Code Extensions

### Infrastructure
- HashiCorp Terraform
- Red Hat Ansible
- YAML support

### Security
- Snyk Vulnerability Scanner
- SARIF Viewer

### Development
- ShellCheck
- Shell Format
- GitLens
- Docker
- Python with linting/formatting

### NixOS
- Nix Language Support
- Nix IDE

## Port Forwards

The following ports are automatically forwarded:
- `8006` - Proxmox Web UI
- `8080` - General web services
- `3000` - Development servers
- `9090` - Monitoring (Prometheus)

## Volume Mounts

- `tf-plugin-cache` - Terraform plugin cache (persistent)
- `pyenv-cache` - Python environments (persistent)
- `ssh-keys` - SSH keys (persistent)

## Customization

### Adding Tools
Modify `.devcontainer/Dockerfile` to add additional tools.

### VS Code Settings
Update `.devcontainer/devcontainer.json` to modify VS Code configuration.

### Shell Configuration
The setup script adds useful aliases and functions to both bash and zsh.

## Troubleshooting

### Tool Not Found
If a tool is not found, check:
1. Path configuration in your shell
2. Tool installation in Dockerfile
3. Run `source ~/.bashrc` or `source ~/.zshrc`

### Permission Issues
All files should be owned by the `vscode` user. If you encounter permission issues:
```bash
sudo chown -R vscode:vscode /home/vscode
```

### Terraform Plugin Issues
Clear the plugin cache:
```bash
rm -rf ~/.terraform.d/plugin-cache/*
terraform init -upgrade
```

## Security Best Practices

1. **Never commit secrets** - Use environment variables or external secret managers
2. **Run security scans regularly** - Use the `scan-all` command
3. **Keep tools updated** - Rebuild the container periodically
4. **Use policy as code** - Implement OPA policies for compliance
5. **Enable pre-commit hooks** - Catch issues before commits

## Contributing

1. Test changes in the devcontainer
2. Run `format-all` to ensure consistent formatting
3. Run `scan-all` to check for security issues
4. Update documentation as needed