# Conteneur LXC pour Nextcloud (zone DMZ) - Docker
resource "proxmox_lxc" "nextcloud" {
  target_node  = var.target_node
  vmid         = 102
  hostname     = "nextcloud"
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  password     = var.ct_password
  unprivileged = true
  onboot       = true

  cores  = 2
  memory = 2048
  swap   = 2048

  rootfs {
    storage = "local-lvm"
    size    = "30G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr10"
    ip     = "192.168.10.200/24"
    gw     = "192.168.10.254"
  }

  nameserver = "1.1.1.1"

  features {
    nesting = true
  }

  ssh_public_keys = file("/root/.ssh/id_ed25519.pub")
}
