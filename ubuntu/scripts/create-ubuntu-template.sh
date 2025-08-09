#!/bin/bash
# Ubuntu Template Creation Script for Proxmox
# Creates a Ubuntu 22.04 LTS cloud-init template for DevOps workloads

set -euo pipefail

# Load shared path resolution and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../shared/lib/paths.sh
source "$(dirname "$(dirname "$SCRIPT_DIR")")/shared/lib/paths.sh"

# Configuration variables (with shared config defaults)
TEMPLATE_ID="${TEMPLATE_ID:-9000}"
TEMPLATE_NAME="${TEMPLATE_NAME:-${UBUNTU_TEMPLATE_NAME}}"
VM_NAME="${VM_NAME:-ubuntu-25.04-template}"
UBUNTU_VERSION="${UBUNTU_VERSION:-25.04}"

# Ubuntu Cloud Image URL (25.04 Plucky Puffin)
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img"
UBUNTU_IMAGE_FILE="ubuntu-${UBUNTU_VERSION}-cloudimg-amd64.img"

# Execute Proxmox command via SSH
execute_proxmox_cmd() {
    local cmd="$1"
    local description="$2"

    echo "🔧 $description"
    
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "$cmd"; then
        echo "✅ $description completed"
        return 0
    else
        echo "❌ $description failed"
        return 1
    fi
}

echo "🚀 Creating Ubuntu ${UBUNTU_VERSION} template for Proxmox..."
echo "Template ID: ${TEMPLATE_ID}"
echo "Template Name: ${TEMPLATE_NAME}"
echo "Host: ${PROXMOX_HOST}"
echo "Node: ${PROXMOX_NODE}"
echo "Storage: ${STORAGE}"

# Check if template already exists
if ssh "$PROXMOX_USER@$PROXMOX_HOST" "pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEMPLATE_ID}/config" >/dev/null 2>&1; then
    echo "❌ Template ID ${TEMPLATE_ID} already exists!"
    echo "To recreate, first run: ssh $PROXMOX_USER@$PROXMOX_HOST 'qm destroy ${TEMPLATE_ID}'"
    exit 1
fi

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

echo "📥 Downloading Ubuntu ${UBUNTU_VERSION} cloud image..."
if ! wget -q --show-progress "${UBUNTU_IMAGE_URL}" -O "${UBUNTU_IMAGE_FILE}"; then
    echo "❌ Failed to download Ubuntu cloud image"
    exit 1
fi

echo "✅ Ubuntu image downloaded successfully"

# Upload image to Proxmox
echo "📤 Uploading image to Proxmox..."
if ! scp "${UBUNTU_IMAGE_FILE}" "$PROXMOX_USER@$PROXMOX_HOST:/tmp/${UBUNTU_IMAGE_FILE}"; then
    echo "❌ Failed to upload Ubuntu cloud image to Proxmox"
    exit 1
fi

echo "✅ Image uploaded to Proxmox successfully"

# Create the VM
execute_proxmox_cmd "qm create ${TEMPLATE_ID} \
  --name '${VM_NAME}' \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=${BRIDGE} \
  --serial0 socket \
  --vga serial0 \
  --ostype l26 \
  --cpu cputype=host \
  --scsihw virtio-scsi-pci" "Creating VM ${TEMPLATE_ID}"

execute_proxmox_cmd "qm importdisk ${TEMPLATE_ID} '/tmp/${UBUNTU_IMAGE_FILE}' ${STORAGE} --format raw" "Importing disk image"

execute_proxmox_cmd "qm set ${TEMPLATE_ID} --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0,cache=writeback,discard=on" "Attaching disk to VM"

execute_proxmox_cmd "qm set ${TEMPLATE_ID} --ide2 ${STORAGE}:cloudinit" "Adding cloud-init drive"

# Boot configuration
execute_proxmox_cmd "qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0" "Configuring boot settings"

# Enable QEMU guest agent
execute_proxmox_cmd "qm set ${TEMPLATE_ID} --agent enabled=1" "Enabling QEMU guest agent"

# Set cloud-init settings (will be overridden by Terraform)
execute_proxmox_cmd "qm set ${TEMPLATE_ID} --ciuser ubuntu" "Setting cloud-init user"
execute_proxmox_cmd "qm set ${TEMPLATE_ID} --cipassword \$(openssl passwd -6 ubuntu)" "Setting cloud-init password"
execute_proxmox_cmd "qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp" "Setting cloud-init network"

# Add cloud-init configuration if it exists
CLOUD_INIT_CONFIG="${K8S_INFRA_UBUNTU_DIR}/cloud-init/ubuntu-cloud-init.yml"
if [[ -f "${CLOUD_INIT_CONFIG}" ]]; then
    echo "📋 Found cloud-init configuration, copying to Proxmox..."
    # Copy cloud-init config to Proxmox snippets directory
    if scp "${CLOUD_INIT_CONFIG}" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/snippets/ubuntu-cloud-init.yml"; then
        execute_proxmox_cmd "qm set ${TEMPLATE_ID} --cicustom 'user=local:snippets/ubuntu-cloud-init.yml'" "Applying cloud-init configuration"
    else
        echo "⚠️  Failed to copy cloud-init configuration, skipping custom cloud-init"
    fi
fi

execute_proxmox_cmd "qm template ${TEMPLATE_ID}" "Converting VM to template"

echo "✅ Ubuntu template created successfully!"
echo ""
echo "Template Details:"
echo "  - ID: ${TEMPLATE_ID}"
echo "  - Name: ${TEMPLATE_NAME}"
echo "  - Node: ${PROXMOX_NODE}"
echo "  - Storage: ${STORAGE}"
echo "  - Ubuntu Version: ${UBUNTU_VERSION}"
echo ""
echo "🎯 Next steps:"
echo "1. Update your Terraform variables to use template: ${TEMPLATE_NAME}"
echo "2. Deploy servers with: cd root-modules/ubuntu-servers && terraform apply"
echo "3. Configure with Ansible using generated inventory"
echo ""
echo "📝 Template is ready for use with Terraform!"