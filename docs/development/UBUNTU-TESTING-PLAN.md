# 🧪 Ubuntu Infrastructure Testing Plan

This testing plan validates the Ubuntu 25.04 server infrastructure, template creation, and Ansible integration capabilities.

## 🎯 Testing Overview

### **Scope**
- Ubuntu 25.04 template creation and automation
- Terraform deployment using root modules architecture
- Cloud-init configuration and server provisioning
- Ansible integration and connectivity
- End-to-end deployment workflows

### **Prerequisites**
- Proxmox VE environment with API access
- AWS S3 backend configured (see [S3-DYNAMODB-SETUP.md](S3-DYNAMODB-SETUP.md))
- Terraform and required tools installed
- Network connectivity to Proxmox and target VMs

## 🚀 **Phase 1: Template Creation Testing**

### **Test 1.1: Ubuntu Template Creation**
```bash
# Test template creation script
cd ubuntu/scripts/

# Run with test configuration
export TEMPLATE_ID=9001
export TEMPLATE_NAME="ubuntu-25.04-test"
export PROXMOX_NODE="core"
./create-ubuntu-template.sh
```

**Validation Steps:**
- [ ] Script downloads Ubuntu 25.04 cloud image successfully
- [ ] VM template appears in Proxmox web interface
- [ ] Template has correct configuration (cores, memory, disk)
- [ ] Cloud-init drive is properly attached
- [ ] Template can be cloned without errors

### **Test 1.2: Cloud-Init Configuration**
```bash
# Validate cloud-init configuration
cat ubuntu/cloud-init/ubuntu-cloud-init.yml

# Check syntax (requires cloud-init package)
cloud-init devel schema --config-file ubuntu/cloud-init/ubuntu-cloud-init.yml
```

**Validation Steps:**
- [ ] YAML syntax is valid
- [ ] Required packages are listed (python3, openssh-server, etc.)
- [ ] Security configuration is appropriate (UFW, SSH keys only)
- [ ] User configuration matches expectations

### **Test 1.3: Template Boot Test**
```bash
# Create test VM from template (run on Proxmox host via SSH)
ssh root@192.168.1.5 "qm clone 9001 9999 --name ubuntu-boot-test"
ssh root@192.168.1.5 "qm set 9999 --ciuser ubuntu --cipassword \$(openssl passwd -6 testpass)"
ssh root@192.168.1.5 "qm set 9999 --ipconfig0 ip=dhcp"
ssh root@192.168.1.5 "qm start 9999"

# Monitor boot process
ssh root@192.168.1.5 "qm status 9999"
```

**Validation Steps:**
- [ ] VM boots successfully from template
- [ ] Cloud-init completes without errors
- [ ] SSH service is running and accessible
- [ ] Required packages are installed

## 🏗️ **Phase 2: Terraform Deployment Testing**

### **Test 2.1: Configuration Validation**
```bash
cd root-modules/ubuntu-servers/

# Validate Terraform configuration
terraform validate
terraform fmt -check

# Check for syntax errors
terraform plan -var-file="environments/dev.tfvars"
```

**Validation Steps:**
- [ ] Terraform configuration is syntactically correct
- [ ] Variables are properly defined with validation rules
- [ ] Module sources resolve correctly
- [ ] Backend configuration is valid

### **Test 2.2: Minimal Deployment Test**
```bash
# Configure test environment
cp environments/dev.tfvars.example environments/test.tfvars
# Edit test.tfvars with minimal configuration:
# server_count = 1
# server_cores = 1
# server_memory = 1024

# Deploy single server
terraform init
terraform plan -var-file="environments/test.tfvars"
terraform apply -var-file="environments/test.tfvars" -auto-approve
```

**Validation Steps:**
- [ ] Terraform initializes with S3 backend
- [ ] Plan shows expected resource creation
- [ ] Single VM deploys successfully
- [ ] SSH keys are generated correctly
- [ ] Ansible inventory is created

### **Test 2.3: Multi-Server Deployment**
```bash
# Deploy multiple servers
# Edit test.tfvars: server_count = 3
terraform apply -var-file="environments/test.tfvars" -auto-approve

# Verify scaling
terraform output ubuntu_servers
terraform output server_ips
```

**Validation Steps:**
- [ ] Multiple VMs deploy successfully
- [ ] Each VM gets unique IP address
- [ ] All VMs are accessible via SSH
- [ ] Resource naming follows conventions
- [ ] Ansible inventory includes all servers

### **Test 2.4: Environment Separation**
```bash
# Test dev environment
terraform workspace select default
terraform apply -var-file="environments/dev.tfvars"

# Verify state separation (check S3 bucket)
aws s3 ls s3://stetter-homelab-proxmox-iac-tf-state/ubuntu-servers/
```

**Validation Steps:**
- [ ] Dev environment deploys independently
- [ ] State files are properly separated
- [ ] No interference between environments
- [ ] Resource naming includes environment prefix

## 🔧 **Phase 3: Server Provisioning Testing**

### **Test 3.1: SSH Connectivity**
```bash
cd root-modules/ubuntu-servers/

# Get connection commands
terraform output ssh_connection_commands

# Test SSH access to each server
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.51
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.52
```

**Validation Steps:**
- [ ] SSH keys have correct permissions (600)
- [ ] Can connect to all servers without password
- [ ] Ubuntu user has sudo privileges
- [ ] SSH connection is stable

### **Test 3.2: Cloud-Init Completion**
```bash
# On each server, check cloud-init status
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.51 \
  "sudo cloud-init status --long"

# Check cloud-init logs
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.51 \
  "sudo journalctl -u cloud-init"
```

**Validation Steps:**
- [ ] Cloud-init completed successfully
- [ ] All packages installed correctly
- [ ] UFW firewall is enabled and configured
- [ ] Python 3 and pip are available
- [ ] No errors in cloud-init logs

### **Test 3.3: System Configuration**
```bash
# Test installed packages and configuration
ssh -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.51 << 'EOF'
  python3 --version
  pip --version
  git --version
  curl --version
  jq --version
  sudo ufw status
  systemctl status ssh
  df -h
  free -h
EOF
```

**Validation Steps:**
- [ ] Python 3.x is installed and functional
- [ ] Essential DevOps tools are available
- [ ] UFW firewall allows SSH and blocks other ports
- [ ] SSH service is enabled and running
- [ ] Disk space and memory allocation are correct

## 📋 **Phase 4: Ansible Integration Testing**

### **Test 4.1: Inventory Validation**
```bash
cd root-modules/ubuntu-servers/

# Check generated inventory
cat inventory/hosts.yml

# Validate inventory syntax
ansible-inventory -i inventory/hosts.yml --list
```

**Validation Steps:**
- [ ] Inventory file is properly formatted YAML
- [ ] All servers are listed with correct IPs
- [ ] SSH configuration is included
- [ ] Group structure is logical

### **Test 4.2: Ansible Connectivity**
```bash
# Test basic Ansible connectivity
ansible all -i inventory/hosts.yml -m ping

# Test Python availability
ansible all -i inventory/hosts.yml -m setup -a "filter=ansible_python*"

# Test privilege escalation
ansible all -i inventory/hosts.yml -m command -a "whoami" --become
```

**Validation Steps:**
- [ ] All servers respond to ping module
- [ ] Python is detected correctly for Ansible
- [ ] Sudo works without password prompts
- [ ] Ansible can gather facts from all servers

### **Test 4.3: Ansible Playbook Test**
```bash
# Create simple test playbook
cat > test-playbook.yml << 'EOF'
---
- name: Test Ubuntu servers
  hosts: ubuntu_servers
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
        
    - name: Install test package
      apt:
        name: htop
        state: present
        
    - name: Create test file
      file:
        path: /tmp/ansible-test
        state: touch
        
    - name: Get system info
      command: uname -a
      register: system_info
      
    - name: Display system info
      debug:
        msg: "{{ system_info.stdout }}"
EOF

# Run test playbook
ansible-playbook -i inventory/hosts.yml test-playbook.yml
```

**Validation Steps:**
- [ ] Playbook runs without errors
- [ ] Package installation works correctly
- [ ] File creation succeeds on all servers
- [ ] System information is collected properly

## 🚀 **Phase 5: End-to-End Testing**

### **Test 5.1: Complete Automation Test**
```bash
# Test complete deployment automation
./ubuntu/scripts/build-and-deploy-ubuntu.sh -e test

# Verify deployment
cd root-modules/ubuntu-servers/
terraform output ubuntu_servers
ansible all -i inventory/hosts.yml -m ping
```

**Validation Steps:**
- [ ] Template creation completes successfully
- [ ] Terraform deployment succeeds
- [ ] All servers are accessible
- [ ] Ansible inventory works correctly

### **Test 5.2: Deployment Options Testing**
```bash
# Test plan-only mode
./ubuntu/scripts/build-and-deploy-ubuntu.sh -a plan

# Test template-skip mode
./ubuntu/scripts/build-and-deploy-ubuntu.sh -s

# Test terraform-skip mode
./ubuntu/scripts/build-and-deploy-ubuntu.sh -t
```

**Validation Steps:**
- [ ] Plan mode shows expected changes without applying
- [ ] Skip options work as expected
- [ ] Script provides clear status messages
- [ ] Error handling works correctly

### **Test 5.3: Cleanup Testing**
```bash
# Test infrastructure destruction
terraform destroy -var-file="environments/test.tfvars" -auto-approve

# Clean up template (optional)
ssh root@192.168.1.5 "qm destroy 9001"
```

**Validation Steps:**
- [ ] All VMs are destroyed successfully
- [ ] No orphaned resources remain
- [ ] State file is properly updated
- [ ] Template cleanup works if needed

## 🔍 **Performance and Scale Testing**

### **Test 6.1: Resource Scaling**
```bash
# Test with larger server count
# Edit test.tfvars: server_count = 5, cores = 2, memory = 2048
terraform apply -var-file="environments/test.tfvars"

# Measure deployment time
time terraform apply -var-file="environments/test.tfvars" -auto-approve
```

### **Test 6.2: Concurrent Operations**
```bash
# Test state locking
# Run terraform plan in two terminals simultaneously
terraform plan -var-file="environments/test.tfvars" &
terraform plan -var-file="environments/test.tfvars" &
```

### **Test 6.3: Network Performance**
```bash
# Test network connectivity between servers
ansible all -i inventory/hosts.yml -m shell \
  -a "ping -c 3 {{ hostvars[groups['ubuntu_servers'][0]]['ansible_host'] }}"
```

## 📊 **Monitoring and Validation**

### **Continuous Testing Checklist**
- [ ] **Template Creation**: Ubuntu template builds without errors
- [ ] **Terraform Validation**: Configuration passes validation
- [ ] **SSH Connectivity**: All servers accessible via SSH
- [ ] **Cloud-Init**: Completes successfully on all servers
- [ ] **Ansible Integration**: Inventory works and playbooks run
- [ ] **Resource Cleanup**: Destroy operations work correctly

### **Performance Metrics**
- Template creation time: `< 10 minutes`
- Single server deployment: `< 5 minutes`
- Multi-server deployment (3 servers): `< 8 minutes`
- SSH connection time: `< 5 seconds`
- Ansible ping response: `< 10 seconds`

### **Security Validation**
- [ ] SSH password authentication disabled
- [ ] UFW firewall enabled and configured
- [ ] Only required ports open (22/SSH)
- [ ] SSH keys have proper permissions
- [ ] No plain-text passwords in configurations

## 🚨 **Troubleshooting Common Issues**

### **Template Creation Failures**
```bash
# Check template status
ssh root@192.168.1.5 "pvesh get /nodes/core/qemu/9001/config"

# Check image download
ssh root@192.168.1.5 "ls -la /tmp/ubuntu-*"

# Verify storage permissions
ssh root@192.168.1.5 "pvesh get /nodes/core/storage"
```

### **Terraform Deployment Issues**
```bash
# Debug terraform
export TF_LOG=DEBUG
terraform apply -var-file="environments/test.tfvars"

# Check provider status
terraform providers

# Validate state
terraform state list
```

### **SSH Connection Problems**
```bash
# Check SSH key permissions
ls -la ssh_keys/
chmod 600 ssh_keys/ubuntu_private_key.pem

# Test with verbose SSH
ssh -v -i ssh_keys/ubuntu_private_key.pem ubuntu@192.168.1.51

# Check cloud-init status on server
# (via Proxmox console if needed)
```

### **Ansible Connectivity Issues**
```bash
# Check inventory syntax
ansible-inventory -i inventory/hosts.yml --list --yaml

# Test with verbose output
ansible all -i inventory/hosts.yml -m ping -vvv

# Check Python path
ansible all -i inventory/hosts.yml -m setup -a "filter=ansible_python_interpreter"
```

## 📝 **Test Results Documentation**

Create a test results file to track your testing:

```bash
# Create test results log
echo "# Ubuntu Infrastructure Test Results - $(date)" > test-results.md
echo "## Template Creation: PASS/FAIL" >> test-results.md  
echo "## Terraform Deployment: PASS/FAIL" >> test-results.md
echo "## SSH Connectivity: PASS/FAIL" >> test-results.md
echo "## Ansible Integration: PASS/FAIL" >> test-results.md
```

This comprehensive testing plan ensures your Ubuntu infrastructure is reliable, secure, and ready for production use! 🚀