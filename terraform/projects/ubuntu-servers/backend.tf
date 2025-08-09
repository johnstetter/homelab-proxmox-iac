terraform {
  backend "s3" {
    bucket       = "stetter-homelab-proxmox-iac-tf-state"
    key          = "ubuntu-servers/dev/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}