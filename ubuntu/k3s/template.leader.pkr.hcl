source "azure-arm" "leader" {
  ssh_username = "root"

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  os_type         = local.os_type
  image_publisher = var.source_image_publisher
  image_offer     = var.source_image_offer
  image_sku       = var.source_image_sku
  image_version   = var.source_image_version

  managed_image_resource_group_name = var.artifacts_resource_group
  managed_image_name                = "k3s-leader-${var.source_image_sku}"

  build_resource_group_name = var.build_resource_group
  vm_size                   = local.vm_size
}

build {
  source "azure-arm.leader" {}

  provisioner "shell" {
    script = "files/k3s-install.sh"
    environment_vars = [
      "K3S_VERSION=${local.k3s_version}"
    ]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /usr/local/bin/k3s",
      "mkdir -p /usr/local/bin/ansible",
    ]
  }

  provisioner "file" {
    sources = [
      "files/k3s-start.sh",
      "files/k3s-bootstrapper.py",
    ]
    destination = "/usr/local/bin/k3s"
  }

  provisioner "file" {
    source      = "files/k3s-config.yaml"
    destination = "/etc/rancher/k3s/config.yaml"
  }

  provisioner "file" {
    source      = "files/ansible-configure-k3s.sh"
    destination = "/usr/local/bin/ansible/"
  }

  provisioner "file" {
    content     = templatefile("files/ansible-hosts.pkrtpl.hcl", {})
    destination = "/usr/local/bin/ansible/hosts.ini"
  }

  provisioner "file" {
    sources = [
      "files/k3s-start.service",
      "files/k3-bootstrapper.service",
      "files/ansible-configure-k3s.service",
      "files/ansible-configure-k3s.timer"
    ]
    destination = "/etc/systemd/system/"
  }
}