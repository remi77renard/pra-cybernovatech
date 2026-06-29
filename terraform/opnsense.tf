# Clonage de la VM OPNsense depuis le template + boot sur disque
resource "proxmox_vm_qemu" "opnsense" {
  name        = "opnsense-iac"
  target_node = var.target_node
  vmid        = 110
  clone       = "opnsense-image"
  full_clone  = true
  agent       = 0

  cores   = 2
  memory  = 2048
  scsihw  = "virtio-scsi-single"
  qemu_os = "other"

  # Boot sur le disque (corrige le boot=net0 par défaut)

  # Interfaces dans le BON ordre (selon le mapping OPNsense)
  # vtnet0 = LAN/Admin -> vmbr20
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr20"
  }
  # vtnet1 = WAN -> vmbr0
  network {
    id     = 1
    model  = "virtio"
    bridge = "vmbr0"
  }
  # vtnet2 = DMZ -> vmbr10
  network {
    id     = 2
    model  = "virtio"
    bridge = "vmbr10"
  }
  # vtnet3 = APP -> vmbr30
  network {
    id     = 3
    model  = "virtio"
    bridge = "vmbr30"
  }

  lifecycle {
    ignore_changes = [network, vmid]
  }
}
