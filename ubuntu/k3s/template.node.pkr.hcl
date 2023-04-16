source "azure-arm" "node" {
  # SSH
  ssh_username = "root"

  # Service Principal Authentication

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Source Image

  os_type         = local.os_type
  image_publisher = var.source_image_publisher
  image_offer     = var.source_image_offer
  image_sku       = var.source_image_sku
  image_version   = var.source_image_version

  # Destination Image

  managed_image_resource_group_name = var.artifacts_resource_group
  managed_image_name                = "k3s-node-${var.source_image_sku}-${var.source_image_version}"

  # Packer Computing Resources

  build_resource_group_name = var.build_resource_group
  vm_size                   = local.vm_size
}

build {
  source "azure-arm.node" {}

  provisioner "shell" {
    script = "files/k3s-install.sh"
    environment_vars = [
      "K3S_VERSION=${local.k3s_version}"
    ]
  }

  provisioner "shell" {
    inline = ["mkdir -p /usr/local/bin/k3s"]
  }

  provisioner "file" {
    sources = [
      "files/k3s-start.sh",
      "files/k3s-spot-helper.py",
      "files/k3s-stop.sh"
    ]
    destination = "/usr/local/bin/k3s"
  }

  provisioner "file" {
    source      = "files/k3s-config.yaml"
    destination = "/etc/rancher/k3s/config.yaml"
  }

  provisioner "file" {
    sources = [
      "files/k3s-start.service",
      "files/k3s-spot-helper.service",
      "files/k3s-stop.service",
    ]
    destination = "/etc/systemd/system/"
  }
}