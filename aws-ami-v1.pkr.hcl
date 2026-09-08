packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region"       { type = string  default = "ap-south-1" }
variable "ami_version"  { type = string  default = "1.0.1" }
variable "build_number" { type = string  default = "local" }

locals {
  stamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "amazon-linux" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"

  ami_name        = "golden-al2023-${var.ami_version}-${var.build_number}-${local.stamp}"
  ami_description = "Golden base image: SSM Agent + CloudWatch Agent + Docker"
  ami_regions     = [var.region]

  # Always start from the newest patched Amazon Linux 2023
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-kernel-6.1-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name        = "golden-base-image"
    OS          = "AmazonLinux2023"
    Version     = var.ami_version
    BuildNumber = var.build_number
    BuiltBy     = "packer"
    CreatedOn   = local.stamp
  }
  snapshot_tags = {
    Name    = "golden-base-image"
    Version = var.ami_version
  }
  # tags the *temporary* builder instance, key pair and SG
  run_tags = {
    Name    = "packer-builder-temp"
    Purpose = "ami-bake"
  }
}

build {
  name    = "hq-packer"
  sources = ["source.amazon-ebs.amazon-linux"]

  provisioner "file" {
    source      = "provisioner.sh"
    destination = "/tmp/provisioner.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/provisioner.sh",
      "sudo /bin/bash -x /tmp/provisioner.sh",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
