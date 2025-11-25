packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/azure"
    }
  }
 
}

variable "arm_client_id" {}
variable "arm_client_secret" {}
variable "arm_tenant_id" {}
variable "arm_subscription_id" {}

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

source "azure-arm" "ubuntu_azure" {
  // Asegúrate de definir estas variables de entorno en tu terminal
  // export ARM_CLIENT_ID="..."
  // --- SINTAXIS CORREGIDA PARA PACKER v1.14.3 ---
  client_id                = "${var.arm_client_id}"
  client_secret            = "${var.arm_client_secret}"
  tenant_id                = "${var.arm_tenant_id}"
  subscription_id          = "${var.arm_subscription_id}"

  // Configuración de la Imagen Final
  managed_image_resource_group_name = "RG-Packer-Images" 
  managed_image_name              = "packer-nodejs-nginx-${local.timestamp}"
  location                        = "East US"
  
  // Configuración del Build Temporal
  os_type                         = "Linux"
  image_publisher                 = "Canonical"
  image_offer                     = "0001-com-ubuntu-server-focal" // Ubuntu 20.04 LTS
  image_sku                       = "20_04-lts-gen2"
  vm_size                         = "Standard_D2s_v3" // VM temporal para la construcción
  
  // Configuración de SSH
  ssh_username                    = "azureuser"

  // Recursos temporales que Packer limpiará
  // El nombre de un RG para los recursos temporales (opcional, pero recomendado)
  temp_resource_group_name        = "Packer-Build-Temp-RG"
}
build {
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu_azure"
  ]

  provisioner "shell" {
    # Evita ventanas interactivas de Ubuntu
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "setup.sh"
  }
}