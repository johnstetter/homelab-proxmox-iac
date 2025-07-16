# README-prompt.md

This file provides AI agents with task-specific prompts to accomplish Phase 1: Terraform + Proxmox Automation.

---

## ✅ Task 1: feat(terraform): create root module for kubernetes clusters

**Prompt:**  
Create a root Terraform module that initializes the project for Kubernetes infrastructure provisioning on Proxmox using the Telmate provider. Include `main.tf`, `providers.tf`, `versions.tf`, and `terraform.tfvars.example`. Add `.gitignore` and `README.md`.

---

## ✅ Task 2: feat(terraform): configure S3 and DynamoDB backend for remote state

**Prompt:**  
Configure a remote Terraform backend using AWS. Create a `backend.tf` file that points to an existing S3 bucket and DynamoDB table for state locking and storage.

---

## ✅ Task 3: feat(terraform): create reusable proxmox_vm module

**Prompt:**  
Create a reusable Terraform module named `proxmox_vm` that provisions a VM via Proxmox with variables for name, CPU, memory, disk, ISO path, and network. Use cloud-init for provisioning and output the VM ID, IP, and name.

---

## ✅ Task 4: feat(terraform): define dev cluster topology (1 control, 2 workers)

**Prompt:**  
Use the `proxmox_vm` module to provision a development cluster with 1 control plane VM and 2 worker VMs. Ensure unique names and tags for later automation.

---

## ✅ Task 5: feat(terraform): define prod cluster topology (3 control, 3 workers)

**Prompt:**  
Define a production Kubernetes cluster topology with 3 control plane and 3 worker VMs using the reusable module.

---

## ✅ Task 6: chore(terraform): add basic DRY support with locals and count

**Prompt:**  
Refactor Terraform configuration to use `locals.tf` for shared config, and use `count` to provision multiple VMs cleanly. Add a variable like `cluster_type` to switch between dev/prod.

---

## ✅ Task 7: ci(gitlab): set up GitLab pipeline for Terraform plan/apply

**Prompt:**  
Create a `.gitlab-ci.yml` pipeline with `plan`, `apply`, and `destroy` stages. Use GitLab CI variables for secrets and support Terraform linting.

---

## ✅ Task 8: feat(terraform): define outputs for inventory and automation

**Prompt:**  
Add output blocks to Terraform to emit hostnames, roles, and IP addresses for future Kubernetes automation or Ansible inventory use.

---

## ✅ Task 9: docs(terraform): document cluster layout and usage

**Prompt:**  
Create a `README.md` in the root module that documents the project structure, usage instructions, backend setup, and cluster topology.

---
