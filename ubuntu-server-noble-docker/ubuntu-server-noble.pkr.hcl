#######################################################################
# Ubuntu Server Noble (24.04.x)
# ---
# Packer Template to create an Ubuntu Server (Noble 24.04.x) on Proxmox
#######################################################################

#######################################################################
# REQUIREMENTS
#######################################################################
packer {
  required_plugins {
    proxmox-iso = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

#######################################################################
# VARIABLE DEFINITIONS
#######################################################################
# Proxmox env variables
variable "proxmox_api_url" {
  type = string
}
variable "proxmox_api_token_id" {
  type = string
}
variable "proxmox_node" {
  type = string
}
# Secret variables
variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}
variable "ssh_username" {
  type = string
}
variable ssh_priv_key_path {
  type = string
}
# VM env variables
variable "vm_id" {
  type = string
}
variable "iso_storage_pool" {
  type = string
}
variable "iso_file" {
  type = string
}
variable "iso_checksum" {
  type    = string
  default = "none"
}
variable "disk_storage" {
  type = string
}
variable "network_interface_bridge" {
  type = string
}
variable "network_vlan_id" {
  type    = string
  default = ""
}

variable "cores" {
  type    = string
  default = "2"
}

variable "memory_size" {
  type    = string
  default = "2048"
}

variable "disk_size" {
  type    = string
  default = "25G"
}

variable "vm_domain" {
  type = string
  default = "localhost"
}

#######################################################################
# SOURCE DEFINITIONS
#######################################################################
source "proxmox-iso" "ubuntu-server-noble" {

  #############################
  # Proxmox Connection Settings
  #############################
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"

  # (Optional) Skip TLS Verification
  insecure_skip_tls_verify = true

  #############################
  # VM General Settings
  #############################
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "ubuntu-server-2404-noble-docker-template"
  template_name        = "ubuntu-server-2404-noble-small-template"
  template_description = "Ubuntu Server 24.04 (Noble) Image"

  #############################
  # VM ISO Settings
  #############################
  # (Option 1) Local ISO File
  boot_iso {
    type              = "ide"
    index             = 0
    iso_file          = "${var.iso_storage_pool}:${var.iso_file}"
    unmount           = true
    keep_cdrom_device = false
    iso_checksum      = var.iso_checksum
  }

  #############################
  # VM System Settings
  #############################
  qemu_agent      = true
  bios            = "seabios"
  machine         = "q35"
  boot            = "order=scsi0;net0;ide0"
  scsi_controller = "virtio-scsi-single"

  #############################
  # VM Hard Disk Settings
  #############################
  disks {
    disk_size    = var.disk_size
    format       = "raw"
    storage_pool = var.disk_storage
    type         = "scsi"
  }

  #############################
  # VM Resource Settings
  #############################
  # VM CPU Settings
  cores = var.cores

  # VM Memory Settings
  memory = var.memory_size

  #############################
  # VM Network Interface Settings
  #############################
  network_adapters {
    model    = "virtio"
    bridge   = var.network_interface_bridge
    firewall = "false"
    vlan_tag = var.network_vlan_id
  }

  #############################
  # VM Cloud-Init Settings
  #############################
  cloud_init              = true
  cloud_init_storage_pool = var.iso_storage_pool
  additional_iso_files {
    type              = "ide"
    index             = 1
    iso_storage_pool  = var.iso_storage_pool
    unmount           = true
    keep_cdrom_device = false
    cd_files = [
      "${path.root}/cloud-init/meta-data",
      "${path.root}/cloud-init/user-data"
    ]
    # Cloud-init specification looks for a drive labelled 'CIDATA' as a way to pull cloud-init data
    # https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html#source-2-drive-with-labeled-filesystem 
    cd_label = "CIDATA"
  }

  #############################
  # Packer Boot Commands
  #############################
  boot_wait = "10s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall quiet ds=nocloud",
    "<f10><wait>",
    "<wait1m>",
    "yes<enter>"
  ]

  #############################
  # SSH Settings
  #############################
  ssh_username         = var.ssh_username
  ssh_private_key_file = "${path.root}/${var.ssh_priv_key_path}"
  ssh_timeout          = "30m"
  ssh_pty              = true

}

# Build Definition to create the VM Template
build {
  name    = "ubuntu-server-noble-2404-docker"
  sources = ["source.proxmox-iso.ubuntu-server-noble"]

  # Copy fallback netplan file into the VM Template
  provisioner "file" {
    source      = "files/01-dhcp-all-ethernets.yaml"
    destination = "/tmp/01-dhcp-all-ethernets.yaml"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
provisioner "shell" {
  inline = [
    "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
    "sudo systemctl enable qemu-guest-agent",
    "sudo systemctl start qemu-guest-agent",
    
    # Remove subiquity networking config that conflicts with cloud-init
    "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
    
    # Ensure cloud-init runs on clones
    "sudo rm -f /etc/cloud/cloud-init.disabled",
    "sudo cloud-init clean --logs",
    "sudo systemctl enable cloud-init",
    "sudo systemctl enable cloud-init-local", 
    "sudo systemctl enable cloud-config",
    "sudo systemctl enable cloud-final",
    
    # Put our fallback netplan in place
    "sudo mkdir -p /etc/netplan",
    "sudo mv /tmp/01-dhcp-all-ethernets.yaml /etc/netplan/01-dhcp-all-ethernets.yaml",
    "sudo chmod 0644 /etc/netplan/01-dhcp-all-ethernets.yaml",

    # Generate, but not apply, fallback netplan
    "sudo netplan generate",

    # Reset machine-id for uniqueness in clones
    "sudo truncate -s 0 /etc/machine-id",
    "sudo rm -f /var/lib/dbus/machine-id || true",
    "sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id",

    # Ensure cloud-init will run on next boot (for clones)
    "sudo touch /var/lib/cloud/instance/cloud-init.disabled || true",
    "sudo rm -f /var/lib/cloud/instance/cloud-init.disabled",

    "echo 'Ubuntu Server Noble (24.04.x) Packer Template Build Complete. Creation Date: $(date)' | sudo tee /etc/issue"
  ]
}


  # Provisioning the VM Template with Docker Installation #4
  provisioner "shell" {
    inline = [
      "echo 'Performing docker prerequisite tasks...'",

      "sudo apt-get update",
      "sudo apt-get install ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",

      "echo 'Installing Docker Engine...'",

      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y",
      "sudo systemctl enable docker",

      "echo 'Adding template user to docker group...'",
      "sudo usermod -aG docker ${var.ssh_username}",

      "echo 'Verifying docker installation...'",
      "docker --version",
      "docker compose version",

      "echo 'Docker installation complete.'"
    ]
  }

}
