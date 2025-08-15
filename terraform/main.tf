# Образ Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

# Используем готовую сеть/подсеть default
data "yandex_vpc_network" "vpc" {
  name = "default"
}

data "yandex_vpc_subnet" "subnet" {
  name = "default-ru-central1-a" # замени, если у тебя другое имя в ru-central1-a
}

# Security group: 22/80/3000 наружу
resource "yandex_vpc_security_group" "sg" {
  name       = "allow-ssh-http-3000"
  network_id = data.yandex_vpc_network.vpc.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Две web-ВМ
resource "yandex_compute_instance" "web" {
  count = 2
  name  = "web-${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    ssh-keys  = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    user-data = <<-CLOUDCFG
      #cloud-config
      fqdn: web-${count.index + 1}
    CLOUDCFG
  }
}

# Одна proxy-ВМ
resource "yandex_compute_instance" "proxy" {
  name = "proxy-1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    ssh-keys  = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    user-data = <<-CLOUDCFG
      #cloud-config
      fqdn: proxy-1
    CLOUDCFG
  }
}

# Удобные значения
locals {
  web_ips  = [for i in yandex_compute_instance.web : i.network_interface[0].nat_ip_address]
  proxy_ip = yandex_compute_instance.proxy.network_interface[0].nat_ip_address
  ssh_key  = replace(var.ssh_public_key_path, ".pub", "")
}

# Inventory для Ansible
resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tftpl", {
    web_ips         = local.web_ips
    proxy_ip        = local.proxy_ip
    ssh_user        = var.ssh_user
    ssh_private_key = local.ssh_key
  })
}

# Переменные для роли proxy
resource "local_file" "proxy_vars" {
  filename = "${path.module}/../ansible/group_vars/proxy.yml"
  content  = <<-YAML
    upstream_ip: ${local.web_ips[0]}
  YAML
}
