packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "packer-nodejs-nginx-${local.timestamp}"
  instance_type = "t3.micro"
  region        = "us-east-2"
  source_ami    = "ami-0f5fcdfbd140e4ab7" 
  ssh_username  = "ubuntu"
  ssh_timeout   = "20m"
  associate_public_ip_address = true
}

build {
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    # Evita ventanas interactivas de Ubuntu
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "setup.sh"
  }
}