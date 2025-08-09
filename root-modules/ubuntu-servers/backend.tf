terraform {
  backend "s3" {
    bucket       = "stetter-k8s-infra-terraform-state"
    key          = "ubuntu-servers/dev/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}