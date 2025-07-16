# Kubernetes Infrastructure on Proxmox with Terraform

This Terraform module provisions a complete Kubernetes cluster infrastructure on Proxmox using the Telmate provider. This is part of a **massive experiment to use NixOS** for Kubernetes infrastructure, as outlined in the project roadmap.

## 🎯 Project Vision

This project is **Phase 1** of a multi-phase experiment to build a production-ready Kubernetes environment using:
- **Terraform** for infrastructure provisioning on Proxmox
- **NixOS** for immutable, declarative node configuration
- **GitLab CI/CD** for automation and GitOps workflows

## Features

- **Multi-node Kubernetes cluster** with configurable control plane and worker nodes
- **High availability** with optional load balancer (HAProxy + Keepalived)
- **Automated VM provisioning** using Proxmox VE
- **Cloud-init integration** for automated OS configuration (transitioning to NixOS)
- **SSH key generation** for secure access
- **Ansible inventory generation** for cluster configuration
- **Kubeconfig template** for kubectl access

## 🗺️ Roadmap Context

This Terraform module represents **Phase 1** of the deployment roadmap:

### Current Phase: Terraform + Proxmox Automation ✅
- ✅ Set up Terraform project using Telmate Proxmox provider
- ✅ Create reusable modules for VM provisioning
- ✅ Define infrastructure for dev and prod clusters
- 🔄 Configure S3 + DynamoDB backend for remote state
- 🔄 Automate Terraform plan/apply with GitLab CI

### Next Phases:
- **Phase 2**: NixOS Node Configuration with `nixos-generators`
- **Phase 3**: Kubernetes Installation via kubeadm or nix-k3s
- **Phase 4**: GitLab CI/CD Integration
- **Phase 5**: Nix Flakes and GitOps automation

## Prerequisites

1. **Proxmox VE** server with API access
2. **NixOS VM template** created with nixos-generators (Phase 2)
3. **Terraform** >= 1.0
4. **Proxmox API token** with sufficient permissions

### Proxmox Setup

1. Create a NixOS VM template (Phase 2 - using nixos-generators):
   ```bash
   # This will be implemented in Phase 2 using nixos-generators
   # For now, you can use a basic NixOS ISO and convert to template
   #
   # Example process (to be automated):
   # 1. Download NixOS ISO
   # 2. Create VM and install NixOS with cloud-init support
   # 3. Configure SSH keys and basic services
   # 4. Convert to template
   #
   # Template name should be: nixos-2311-cloud-init
   ```

2. Create API token in Proxmox:
   ```bash
   # In Proxmox web UI: Datacenter > Permissions > API Tokens
   # Create token: terraform@pve!terraform
   ```

## Quick Start

1. **Clone and configure**:
   ```bash
   cd terraform/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Proxmox details
   ```

2. **Initialize and plan**:
   ```bash
   terraform init
   terraform plan
   ```

3. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

4. **Access your cluster**:
   ```bash
   # SSH to control plane
   ssh -i ssh_keys/k8s_private_key.pem nixos@<control-plane-ip>
   
   # Use generated Ansible inventory
   ansible-playbook -i inventory/hosts.yml your-k8s-playbook.yml
   ```

## Configuration

### Cluster Sizing

The module supports flexible cluster configurations:

```hcl
# Development cluster (minimal)
control_plane_count = 1
worker_node_count   = 2
enable_load_balancer = false

# Production cluster (HA)
control_plane_count = 3
worker_node_count   = 5
enable_load_balancer = true
```

### Network Configuration

Configure your network settings in `terraform.tfvars`:

```hcl
# Network settings
network_bridge      = "vmbr0"
network_vlan        = null  # or specific VLAN ID
network_cidr        = "24"
network_gateway     = "192.168.1.1"
nameserver          = "8.8.8.8"

# IP allocation
control_plane_ip_base = "192.168.1.10"  # Results in .101, .102, .103
worker_node_ip_base   = "192.168.1.20"  # Results in .201, .202, .203
load_balancer_ip      = "192.168.1.100"
```

## Generated Files

After deployment, the module generates several useful files:

- `ssh_keys/k8s_private_key.pem` - SSH private key for cluster access
- `ssh_keys/k8s_public_key.pub` - SSH public key
- `inventory/hosts.yml` - Ansible inventory for cluster configuration
- `kubeconfig/kubeconfig-template.yml` - Kubeconfig template

## Outputs

The module provides comprehensive outputs for integration:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output control_plane_ips
terraform output worker_node_ips
terraform output ssh_commands
terraform output quick_start_info
```

## 🔮 Future: NixOS Integration

In **Phase 2**, this infrastructure will be enhanced with:

- **NixOS cloud-init ISOs** generated with `nixos-generators`
- **Declarative node configuration** with Nix expressions
- **Immutable infrastructure** with atomic updates
- **Nix-native Kubernetes** potentially using nix-k3s

The current Ubuntu-based cloud-init files in `cloud-init/` will be replaced with NixOS configurations in `nixos/`.

## Directory Structure

```
terraform/
├── main.tf                    # Main infrastructure definition
├── providers.tf               # Provider configurations
├── variables.tf               # Input variables
├── versions.tf                # Version constraints
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── modules/
│   └── proxmox_vm/            # Reusable VM module
└── templates/                 # Template files
    ├── inventory.tpl          # Ansible inventory template
    └── kubeconfig.tpl         # Kubeconfig template

# NixOS configurations are in ../nixos/
../nixos/
├── common/
│   └── configuration.nix      # Shared NixOS configuration
├── dev/
│   ├── control.nix           # Dev control plane config
│   └── worker.nix            # Dev worker config
└── prod/
    ├── control.nix           # Prod control plane config
    └── worker.nix            # Prod worker config
```

## Contributing

This is an experimental project exploring NixOS for Kubernetes infrastructure. Contributions and feedback are welcome as we progress through the roadmap phases.

## License

This project is part of a homelab experiment. Use at your own risk and adapt to your environment.

---

**Next Steps**: See `README-roadmap.md` for the complete multi-phase plan and `nixos/` directory for upcoming NixOS configurations.