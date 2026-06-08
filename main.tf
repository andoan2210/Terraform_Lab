###############################################################
# K8s on AWS — Terraform 1-Click
# Provider 1: hashicorp/aws   — EC2, ALB, VPC, IAM
# Provider 2: hashicorp/tls   — generate SSH key tự động
###############################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "tls" {}

###############################################################
# Provider 2 – TLS: generate SSH key pair tự động
###############################################################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/${var.project}-key.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0400"
}
