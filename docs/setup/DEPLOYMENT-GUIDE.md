# 🚀 Homelab Proxmox Infrastructure Deployment Guide

This guide walks you through deploying your complete homelab infrastructure from scratch.

## Prerequisites

- ✅ **Proxmox VE** server running and accessible via SSH
- ✅ **AWS Account** with CLI configured (`aws configure`)
- ✅ **Git repository** renamed and pushed to new location
- ✅ **SSH access** to Proxmox host (default: `root@core`)

## 📋 Overview

We'll deploy in this order:
1. **S3 Backend Setup** - Create Terraform state storage
2. **NixOS Template** - Kubernetes-ready template with ansible user
3. **Ubuntu Template** - DevOps-ready template with ansible user
4. **Infrastructure Deployment** - Deploy actual VMs using Terraform

---

## 1️⃣ Create S3 Backend

### Create the S3 Bucket
```bash
# This creates: stetter-homelab-proxmox-iac-tf-state
./scripts/create-s3-state-bucket.sh
```

**What this does:**
- Creates S3 bucket with versioning enabled
- Enables server-side encryption
- Creates DynamoDB table for state locking
- Sets proper permissions and lifecycle policies

### Set Up AWS IAM for GitLab CI/CD (Optional)
```bash
# Only needed if using GitLab CI/CD
./scripts/setup-gitlab-aws-iam.sh
```

**Verify S3 bucket creation:**
```bash
aws s3 ls stetter-homelab-proxmox-iac-tf-state
aws dynamodb describe-table --table-name homelab-proxmox-iac-tf-locks
```

---

## 2️⃣ Create NixOS Template

### Generate and Deploy NixOS Template
```bash
# This handles ISO generation and Proxmox template creation
./nixos/scripts/build-and-deploy-nixos-template.sh
```

**What this does:**
- Generates custom NixOS ISO with kubernetes packages pre-installed
- Creates Proxmox VM and auto-installs NixOS
- Converts to template (ID: 9000, Name: nixos-base-template)
- **Creates ansible user** with passwordless sudo
- Cleans up installer VM automatically
- Saves template info to `build/templates/base-template-info.json`

**Manual alternative (step-by-step):**
```bash
# Generate ISO only
./nixos/scripts/generate-nixos-iso.sh

# Create template from ISO
./nixos/scripts/create-proxmox-template.sh
```

**Verify template creation:**
```bash
# Check template exists in Proxmox
ssh root@core "qm list"
# Should show template with ID 9000
```

---

## 3️⃣ Create Ubuntu Template

### Generate and Deploy Ubuntu Template
```bash
# This downloads Ubuntu cloud image and creates Proxmox template
./ubuntu/scripts/create-ubuntu-template.sh
```

**What this does:**
- Downloads Ubuntu 25.04 cloud image
- Creates Proxmox VM with cloud-init configuration
- Converts to template (ID: 9001, Name: ubuntu-25.04-template)
- **Creates ubuntu user** with sudo access
- **Creates ansible user** with your SSH key: `ssh-ed25519 AAAAC3...ansible@ansible.slowplanet.net`
- Includes DevOps tools: Python, Docker, essential packages

**Manual verification:**
```bash
# Check template exists
ssh root@core "qm list"
# Should show template with ID 9001

# Verify cloud-init config was applied
ssh root@core "cat /var/lib/vz/snippets/ubuntu-cloud-init.yml"
```

---

## 4️⃣ Deploy Infrastructure with Terraform

Now you can deploy actual VMs using either project:

### Option A: Deploy Ubuntu Servers
```bash
cd terraform/projects/ubuntu-servers/

# Configure environment
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit dev.tfvars with your settings:
# - vm_template = "ubuntu-25.04-template"
# - server_count = 3
# - proxmox_api_token_id = "your-token"
# - proxmox_api_token_secret = "your-secret"

# Initialize and deploy
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Option B: Deploy NixOS Kubernetes Cluster
```bash
cd terraform/projects/nixos-kubernetes/

# Configure environment  
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit dev.tfvars with your settings:
# - vm_template = "nixos-base-template"
# - control_plane_count = 1
# - worker_count = 2

# Initialize and deploy
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### End-to-End Ubuntu Deployment
```bash
# This does template creation + terraform deployment in one command
./ubuntu/scripts/build-and-deploy-ubuntu.sh
```

---

## 🔧 Configuration Details

### S3 Backend Configuration
All projects now use:
- **Bucket**: `stetter-homelab-proxmox-iac-tf-state`
- **Region**: `us-east-2`
- **Encryption**: AES256
- **Versioning**: Enabled
- **Locking**: DynamoDB table

### Ansible User Configuration

**NixOS Templates:**
- User: `ansible`  
- Groups: `wheel`, `docker`
- Sudo: Passwordless
- SSH: Keys managed by cloud-init

**Ubuntu Templates:**
- User: `ansible`
- Groups: `sudo`
- Sudo: Passwordless  
- SSH: Dedicated key baked in: `ssh-ed25519 AAAAC3...ansible@ansible.slowplanet.net`

### Template IDs
- **NixOS**: 9000 (`nixos-base-template`)
- **Ubuntu**: 9001 (`ubuntu-25.04-template`)

---

## 🧪 Testing and Verification

### Test Templates
```bash
# Test Ubuntu infrastructure end-to-end
./ubuntu/scripts/test-ubuntu-infrastructure.sh

# Validate path resolution
./scripts/test-path-resolution.sh

# Clean up any orphaned installer VMs
./scripts/cleanup-orphaned-installer-vms.sh
```

### Test Ansible Connectivity
```bash
# Test SSH to deployed VMs
ssh ansible@<vm-ip>

# Test sudo access
ssh ansible@<vm-ip> "sudo whoami"  # Should return: root
```

### Verify State Storage
```bash
# Check state files
aws s3 ls s3://stetter-homelab-proxmox-iac-tf-state/ --recursive

# Should show:
# ubuntu-servers/dev/terraform.tfstate
# nixos-kubernetes/dev/terraform.tfstate
```

---

## 🚨 Troubleshooting

### Common Issues

**S3 Bucket Already Exists:**
```bash
# Choose a different name or region in scripts/create-s3-state-bucket.sh
export PROJECT_NAME="homelab-proxmox-iac-unique-suffix"
```

**Template ID Conflicts:**
```bash
# Destroy existing template first
ssh root@core "qm destroy 9000"  # or 9001
```

**Proxmox SSH Issues:**
```bash
# Verify SSH access
ssh root@core "pvesh get /version"

# Check API access
curl -k https://core:8006/api2/json/version
```

**Terraform State Issues:**
```bash
# Re-initialize backend
terraform init -reconfigure
```

### Recovery Commands

**Clean slate restart:**
```bash
# Destroy all VMs and templates
ssh root@core "qm list | grep -E '(9000|9001)' | awk '{print \$1}' | xargs -r -I {} qm destroy {}"

# Clear S3 state
aws s3 rm s3://stetter-homelab-proxmox-iac-tf-state/ --recursive

# Start over from step 1
```

---

## ✅ Success Checklist

- [ ] S3 bucket `stetter-homelab-proxmox-iac-tf-state` created
- [ ] NixOS template (9000) created with ansible user
- [ ] Ubuntu template (9001) created with ansible user  
- [ ] Terraform projects deploy successfully
- [ ] Ansible can SSH to deployed VMs
- [ ] Infrastructure state stored in S3

---

## 🎯 Next Steps

After successful deployment:

1. **Set up monitoring** with your preferred tools
2. **Configure backup strategies** for VMs and templates
3. **Implement GitLab CI/CD** for automated deployments
4. **Create Ansible playbooks** for application deployment
5. **Set up Kubernetes cluster** using the NixOS nodes

Your homelab infrastructure is now ready for production workloads! 🎉