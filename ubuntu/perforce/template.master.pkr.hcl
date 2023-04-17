locals {
  image_version      = formatdate("YYYY.MM.DDhhmmss", timestamp())
  image_offer        = "Perforce"
  image_sku          = "Master"
  image_os           = "Linux"
  image_name         = "${local.image_offer}-${local.image_sku}-${local.image_os}"
  managed_image_name = "${lower(local.image_name)}-${local.image_version}"
}

source "azure-arm" "master" {
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
  managed_image_name                = local.managed_image_name

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = local.image_name
    image_version        = local.image_version
    storage_account_type = "Standard_LRS"
    replication_regions = [
      "ukwest"
    ]
  }

  build_resource_group_name = var.build_resource_group
  vm_size                   = local.vm_size

  azure_tags = {
    os_type       = local.image_os
    os_version    = var.source_image_version
    build_version = local.image_version
  }
}

build {
  source "azure-arm.master" {}

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script          = "${path.root}/files/p4-install.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "mkdir -p /usr/local/bin/sdp",
      "mkdir -p /usr/local/bin/ansible",
    ]
  }

  provisioner "file" {
    content = templatefile("files/p4-cfg.pkrtpl.hcl", {
      INSTANCE    = 1
      SERVER_ID   = ""
      SERVER_TYPE = "p4d_master"
    })
    destination = "/tmp/p4-sdp.cfg"
  }

  provisioner "file" {
    content = templatefile("files/ansible-hosts.pkrtpl.hcl", {
      INSTANCE = 1
    })
    destination = "/tmp/ansible-hosts.ini"
  }

  provisioner "file" {
    sources = [
      # Services
      "${path.root}/files/p4-bootstrap.service",
      "${path.root}/files/ansible-configure-helix.service",
      "${path.root}/files/ansible-configure-helix.timer",
      # Ansible
      "${path.root}/files/ansible-configure-helix.sh",
      # P4
      "${path.root}/files/p4-bootstrap.sh",
      "${path.root}/files/p4-reset-sdp.sh"
    ]
    destination = "/tmp/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "mv /tmp/*.service /etc/systemd/system",
      "mv /tmp/*.timer /etc/systemd/system",
      "mv /tmp/p4-* /usr/local/bin/sdp",
      "mv /tmp/ansible-* /usr/local/bin/ansible",
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "mv /usr/local/bin/sdp/p4-reset-sdp.sh /usr/local/bin/sdp/reset_sdp.sh",
      "mv /usr/local/bin/sdp/p4-sdp.cfg /usr/local/bin/sdp/sdp.cfg",
      "mv /usr/local/bin/ansible/ansible-hosts.ini /usr/local/bin/ansible/hosts.ini"
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user",
      "export HISTSIZE=0",
      "sync"
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/output.json"
    strip_path = true
  }
}
