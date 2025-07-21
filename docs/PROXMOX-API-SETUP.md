# Proxmox API Token Setup for Terraform

This guide covers setting up API tokens in Proxmox VE with the proper permissions for Terraform automation.

## Overview

Terraform uses the Proxmox API to create and manage virtual machines. To secure this access, we'll create a dedicated user and API token with minimal required permissions.

## Prerequisites

- Proxmox VE server (tested with 7.x and 8.x)
- Administrative access to Proxmox web interface
- Basic understanding of Proxmox permissions model

## Step 1: Create a Terraform User

### Option A: Using Proxmox Web Interface

1. **Access Proxmox Web Interface**
   - Navigate to `https://your-proxmox-server:8006`
   - Log in with an administrator account

2. **Navigate to User Management**
   - Go to `Datacenter` → `Permissions` → `Users`
   - Click `Add` to create a new user

3. **Create User**
   - **User name**: `terraform@pve`
   - **Password**: Set a secure password (optional, we'll use tokens)
   - **Email**: Your email address
   - **Comment**: `Terraform automation user`
   - **Enabled**: ✅ Checked
   - Click `Add`

### Option B: Using CLI (SSH to Proxmox node)

```bash
# SSH to your Proxmox node
ssh root@your-proxmox-server

# Create the terraform user
pveum user add terraform@pve --comment "Terraform automation user"
```

## Step 2: Create Required Roles

We'll create a custom role with minimal permissions needed for VM management.

### Using Web Interface

1. **Navigate to Role Management**
   - Go to `Datacenter` → `Permissions` → `Roles`
   - Click `Create` to add a new role

2. **Create Terraform Role**
   - **Name**: `TerraformProvisioner`
   - **Privileges**: Select the following permissions:

#### Required Permissions

**VM Management:**
```
VM.Allocate    # Create/delete VMs
VM.Config.Disk # Configure VM disks
VM.Config.CPU  # Configure VM CPU
VM.Config.Memory # Configure VM memory
VM.Config.Network # Configure VM networking
VM.Config.Options # Configure VM options
VM.Monitor     # Monitor VM status
VM.PowerMgmt   # Start/stop/reset VMs
VM.Console     # Access VM console (optional)
```

**Storage Management:**
```
Datastore.AllocateSpace # Allocate disk space
Datastore.AllocateTemplate # Use VM templates
Datastore.Audit # Read storage information
```

**Resource Management:**
```
Pool.Allocate  # Use resource pools (if applicable)
SDN.Use        # Software Defined Networking (if used)
```

**System Information:**
```
Sys.Audit      # Read system information
```

### Using CLI

```bash
# Create the terraform role with required permissions
pveum role add TerraformProvisioner -privs "VM.Allocate,VM.Config.Disk,VM.Config.CPU,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Monitor,VM.PowerMgmt,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Sys.Audit"
```

## Step 3: Assign Permissions

### Using Web Interface

1. **Navigate to Permissions**
   - Go to `Datacenter` → `Permissions`
   - Click `Add` → `User Permission`

2. **Set Path and User**
   - **Path**: `/` (root path for datacenter-wide access)
   - **User**: `terraform@pve`
   - **Role**: `TerraformProvisioner`
   - **Propagate**: ✅ Checked (important!)
   - Click `Add`

### Using CLI

```bash
# Assign the role to the terraform user at the datacenter level
pveum aclmod / -user terraform@pve -role TerraformProvisioner
```

## Step 4: Create API Token

### Using Web Interface

1. **Navigate to API Tokens**
   - Go to `Datacenter` → `Permissions` → `API Tokens`
   - Click `Add`

2. **Create Token**
   - **User**: Select `terraform@pve`
   - **Token ID**: `terraform` (results in `terraform@pve!terraform`)
   - **Comment**: `Terraform automation token`
   - **Privilege Separation**: ✅ **Enabled** (recommended for security)
   - Click `Add`

3. **Save Token Secret**
   - ⚠️ **IMPORTANT**: Copy the token secret immediately
   - You won't be able to see it again
   - Store it securely (password manager, etc.)

### Using CLI

```bash
# Create API token
pveum user token add terraform@pve terraform --comment "Terraform automation token"

# The output will show the token secret - save it immediately!
```

## Step 5: Test API Access

### Using curl

⚠️ **Important**: Use single quotes to avoid shell interpretation of the `!` character:

```bash
# Test API access (replace with your values)
curl -k -H 'Authorization: PVEAPIToken=terraform@pve!terraform=YOUR_TOKEN_SECRET' \
  https://your-proxmox-server:8006/api2/json/version

# Expected response: JSON with Proxmox version information
# Example: {"data":{"version":"8.4.1","repoid":"xxxxxxxx"}}
```

**Common shell issues:**
```bash
# ❌ WRONG - Double quotes cause shell to interpret ! character
curl -k -H "Authorization: PVEAPIToken=terraform@pve!terraform=secret" ...

# ✅ CORRECT - Single quotes prevent shell interpretation
curl -k -H 'Authorization: PVEAPIToken=terraform@pve!terraform=secret' ...

# ✅ ALTERNATIVE - Escape the ! character
curl -k -H "Authorization: PVEAPIToken=terraform@pve\!terraform=secret" ...
```

### Using Terraform

Create a test configuration:

```hcl
# test.tf
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://your-proxmox-server:8006/api2/json"
  pm_api_token_id     = "terraform@pve!terraform"
  pm_api_token_secret = "YOUR_TOKEN_SECRET"
  pm_tls_insecure     = true
}

data "proxmox_vm_qemu" "test" {
  # This will test if we can read VM information
  count   = 0
  target_node = "your-node-name"
}
```

```bash
# Test the configuration
terraform init
terraform plan
```

## Step 6: Configure Terraform Variables

Update your `environments/dev.tfvars` or `environments/prod.tfvars`:

```hcl
# Proxmox Provider Configuration
proxmox_api_url          = "https://your-proxmox-server:8006/api2/json"
proxmox_api_token_id     = "terraform@pve!terraform"
proxmox_api_token_secret = "YOUR_ACTUAL_TOKEN_SECRET"
proxmox_tls_insecure     = true  # Set to false if you have valid SSL certs
```

## Security Best Practices

### 1. Token Management
- **Store tokens securely**: Use environment variables or secure vaults
- **Rotate tokens regularly**: Create new tokens periodically
- **Limit token scope**: Use privilege separation when possible

### 2. Network Security
- **Firewall rules**: Restrict API access to specific IP ranges
- **SSL/TLS**: Use valid certificates (set `pm_tls_insecure = false`)
- **VPN access**: Consider requiring VPN for API access

### 3. Monitoring
- **Audit logs**: Monitor API access in Proxmox logs
- **Failed attempts**: Watch for authentication failures
- **Resource usage**: Monitor for unexpected VM creation/deletion

## Environment Variables (Alternative)

Instead of storing secrets in tfvars files, use environment variables:

```bash
# Set environment variables
export PM_API_TOKEN_ID="terraform@pve!terraform"
export PM_API_TOKEN_SECRET="your-token-secret"
export PM_API_URL="https://your-proxmox-server:8006/api2/json"

# Remove from tfvars and let Terraform read from environment
```

## Troubleshooting

### Common Permission Issues

**Error: "Permission check failed"**
```
Solution: Ensure the role has all required permissions and propagate is enabled
```

**Error: "authentication failure" or "no tokenid specified"**
```
Solution: Check token ID format (user@realm!tokenid) and secret
Common cause: Shell interpreting ! character - use single quotes around the header
```

**Error: "SSL verification failed"**
```
Solution: Set pm_tls_insecure = true or install proper SSL certificates
```

### Verification Commands

```bash
# Check user exists
pveum user list | grep terraform

# Check role permissions
pveum role show TerraformProvisioner

# Check user permissions
pveum user permissions terraform@pve

# Check API tokens
pveum user token list terraform@pve
```

### Debug Mode

Enable debug logging in Terraform:

```bash
# Enable Proxmox provider debug logging
export TF_LOG=DEBUG
terraform plan
```

## Additional Permissions (If Needed)

Depending on your specific use case, you might need additional permissions:

### For Template Management
```
VM.Clone       # Clone templates
VM.Migrate     # Migrate VMs between nodes
```

### For Network Management (SDN)
```
SDN.Allocate   # Manage SDN resources
```

### For Backup Integration
```
VM.Backup      # Create/restore backups
```

### For Advanced Storage
```
Datastore.Allocate  # Manage storage allocations
```

## Summary

You should now have:

1. ✅ `terraform@pve` user created
2. ✅ `TerraformProvisioner` role with minimal required permissions
3. ✅ User assigned to role with datacenter-wide access
4. ✅ API token created with privilege separation
5. ✅ Token tested and working with Terraform

Your Terraform configuration can now securely manage Proxmox VMs with the principle of least privilege.

---

**Security Note**: Always use the minimal permissions required for your use case. Regularly audit and rotate API tokens. Never commit token secrets to version control.