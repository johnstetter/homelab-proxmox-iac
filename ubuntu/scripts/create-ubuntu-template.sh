#!/bin/bash
# Ubuntu Template Creation Script for Proxmox
# Creates a Ubuntu 22.04 LTS cloud-init template for DevOps workloads

set -euo pipefail

# Configuration variables
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
TEMPLATE_ID="${TEMPLATE_ID:-9000}"
TEMPLATE_NAME="${TEMPLATE_NAME:-ubuntu-25.04-cloud-init}"
VM_NAME="${VM_NAME:-ubuntu-25.04-template}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
UBUNTU_VERSION="${UBUNTU_VERSION:-25.04}"

# Ubuntu Cloud Image URL (25.04 Plucky Puffin)
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img"
UBUNTU_IMAGE_FILE="ubuntu-${UBUNTU_VERSION}-cloudimg-amd64.img"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🚀 Creating Ubuntu ${UBUNTU_VERSION} template for Proxmox..."
echo "Template ID: ${TEMPLATE_ID}"
echo "Template Name: ${TEMPLATE_NAME}"
echo "Node: ${PROXMOX_NODE}"
echo "Storage: ${STORAGE}"

# Check if template already exists
if pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEMPLATE_ID}/config >/dev/null 2>&1; then
    echo "❌ Template ID ${TEMPLATE_ID} already exists!"
    echo "To recreate, first run: qm destroy ${TEMPLATE_ID}"
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

# Create the VM
echo "🔧 Creating VM ${TEMPLATE_ID}..."
qm create ${TEMPLATE_ID} \
  --name "${VM_NAME}" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=${BRIDGE} \
  --serial0 socket \
  --vga serial0 \
  --ostype l26 \
  --cpu cputype=host \
  --scsihw virtio-scsi-pci

echo "💾 Importing disk image..."
qm importdisk ${TEMPLATE_ID} "${UBUNTU_IMAGE_FILE}" ${STORAGE} --format raw

echo "🔗 Attaching disk to VM..."
qm set ${TEMPLATE_ID} --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0,cache=writeback,discard=on

echo "☁️  Adding cloud-init drive..."
qm set ${TEMPLATE_ID} --ide2 ${STORAGE}:cloudinit

echo "⚙️  Configuring VM settings..."
# Boot configuration
qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0

# Enable QEMU guest agent
qm set ${TEMPLATE_ID} --agent enabled=1

# Set cloud-init settings (will be overridden by Terraform)
qm set ${TEMPLATE_ID} --ciuser ubuntu
qm set ${TEMPLATE_ID} --cipassword $(openssl passwd -6 ubuntu)
qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp

# Add cloud-init configuration if it exists
CLOUD_INIT_CONFIG="${PROJECT_ROOT}/ubuntu/cloud-init/ubuntu-cloud-init.yml"
if [[ -f "${CLOUD_INIT_CONFIG}" ]]; then
    echo "📋 Found cloud-init configuration, copying to Proxmox..."
    # Copy cloud-init config to Proxmox snippets directory
    SNIPPETS_DIR="/var/lib/vz/snippets"
    if [[ -d "${SNIPPETS_DIR}" ]]; then
        cp "${CLOUD_INIT_CONFIG}" "${SNIPPETS_DIR}/ubuntu-cloud-init.yml"
        qm set ${TEMPLATE_ID} --cicustom "user=${STORAGE}:snippets/ubuntu-cloud-init.yml"
        echo "✅ Cloud-init configuration applied"
    else
        echo "⚠️  Snippets directory not found, skipping custom cloud-init"
    fi
fi

echo "📦 Converting VM to template..."
qm template ${TEMPLATE_ID}

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