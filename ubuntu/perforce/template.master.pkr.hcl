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
  managed_image_name                = "perforce-master-${var.source_image_sku}"

  build_resource_group_name = var.build_resource_group
  vm_size                   = local.vm_size
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
    destination = "/usr/local/bin/sdp/sdp.cfg"
  }

  provisioner "file" {
    source      = "${path.root}/files/p4-reset-sdp.sh"
    destination = "/usr/local/bin/sdp/reset_sdp.sh"
  }

  provisioner "file" {
    source      = "${path.root}/files/p4-bootstrap.sh"
    destination = "/usr/local/bin/sdp/"
  }

  provisioner "file" {
    source      = "${path.root}/files/ansible-configure-helix.sh"
    destination = "/usr/local/bin/ansible/"
  }

  provisioner "file" {
    content = templatefile("files/ansible-hosts.pkrtpl.hcl", {
      INSTANCE = 1
    })
    destination = "/usr/local/bin/ansible/hosts.ini"
  }

  provisioner "file" {
    sources = [
      "${path.root}/files/p4-bootstrap.service",
      "${path.root}/files/ansible-configure-helix.service",
      "${path.root}/files/ansible-configure-helix.timer",
    ]
    destination = "/etc/systemd/system/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user",
      "export HISTSIZE=0",
      "sync"
    ]
  }
}
