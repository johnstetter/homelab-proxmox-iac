# Homelab Infrastructure Roadmap

## 🎯 Current Status: **MULTI-PLATFORM INFRASTRUCTURE**

This project provides a flexible infrastructure-as-code foundation supporting both NixOS Kubernetes clusters and Ubuntu server deployments with a modular root-modules architecture.

---

## ✅ **Implemented Features**

### **Root Modules Architecture**
- ✅ Modular root modules pattern for infrastructure separation
- ✅ Independent Terraform state files per infrastructure type
- ✅ Shared modules for code reuse across projects
- ✅ Standardized template for creating new projects
- ✅ Environment-specific configurations (dev/staging/prod)

### **Infrastructure Automation**
- ✅ Terraform projects with Telmate Proxmox provider  
- ✅ Reusable VM modules for provisioning
- ✅ SSH key generation and management per project
- ✅ Ansible inventory generation
- ✅ Flexible resource sizing and environment configurations

### **Ubuntu Server Infrastructure** 
- ✅ Ubuntu 25.04 cloud-init template automation
- ✅ Ansible-ready server deployments
- ✅ End-to-end deployment scripts
- ✅ DevOps tooling (Python 3, SSH, standard tools)
- ✅ Separate state management from K8s infrastructure

### **NixOS Template System**
- ✅ Automated NixOS ISO generation with `nixos-generators`
- ✅ Self-installing template with systemd auto-install service
- ✅ LVM partitioning with resize capabilities
- ✅ Cloud-init integration for post-deployment configuration
- ✅ NFS client support for shared storage integration

### **Storage and Networking**
- ✅ LVM-based storage with 20GB default (expandable)
- ✅ NFS mount integration (`/mnt/nfs` from Synology NAS)
- ✅ Bridge networking with DHCP
- ✅ SSH access with generated keys

### **Automation Scripts**
- ✅ `build-and-deploy-template.sh` - Complete pipeline
- ✅ `generate-nixos-iso.sh` - ISO creation
- ✅ `create-proxmox-template.sh` - Template deployment

---

## 🚀 **Next Steps (Future Enhancements)**

### **Kubernetes Installation**
- [ ] Kubernetes cluster initialization (kubeadm)
- [ ] CNI plugin deployment (Flannel/Calico)
- [ ] Role-specific node configuration

### **CI/CD Integration**
- [ ] GitLab CI pipeline for infrastructure updates
- [ ] Automated template rebuilds
- [ ] GitOps workflow implementation

### **Advanced Features**
- [ ] Multi-cluster management
- [ ] Nix flakes integration
- [ ] Backup and disaster recovery
- [ ] Monitoring and observability stack

---

## 🏗️ **Architecture Overview**

```
NixOS Template (base-template.nix)
├── Automated Installation (systemd service)
├── LVM Partitioning (/dev/sda -> VG -> LV)
├── NFS Client (Synology integration) 
├── Cloud-init Support
└── SSH Key Access

Terraform Infrastructure
├── SSH Key Generation
├── Control Plane VMs (1-3 nodes)
├── Worker Node VMs (2+ nodes)
├── Ansible Inventory Generation
└── Kubeconfig Template
```

This infrastructure provides a solid foundation for Kubernetes deployment with automated NixOS template creation and Terraform-based VM provisioning.
