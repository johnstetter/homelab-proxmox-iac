# README-roadmap.md

## 🛠️ Deployment Roadmap

This roadmap outlines the full plan for building a multi-cluster Kubernetes environment using Terraform and NixOS on Proxmox.

---

### **Phase 1: Terraform + Proxmox Automation**

- [ ] Set up Terraform project using Telmate Proxmox provider
- [ ] Define VM templates for NixOS using cloud-init ISOs
- [ ] Create reusable modules for VM provisioning
- [ ] Create clusters:
  - `dev-cluster` (1 control plane, 2 workers)
  - `prod-cluster` (3 control planes, 3+ workers)
- [ ] Configure S3 + DynamoDB backend for remote state
- [ ] Automate Terraform plan/apply with GitLab CI

---

### **Phase 2: NixOS Node Configuration**

- [ ] Generate cloud-init NixOS ISOs using `nixos-generators`
- [ ] Preconfigure NixOS with `kubelet`, `containerd`, sysctl, CNI
- [ ] Use Flannel or Calico as the default CNI
- [ ] Write reusable NixOS modules for node roles

---

### **Phase 3: Kubernetes Installation**

- [ ] Install Kubernetes via Kubespray or kubeadm
- [ ] Optionally evaluate nix-k3s for Nix-native setup
- [ ] Ensure multi-node HA support for prod cluster

---

### **Phase 4: GitLab CI/CD Integration**

- [ ] Store code in GitLab repo with `.gitlab-ci.yml`
- [ ] Run terraform plan/apply via CI
- [ ] Optional: build and store cloud-init ISOs automatically
- [ ] Optional: deploy GitLab Runner inside homelab

---

### **Phase 5: Bonus Enhancements**

- [ ] Use nix flake + `nixos-rebuild switch --flake`
- [ ] Add `direnv`, `lorri`, or `nix-shell` for local dev
- [ ] Explore GitOps automation for cluster bootstrapping

---

## 📁 Suggested Directory Layout

```
infra/
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf
│   ├── terraform.tfvars.example
│   ├── outputs.tf
│   └── modules/
│       └── proxmox_vm/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── nixos/
│   ├── common/
│   │   └── configuration.nix
│   ├── dev/
│   │   └── control.nix
│   │   └── worker.nix
│   └── prod/
│       └── control.nix
│       └── worker.nix
├── .gitlab-ci.yml
├── README.md
├── README-roadmap.md
└── README-prompt.md
```
