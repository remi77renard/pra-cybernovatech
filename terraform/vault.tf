# Conteneur LXC dedie pour HashiCorp Vault (zone Admin) - Docker
resource "proxmox_lxc" "vault" {
  target_node  = var.target_node
  vmid         = 106
  hostname     = "vault"
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
    bridge = "vmbr20"
    ip     = "192.168.20.210/24"
    gw     = "192.168.20.254"
  }

  nameserver = "1.1.1.1"

  features {
    nesting = true
  }

  ssh_public_keys = file("/root/.ssh/id_ed25519.pub")
}
