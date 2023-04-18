locals {
  image_name         = "UnrealAgent-Build-Windows"
  managed_image_name = "${lower(local.image_name)}-${local.image_version}"
  image_version      = formatdate("YYYY.MM.DDhhmmss", timestamp())
}

source "azure-arm" "build" {
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "5m"
  winrm_username = "packer"

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  os_type         = "Windows"
  image_publisher = var.source_image_publisher
  image_offer     = var.source_image_offer
  image_sku       = var.source_image_sku
  image_version   = var.source_image_version

  managed_image_resource_group_name = var.artifacts_resource_group
  managed_image_name                = local.image_name

  shared_image_gallery_destination {
    shared_image_gallery_timeout = "5h0m0s"
    subscription                 = var.subscription_id
    resource_group               = var.gallery_resource_group
    gallery_name                 = var.gallery_name
    image_name                   = local.image_name
    image_version                = local.image_version
    storage_account_type         = "Standard_LRS"
    replication_regions = [
      "ukwest"
    ]
  }

  build_resource_group_name = var.build_resource_group
  vm_size                   = "Standard_D4ds_v4"

  azure_tags = {
    source_image_version  = var.source_image_version
    gallery_image_version = local.image_version
    gallery_image_commit  = var.git_commit
  }
}

build {
  source "azure-arm.build" {}

  # Install Chocolatey: https://chocolatey.org/install#individual
  provisioner "powershell" {
    inline = ["Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"]
  }

  # Install Chocolatey packages
  provisioner "file" {
    source      = "${path.root}/files/packages.config"
    destination = "D:/packages.config"
  }

  provisioner "powershell" {
    inline = ["choco install --confirm D:/packages.config"]
    # See https://docs.chocolatey.org/en-us/choco/commands/install#exit-codes
    valid_exit_codes = [0, 3010]
  }

  # Azure PowerShell Modules
  provisioner "powershell" {
    script = "${path.root}/files/install-azure-powershell.ps1"
  }

  provisioner "windows-restart" {}

  # Generalize image using Sysprep
  # See https://www.packer.io/docs/builders/azure/arm#windows
  # See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/build-image-with-packer#define-packer-template
  provisioner "powershell" {
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while ($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
  }
}