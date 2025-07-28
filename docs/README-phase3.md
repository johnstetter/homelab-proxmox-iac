# Phase 3 Developer's Guide: NixOS Native Kubernetes Deployment

This guide provides step-by-step instructions for implementing **Phase 3** of the NixOS Kubernetes experiment: deploying a complete Kubernetes cluster using NixOS's built-in `services.kubernetes` module - no kubeadm or manual installation required.

## 🎯 Phase 3 Objectives

- Deploy complete Kubernetes cluster using NixOS declarative configuration
- Leverage `services.kubernetes` module (NixOS's native kubeadm equivalent)
- Configure role-based deployments via cloud-init templates
- Enable automatic certificate management with `easyCerts`
- Set up multi-node cluster coordination
- Integrate seamlessly with existing Terraform infrastructure

## 🔑 Key Insight: NixOS IS the Installation Tool

**Traditional approach:** Install OS → install Docker → install kubeadm → kubeadm init → kubectl apply CNI  
**NixOS approach:** Configure `services.kubernetes` → `nixos-rebuild switch` → Done!

NixOS's `services.kubernetes` module provides:
- ✅ All Kubernetes components (kubelet, apiserver, etcd, etc.)
- ✅ Container runtime (containerd/docker) 
- ✅ CNI networking (Flannel built-in)
- ✅ Certificate management (automatic PKI)
- ✅ systemd service orchestration
- ✅ Multi-node cluster coordination

## 📋 Prerequisites

- **Phase 2** completed - base NixOS template available
- **Terraform infrastructure** deployed and functional
- **NixOS** understanding for service configuration
- **kubectl** access for cluster management

## 🏗️ Architecture Overview

### Cluster Components

**Control Plane Nodes:**
- kube-apiserver (port 6443)
- etcd cluster (ports 2379/2380)  
- kube-controller-manager
- kube-scheduler
- kubelet + kube-proxy

**Worker Nodes:**
- kubelet + kube-proxy
- containerd runtime
- CNI networking

**Network Layout:**
- Cluster CIDR: `10.244.0.0/16` (Pod networking)
- Service CIDR: `10.96.0.0/12` (Service networking)
- CNI: Flannel VXLAN (port 8472)

## 🚀 Phase 3 Implementation Steps

### Step 1: Create Role-Specific NixOS Configurations

Create Kubernetes configurations for different node roles:

```bash
# Create NixOS Kubernetes configurations
./scripts/create-k8s-configs.sh

# This creates:
# - nixos/roles/control-plane.nix
# - nixos/roles/worker.nix
# - templates cloud-init templates for role assignment
```

### Step 2: Update Terraform with Cloud-Init Templates

Configure Terraform to use role-specific cloud-init:

```bash
# Update Terraform module to use Kubernetes cloud-init
./scripts/update-terraform-k8s.sh

# This modifies:
# - terraform/modules/proxmox_vm/main.tf (add cloud-init templates)
# - terraform/variables.tf (add cluster configuration)
```

### Step 3: Deploy Control Plane Nodes

Deploy control plane with automatic Kubernetes setup:

```bash
cd terraform/
terraform apply -target=module.k8s_control_plane

# NixOS automatically:
# ✅ Installs all Kubernetes components
# ✅ Generates certificates (easyCerts)
# ✅ Starts etcd, apiserver, scheduler, controller-manager
# ✅ Enables Flannel CNI networking
# ✅ Creates systemd services
```

### Step 4: Deploy Worker Nodes

Deploy workers - they automatically join the cluster:

```bash
# Deploy worker nodes
terraform apply -target=module.k8s_workers

# NixOS automatically:
# ✅ Installs kubelet and kube-proxy
# ✅ Connects to control plane
# ✅ Joins cluster using shared certificates
# ✅ Sets up Flannel networking
```

### Step 5: Verify Cluster

Check that everything is working:

```bash
# Get kubeconfig from control plane
./scripts/get-kubeconfig.sh

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Run validation tests
./scripts/validate-k8s-cluster.sh
```

## 📁 New File Structure

After Phase 3 implementation:

```
k8s-infra/
├── nixos/
│   ├── base-template.nix          # Base template (unchanged)
│   ├── roles/
│   │   ├── control-plane.nix      # NixOS control plane config
│   │   └── worker.nix             # NixOS worker config
│   └── cloud-init/
│       ├── control-plane.yml      # Role assignment via cloud-init
│       └── worker.yml             # Role assignment via cloud-init
├── scripts/
│   ├── create-k8s-configs.sh      # Generate NixOS Kubernetes configs
│   ├── update-terraform-k8s.sh    # Update Terraform for K8s
│   ├── get-kubeconfig.sh          # Extract kubeconfig from cluster
│   └── validate-k8s-cluster.sh    # Test cluster functionality
├── terraform/
│   ├── modules/proxmox_vm/
│   │   └── main.tf                # Updated with K8s cloud-init
│   ├── variables.tf               # Added cluster variables
│   └── outputs.tf                 # Added kubeconfig output
└── docs/
    └── README-phase3.md
```

## 🔧 Configuration Details

### NixOS Native Kubernetes Configuration

**Control Plane Configuration (`nixos/roles/control-plane.nix`):**
```nix
{ config, pkgs, ... }:
{
  # Enable Kubernetes control plane
  services.kubernetes = {
    roles = ["master"];
    masterAddress = "control-plane-1.k8s.local";
    clusterCidr = "10.244.0.0/16";
    serviceCidr = "10.96.0.0/12";
    
    # Automatic certificate management
    easyCerts = true;
    
    # API server configuration
    apiserver = {
      advertiseAddress = "192.168.1.10";
      securePort = 6443;
    };
    
    # Built-in Flannel CNI
    flannel.enable = true;
  };
  
  # Open required ports
  networking.firewall.allowedTCPPorts = [ 6443 2379 2380 10250 10251 10252 ];
  networking.firewall.allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
}
```

**Worker Node Configuration (`nixos/roles/worker.nix`):**
```nix
{ config, pkgs, ... }:
{
  # Enable Kubernetes worker
  services.kubernetes = {
    roles = ["node"];
    masterAddress = "control-plane-1.k8s.local";
    
    # Kubelet configuration
    kubelet.extraOpts = "--fail-swap-on=false";
    
    # Built-in Flannel CNI
    flannel.enable = true;
    
    # Automatic certificate management
    easyCerts = true;
  };
  
  # Open required ports
  networking.firewall.allowedTCPPorts = [ 10250 ];
  networking.firewall.allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
}
```

### Cloud-Init Role Assignment

**Control Plane Cloud-Init (`nixos/cloud-init/control-plane.yml`):**
```yaml
#cloud-config
write_files:
  - path: /etc/nixos/k8s-role.nix
    content: |
      { ... }: {
        imports = [ ./roles/control-plane.nix ];
        networking.hostName = "control-plane-${instance_id}";
        networking.extraHosts = ''
          ${master_ip} control-plane-1.k8s.local
        '';
      }

runcmd:
  - ln -sf /etc/nixos/k8s-role.nix /etc/nixos/configuration.nix
  - nixos-rebuild switch
```

**Worker Cloud-Init (`nixos/cloud-init/worker.yml`):**
```yaml
#cloud-config
write_files:
  - path: /etc/nixos/k8s-role.nix
    content: |
      { ... }: {
        imports = [ ./roles/worker.nix ];
        networking.hostName = "worker-${instance_id}";
        networking.extraHosts = ''
          ${master_ip} control-plane-1.k8s.local
        '';
      }

runcmd:
  - ln -sf /etc/nixos/k8s-role.nix /etc/nixos/configuration.nix
  - nixos-rebuild switch
```

## 🧪 Testing Phase 3

### Validation Checklist

- [ ] All control plane nodes are in Ready state
- [ ] All worker nodes are in Ready state  
- [ ] etcd cluster is healthy (3+ members)
- [ ] API server is accessible on port 6443
- [ ] CoreDNS pods are running
- [ ] Flannel CNI is deployed and functional
- [ ] Pod-to-pod networking works across nodes
- [ ] Services can be created and reached
- [ ] Sample workload deploys successfully

### Manual Testing Commands

```bash
# Cluster health
kubectl cluster-info
kubectl get componentstatuses

# Node status
kubectl get nodes -o wide
kubectl describe nodes

# System pods
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel

# Networking test
kubectl run test-pod --image=nginx --rm -it -- /bin/bash
curl <service-ip>

# Workload test
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

## 🔄 Integration with Terraform

### Updated Variables

Add Kubernetes-specific variables to `terraform.tfvars`:

```hcl
# Kubernetes Configuration
cluster_name = "nixos-k8s"
cluster_cidr = "10.244.0.0/16"
service_cidr = "10.96.0.0/12"

# Control Plane
control_plane_count = 3
control_plane_memory = 4096
control_plane_cores = 2

# Workers  
worker_count = 3
worker_memory = 2048
worker_cores = 2

# CNI Selection
cni_plugin = "flannel"  # or "calico"
```

### Generated Outputs

Terraform will output cluster connection details:

```hcl
output "kubeconfig" {
  value = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name = var.cluster_name
    api_server   = "https://${module.k8s_control_plane[0].ip_address}:6443"
    ca_cert      = base64encode(file("${path.module}/certs/ca.crt"))
  })
}

output "cluster_info" {
  value = {
    api_server      = "https://${module.k8s_control_plane[0].ip_address}:6443"
    control_planes  = module.k8s_control_plane[*].ip_address
    workers        = module.k8s_workers[*].ip_address
    cluster_cidr   = var.cluster_cidr
    service_cidr   = var.service_cidr
  }
}
```

## 🛠️ Utility Scripts Reference

### `./scripts/create-k8s-configs.sh`
Creates NixOS Kubernetes configurations and cloud-init templates.

**Usage:**
```bash
./scripts/create-k8s-configs.sh [--cluster-name NAME] [--cluster-cidr CIDR]
```

**Creates:**
- `nixos/roles/control-plane.nix`
- `nixos/roles/worker.nix` 
- `nixos/cloud-init/control-plane.yml`
- `nixos/cloud-init/worker.yml`

### `./scripts/update-terraform-k8s.sh`
Updates Terraform configuration to use Kubernetes cloud-init templates.

**Usage:**
```bash
./scripts/update-terraform-k8s.sh
```

**Modifies:**
- Adds cloud-init template variables to `terraform/variables.tf`
- Updates `terraform/modules/proxmox_vm/main.tf` with role-specific cloud-init

### `./scripts/get-kubeconfig.sh`
Extracts kubeconfig from the control plane node.

**Usage:**
```bash
./scripts/get-kubeconfig.sh [--control-plane-ip IP] [--output-file PATH]
```

### `./scripts/validate-k8s-cluster.sh`
Tests cluster functionality and connectivity.

**Usage:**
```bash
./scripts/validate-k8s-cluster.sh [--kubeconfig PATH]
```

**Tests:**
- Node readiness
- Pod networking
- Service discovery
- DNS resolution

## 🐛 Troubleshooting

### Common Issues

**NixOS Service Issues:**
```bash
# Check Kubernetes service status
sudo systemctl status kubernetes-apiserver
sudo systemctl status kubernetes-scheduler
sudo systemctl status kubernetes-controller-manager

# Check kubelet logs
sudo journalctl -u kubelet -f

# Verify NixOS configuration
sudo nixos-rebuild dry-build
```

**Certificate Issues:**
```bash
# NixOS generates certs automatically with easyCerts
# Check certificate status
sudo ls -la /var/lib/kubernetes/secrets/

# Regenerate certificates (if needed)
sudo systemctl stop kubernetes-*
sudo rm -rf /var/lib/kubernetes/secrets/
sudo nixos-rebuild switch
```

**Networking Issues:**
```bash
# Check Flannel status (built into NixOS Kubernetes)
ip addr show flannel.1

# Verify firewall rules
sudo iptables -L -n

# Test connectivity
ping control-plane-1.k8s.local
```

## 🚀 Performance Optimization

### Resource Allocation

**Control Plane Sizing:**
- Development: 2 CPU, 4GB RAM
- Production: 4 CPU, 8GB RAM, 50GB storage

**Worker Node Sizing:**
- Small: 2 CPU, 4GB RAM
- Medium: 4 CPU, 8GB RAM  
- Large: 8 CPU, 16GB RAM

### Network Performance

**NixOS Flannel Configuration:**
```nix
# Built into services.kubernetes module
services.kubernetes.flannel = {
  enable = true;
  backend = "vxlan";
  network = "10.244.0.0/16";
};
```

**Alternative CNI (Advanced):**
```nix
# Disable built-in Flannel and use custom CNI
services.kubernetes.flannel.enable = false;
# Then deploy Calico/Cilium via kubectl after cluster setup
```

## 📚 Next Steps: Phase 4 - GitOps Application Platform

Once Phase 3 is complete, **Phase 4** will focus on GitOps-driven application deployment and promotion:

### 🎯 Phase 4 Objectives: GitOps with Flux

- **Bootstrap Flux v2** to both dev and prod clusters
- **Application deployment** via GitOps workflows  
- **Environment promotion** (dev → prod) with automated pipelines
- **Multi-cluster management** with cluster-specific configurations
- **Progressive delivery** with Flagger for canary deployments

### 🏗️ GitOps Architecture

**Repository Structure:**
```
k8s-apps/
├── clusters/
│   ├── dev/
│   │   ├── flux-system/
│   │   └── apps/
│   └── prod/
│       ├── flux-system/
│       └── apps/
├── apps/
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
└── infrastructure/
    ├── controllers/
    └── configs/
```

**Deployment Flow:**
1. **Dev Cluster**: Flux watches `main` branch → auto-deploys to dev
2. **Testing**: Automated tests validate dev deployments
3. **Promotion**: GitOps pipeline promotes successful builds to prod branch
4. **Prod Cluster**: Flux watches `prod` branch → controlled prod deployment

### 🛠️ Additional Platform Components

After GitOps foundation:
- **Monitoring**: Prometheus + Grafana (deployed via Flux)
- **Logging**: Loki stack (deployed via Flux)
- **Ingress**: nginx-ingress or Traefik (managed by Flux)
- **Secrets Management**: External Secrets Operator + Vault
- **Progressive Delivery**: Flagger for canary releases

## 📖 Additional Resources

- [NixOS Kubernetes Wiki](https://nixos.wiki/wiki/Kubernetes)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NixOS Services Reference](https://nixos.org/manual/nixos/stable/options.html#opt-services.kubernetes)
- [Flannel Documentation](https://github.com/flannel-io/flannel)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)

---

**Previous:** [Phase 2 - NixOS Base Template](./README-phase2.md)  
**Next:** Phase 4 - Advanced Cluster Features (future)