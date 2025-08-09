terraform {
  backend "s3" {
    bucket       = "stetter-homelab-proxmox-iac-tf-state"
    key          = "nixos-kubernetes/dev/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
