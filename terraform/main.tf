# VM de démonstration IaC - conteneur LXC
resource "proxmox_lxc" "demo" {
  target_node  = var.target_node
  hostname     = "demo-iac"
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  password     = "DemoPassword2026"
  unprivileged = true

  cores  = 1
  memory = 512
  swap   = 512

  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr20"
    ip     = "192.168.20.210/24"
    gw     = "192.168.20.254"
  }

  features {
    nesting = true
  }
}
