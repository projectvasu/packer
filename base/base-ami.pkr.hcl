packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  default = "ap-south-2"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "base" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"
  ami_name      = "devops-lab-base-${local.timestamp}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  tags = {
    Name    = "devops-lab-base"
    BuiltBy = "Packer"
  }
}

build {
  sources = ["source.amazon-ebs.base"]

  provisioner "file" {
    source      = "files/amazon-cloudwatch-agent.json"
    destination = "/tmp/amazon-cloudwatch-agent.json"
  }

  provisioner "shell" {
    script = "scripts/install-software.sh"
  }

  provisioner "shell" {
    inline = [
      "echo '--- Verification ---'",
      "docker --version",
      "systemctl is-enabled amazon-ssm-agent",
      "systemctl is-enabled amazon-cloudwatch-agent",
      "test -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
    ]
  }
}
