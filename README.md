# Homelab Kubernetes Infrastructure

This project provisions repeatable, multi-cluster Kubernetes environments using Terraform and NixOS on Proxmox.

## 🧩 Project Goals

- Provision dev and prod Kubernetes clusters automatically via Terraform
- Use NixOS for minimal, declarative OS configuration
- Maintain a reusable infrastructure-as-code foundation
- Automate cluster provisioning with GitLab CI/CD
- Apply DRY principles and use reusable modules
- Future phases will add NixOS cloud-init, Kubernetes installation, and GitOps

## 📁 Directory Structure

```
.
├── README.md                  # This file
├── README-prompt.md           # AI agent task prompts
├── terraform/
│   ├── main.tf                # Entry point for Terraform root module
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf             # Remote state backend config
│   ├── terraform.tfvars.example
│   ├── modules/
│   │   └── proxmox_vm/        # Reusable VM provisioning module
│   └── outputs.tf
├── .gitlab-ci.yml             # GitLab CI for Terraform automation
└── .gitignore
```

## 🚀 Clusters

- `dev-cluster`: 1 control plane, 2 workers
- `prod-cluster`: 3 control planes, 3 workers

## ✅ Phase 1 Progress

Phase 1 is focused on automating VM creation using Terraform, Proxmox, and AWS for state management. See [README-prompt.md](./README-prompt.md) for detailed task descriptions.
