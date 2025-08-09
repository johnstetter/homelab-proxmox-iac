#!/bin/bash
# One-time cleanup script for orphaned installer VMs
# These were created before the cleanup functionality was added

set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-core}"
PROXMOX_USER="${PROXMOX_USER:-root}"

# List of known orphaned installer VMs
INSTALLER_VMS=(9000 9002)

echo "🧹 Cleaning up orphaned installer VMs..."

for vm_id in "${INSTALLER_VMS[@]}"; do
    echo "Checking VM $vm_id..."
    
    # Check if VM exists and get its name
    if vm_info=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vm_id 2>/dev/null"); then
        vm_name=$(echo "$vm_info" | grep "^name:" | cut -d' ' -f2- || echo "unknown")
        
        # Check if it's an installer VM
        if [[ "$vm_name" == *"-installer" || "$vm_name" == *"installer"* ]]; then
            echo "  Found installer VM: $vm_id ($vm_name)"
            echo "  Destroying..."
            
            if ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm destroy $vm_id"; then
                echo "  ✅ Successfully removed VM $vm_id"
            else
                echo "  ❌ Failed to remove VM $vm_id"
            fi
        else
            echo "  ⚠️  VM $vm_id exists but doesn't appear to be an installer VM ($vm_name)"
            echo "     Skipping for safety"
        fi
    else
        echo "  ℹ️  VM $vm_id doesn't exist (already cleaned up)"
    fi
    echo
done

echo "✅ Cleanup complete!"