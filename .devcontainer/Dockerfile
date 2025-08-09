# Infrastructure Development Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    curl \
    wget \
    gpg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    unzip \
    zip \
    jq \
    yq \
    tree \
    htop \
    vim \
    nano \
    # Network tools
    net-tools \
    iputils-ping \
    dnsutils \
    telnet \
    openssh-client \
    rsync \
    # Security tools
    openssl \
    gnupg \
    pass \
    # Python and pip
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # System libraries for Python packages
    libffi-dev \
    libssl-dev \
    libyaml-dev \
    # Version control
    git \
    git-lfs \
    # Cloud tools dependencies
    snapd \
    && rm -rf /var/lib/apt/lists/*

# Switch to vscode user for tool installations
USER vscode
WORKDIR /home/vscode

# Install tfenv (Terraform version manager)
RUN git clone https://github.com/tfutils/tfenv.git ~/.tfenv \
    && echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc \
    && echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.zshrc

# Install pyenv (Python version manager)
RUN curl https://pyenv.run | bash \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc \
    && echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc \
    && echo 'eval "$(pyenv init -)"' >> ~/.bashrc \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc \
    && echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc \
    && echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# Install specific Python version for infrastructure tools
ENV PATH="/home/vscode/.pyenv/bin:$PATH"
RUN eval "$(pyenv init -)" && pyenv install 3.11.7 && pyenv global 3.11.7

# Install Terraform latest version
ENV PATH="/home/vscode/.tfenv/bin:$PATH"
RUN ~/.tfenv/bin/tfenv install latest \
    && ~/.tfenv/bin/tfenv use latest

# Install Packer
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update && sudo apt install -y packer

# Install Ansible and infrastructure Python packages
RUN ~/.pyenv/versions/3.11.7/bin/pip install --user \
    ansible \
    ansible-lint \
    molecule \
    yamllint \
    jinja2-cli \
    netaddr \
    # Security scanners
    checkov \
    tfsec \
    terrascan \
    safety \
    bandit \
    # Cloud providers
    boto3 \
    botocore \
    # Infrastructure tools
    proxmoxer \
    requests \
    # Development tools
    black \
    pylint \
    flake8 \
    pytest \
    pre-commit \
    # Documentation
    mkdocs \
    mkdocs-material

# Install Node.js and npm for some tooling
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - \
    && sudo apt-get install -y nodejs

# Install additional security scanners
RUN npm install -g \
    @microsoft/sarif-web-component \
    eslint \
    markdownlint-cli2

# Install cloud CLIs
# AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && rm -rf awscliv2.zip aws/

# Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl and helm (if not already installed by features)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install NixOS tools
USER root
RUN curl -L https://nixos.org/nix/install | sh -s -- --daemon \
    && echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> /home/vscode/.bashrc \
    && echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> /home/vscode/.zshrc

# Install additional security tools
RUN wget -O - https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Install HashiCorp Vault CLI
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update && sudo apt install vault

# Install Nix package manager tools
USER vscode
RUN curl -L https://github.com/nix-community/nixos-generators/tarball/master | tar xz \
    && sudo mv nixos-generators-* /opt/nixos-generators \
    && sudo ln -s /opt/nixos-generators/nixos-generate /usr/local/bin/nixos-generate

# Set up Terraform plugin caching
RUN mkdir -p ~/.terraform.d/plugin-cache \
    && echo 'plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"' > ~/.terraformrc

# Set up git configuration templates
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global core.editor "code --wait"

# Create workspace directories
RUN mkdir -p ~/workspace/bin ~/workspace/scripts ~/workspace/configs

# Add local bin to PATH
RUN echo 'export PATH="$HOME/.local/bin:$HOME/workspace/bin:$PATH"' >> ~/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$HOME/workspace/bin:$PATH"' >> ~/.zshrc

# Install shell linters and formatters
USER root
RUN curl -fsSL https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz \
    | tar -xJ --strip-components=1 -C /usr/local/bin/ shellcheck-stable/shellcheck

RUN curl -fsSL https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64 \
    -o /usr/local/bin/shfmt && chmod +x /usr/local/bin/shfmt

# Install hadolint for Dockerfile linting
RUN wget -O /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint

# Install OPA and Conftest for policy testing
RUN curl -L -o opa https://openpolicyagent.org/downloads/v0.59.0/opa_linux_amd64_static \
    && chmod 755 ./opa && sudo mv opa /usr/local/bin/

RUN wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz \
    && tar xzf conftest_0.46.0_Linux_x86_64.tar.gz \
    && sudo mv conftest /usr/local/bin \
    && rm conftest_0.46.0_Linux_x86_64.tar.gz

USER vscode

# Set up oh-my-zsh with useful plugins (if zsh is installed)
RUN if [ -d "$HOME/.oh-my-zsh" ]; then \
        sed -i 's/plugins=(git)/plugins=(git terraform ansible docker kubectl helm aws azure)/g' ~/.zshrc; \
    fi

WORKDIR /workspace

# Default command
CMD ["zsh"]