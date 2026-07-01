# Conteneur LXC pour docker-admin (zone Admin) - Docker
# Heberge : Zabbix (db/server/web), Portainer, Dashy
resource "proxmox_lxc" "docker_admin" {
  target_node  = var.target_node
  vmid         = 101
  hostname     = "docker-admin"
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  password     = var.ct_password
  unprivileged = true
  onboot       = true

  cores  = 2
  memory = 8192
  swap   = 8192

  rootfs {
    storage = "local-lvm"
    size    = "50G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr20"
    ip     = "192.168.20.200/24"
    gw     = "192.168.20.254"
  }

  nameserver = "1.1.1.1 8.8.8.8"

  features {
    nesting = true
  }

  ssh_public_keys = file("/root/.ssh/id_ed25519.pub")
}
