# Conteneur LXC pour MariaDB (zone APP) - reconstruction a l'identique
resource "proxmox_lxc" "mariadb" {
  target_node  = var.target_node
  vmid         = 103
  hostname     = "mariadb"
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  password     = var.ct_password
  unprivileged = true
  onboot       = true

  cores  = 1
  memory = 1024
  swap   = 512

  rootfs {
    storage = "local-lvm"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr30"
    ip     = "192.168.30.200/24"
    gw     = "192.168.30.254"
  }

  features {
    nesting = true
  }

  ssh_public_keys = file("/root/.ssh/id_ed25519.pub")
}
