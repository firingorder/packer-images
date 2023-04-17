locals {
  os_type       = "Linux"
  vm_size       = "Standard_B2s"
  image_version = formatdate("YYYY.MM.DDhhmmss", timestamp())
}