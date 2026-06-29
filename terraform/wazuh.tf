# Conteneur LXC pour Wazuh SIEM (zone Admin) - Docker
resource "proxmox_lxc" "wazuh" {
  target_node  = var.target_node
  vmid         = 107
  hostname     = "wazuh"
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  password     = var.ct_password
  unprivileged = true
  onboot       = true

  cores  = 2
  memory = 6144
  swap   = 6144

  rootfs {
    storage = "local-lvm"
    size    = "50G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr20"
    ip     = "192.168.20.220/24"
    gw     = "192.168.20.254"
  }

  nameserver = "1.1.1.1"

  features {
    nesting = true
  }

  ssh_public_keys = file("/root/.ssh/id_ed25519.pub")
}
