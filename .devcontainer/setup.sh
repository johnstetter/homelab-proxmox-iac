#!/bin/bash
# DevContainer Post-Creation Setup Script

set -euo pipefail

echo "🚀 Setting up infrastructure development environment..."

# Source shell configuration
export PATH="/home/vscode/.tfenv/bin:/home/vscode/.pyenv/bin:/home/vscode/.local/bin:$PATH"

# Initialize pyenv
if [ -d "/home/vscode/.pyenv" ]; then
    eval "$(/home/vscode/.pyenv/bin/pyenv init -)"
fi

echo "📋 Environment Setup:"
echo "  - User: $(whoami)"
echo "  - Home: $HOME"
echo "  - Workspace: $(pwd)"

# Set up Terraform
echo "🔧 Setting up Terraform..."
if [ -x "/home/vscode/.tfenv/bin/terraform" ]; then
    terraform_version=$(/home/vscode/.tfenv/bin/terraform version | head -1)
    echo "  ✅ $terraform_version"
else
    echo "  ❌ Terraform not found"
fi

# Set up Python environment
echo "🐍 Setting up Python environment..."
if command -v pyenv >/dev/null 2>&1; then
    python_version=$(pyenv version | cut -d' ' -f1)
    echo "  ✅ Python $python_version (via pyenv)"
    
    # Upgrade pip and install additional packages if needed
    pip install --user --upgrade pip setuptools wheel
else
    echo "  ❌ pyenv not found"
fi

# Verify key tools
echo "🛠️  Verifying installed tools..."

tools=(
    "terraform:Terraform"
    "ansible:Ansible"
    "kubectl:Kubernetes CLI"
    "helm:Helm"
    "aws:AWS CLI"
    "az:Azure CLI"
    "docker:Docker"
    "git:Git"
    "jq:jq"
    "yq:yq"
    "shellcheck:ShellCheck"
    "shfmt:Shell formatter"
    "hadolint:Dockerfile linter"
    "checkov:Checkov security scanner"
    "tfsec:tfsec Terraform scanner"
    "trivy:Trivy security scanner"
    "vault:HashiCorp Vault"
)

for tool_info in "${tools[@]}"; do
    tool=$(echo "$tool_info" | cut -d':' -f1)
    name=$(echo "$tool_info" | cut -d':' -f2)
    
    if command -v "$tool" >/dev/null 2>&1; then
        version=$($tool --version 2>/dev/null | head -1 || echo "unknown")
        echo "  ✅ $name: $version"
    else
        echo "  ❌ $name: not found"
    fi
done

# Set up git hooks directory
echo "🎣 Setting up git hooks..."
mkdir -p .git/hooks
if [ -d "scripts/git-hooks" ]; then
    cp scripts/git-hooks/* .git/hooks/ 2>/dev/null || true
    chmod +x .git/hooks/* 2>/dev/null || true
    echo "  ✅ Git hooks installed"
else
    echo "  ℹ️  No git hooks directory found"
fi

# Install pre-commit if requirements exist
if [ -f ".pre-commit-config.yaml" ]; then
    echo "🔍 Installing pre-commit hooks..."
    pre-commit install
    echo "  ✅ Pre-commit hooks installed"
fi

# Set up SSH directory with proper permissions
echo "🔑 Setting up SSH configuration..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/config ~/.ssh/known_hosts
chmod 600 ~/.ssh/config ~/.ssh/known_hosts

# Add common SSH configurations for infrastructure work
cat > ~/.ssh/config << 'EOF'
# Infrastructure SSH Configuration
Host core
    HostName 192.168.1.100
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host pve
    HostName 192.168.1.100
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Default settings for all hosts
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
EOF

echo "  ✅ SSH configuration created"

# Create useful aliases
echo "📝 Setting up aliases..."
cat >> ~/.bashrc << 'EOF'

# Infrastructure Development Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias tf='terraform'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'
alias k='kubectl'
alias h='helm'
alias dc='docker-compose'
alias ans='ansible'
alias ansp='ansible-playbook'

# Security scanning aliases
alias tfscan='tfsec .'
alias checksec='checkov -d .'
alias trivy-fs='trivy fs .'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Navigation
alias cdw='cd /workspace'
alias cdt='cd /workspace/terraform'
alias cdr='cd /workspace/root-modules'
alias cds='cd /workspace/scripts'
EOF

# Copy aliases to zsh if it exists
if [ -f ~/.zshrc ]; then
    cat >> ~/.zshrc << 'EOF'

# Infrastructure Development Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias tf='terraform'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'
alias k='kubectl'
alias h='helm'
alias dc='docker-compose'
alias ans='ansible'
alias ansp='ansible-playbook'

# Security scanning aliases
alias tfscan='tfsec .'
alias checksec='checkov -d .'
alias trivy-fs='trivy fs .'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Navigation
alias cdw='cd /workspace'
alias cdt='cd /workspace/terraform'
alias cdr='cd /workspace/root-modules'
alias cds='cd /workspace/scripts'
EOF
fi

echo "  ✅ Aliases configured"

# Create useful scripts
echo "📜 Creating utility scripts..."
mkdir -p ~/workspace/bin

# Script to run all security scans
cat > ~/workspace/bin/scan-all << 'EOF'
#!/bin/bash
echo "🔍 Running comprehensive security scans..."

echo "📋 Terraform Security Scan (tfsec):"
if command -v tfsec >/dev/null 2>&1; then
    tfsec . --format table || true
else
    echo "  ❌ tfsec not available"
fi

echo ""
echo "🔒 Infrastructure Security Scan (checkov):"
if command -v checkov >/dev/null 2>&1; then
    checkov -d . --framework terraform --quiet || true
else
    echo "  ❌ checkov not available"
fi

echo ""
echo "🛡️  Container Security Scan (trivy):"
if command -v trivy >/dev/null 2>&1; then
    trivy fs . --security-checks vuln,config || true
else
    echo "  ❌ trivy not available"
fi

echo ""
echo "🐚 Shell Script Scan (shellcheck):"
if command -v shellcheck >/dev/null 2>&1; then
    find . -name "*.sh" -type f -exec shellcheck {} \; || true
else
    echo "  ❌ shellcheck not available"
fi

echo "✅ Security scans completed"
EOF

chmod +x ~/workspace/bin/scan-all

# Script to format all code
cat > ~/workspace/bin/format-all << 'EOF'
#!/bin/bash
echo "🎨 Formatting all code..."

echo "📋 Terraform format:"
if command -v terraform >/dev/null 2>&1; then
    terraform fmt -recursive .
    echo "  ✅ Terraform formatted"
else
    echo "  ❌ terraform not available"
fi

echo "🐚 Shell script format:"
if command -v shfmt >/dev/null 2>&1; then
    find . -name "*.sh" -type f -exec shfmt -w -i 4 {} \;
    echo "  ✅ Shell scripts formatted"
else
    echo "  ❌ shfmt not available"
fi

echo "🐍 Python format:"
if command -v black >/dev/null 2>&1; then
    black . || true
    echo "  ✅ Python formatted"
else
    echo "  ❌ black not available"
fi

echo "✅ Code formatting completed"
EOF

chmod +x ~/workspace/bin/format-all

echo "  ✅ Utility scripts created"

# Final setup
echo "🎯 Final setup..."

# Make sure permissions are correct
sudo chown -R vscode:vscode /home/vscode
find /home/vscode -type d -exec chmod 755 {} \;
find /home/vscode -type f -exec chmod 644 {} \;
chmod 700 /home/vscode/.ssh
chmod 600 /home/vscode/.ssh/* 2>/dev/null || true
chmod +x /home/vscode/workspace/bin/* 2>/dev/null || true

echo ""
echo "🎉 Infrastructure development environment setup complete!"
echo ""
echo "📚 Available tools:"
echo "  • tfenv - Terraform version manager"
echo "  • pyenv - Python version manager"
echo "  • Terraform, Ansible, kubectl, Helm"
echo "  • AWS CLI, Azure CLI"
echo "  • Security scanners: checkov, tfsec, trivy"
echo "  • Shell tools: shellcheck, shfmt"
echo "  • Utility scripts: scan-all, format-all"
echo ""
echo "🔧 Quick start:"
echo "  • tf init    - Initialize Terraform"
echo "  • scan-all   - Run security scans"
echo "  • format-all - Format all code"
echo ""
echo "Happy coding! 🚀"