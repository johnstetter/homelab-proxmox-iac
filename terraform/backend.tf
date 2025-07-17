terraform {
  backend "s3" {
    bucket         = var.backend_bucket_name
    key            = var.backend_key
    region         = var.backend_region
    dynamodb_table = var.backend_dynamodb_table
    encrypt        = var.backend_encrypt
  }
}
