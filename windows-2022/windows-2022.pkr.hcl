packer {
  required_plugins {
    proxmox = {
      version = "= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ---- Variables ----
variable "proxmox_api_url" { type = string }
variable "proxmox_api_token_id" { type = string }
variable "proxmox_api_token_secret" { type = string }
variable "node" { default = "pve" }
variable "pool" { default = "local-zfs" }

# ---- Source ----
source "proxmox-iso" "windows2022" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true




  vm_id         = 9000
  vm_name       = "win2022-base"
  template_name = "win2022-base"
  node          = var.node
  #pool          = var.pool

  # ✅ Correct modern boot_iso block
  boot_iso {
    iso_storage_pool = "local"
    iso_file         = "local:iso/SERVER_2022_EVAL_x64FRE_en-us.iso"
    iso_checksum     = "none"
    unmount          = true
  }

  # Attach VirtIO drivers ISO
  additional_iso_files {
    iso_file = "local:iso/virtio-win.iso"
  }

  # Attach our autounattend + scripts ISO
  additional_iso_files {
    iso_file = "local:iso/win-files.iso"
  }

  disks {
    storage_pool = "local-zfs"
    disk_size    = "60G"
    format       = "raw"
    type         = "scsi"
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cpu_type = "host"
  sockets  = 1
  cores    = 2
  memory   = 4096
  os       = "win11"

  boot_wait    = "5s"
  boot_command = [
    "<tab><wait>",
    " autounattend=cdrom:/autounattend.xml",
    "<enter>"
  ]

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "P@ssw0rd123!"
  winrm_timeout  = "30m"
}

# ---- Build ----
build {
  name    = "win2022-base"
  sources = ["source.proxmox-iso.windows2022"]

  provisioner "powershell" {
    scripts = [
      "scripts/install-virtio-drivers.ps1",
      "scripts/enable-winrm.ps1"
    ]
  }
}
