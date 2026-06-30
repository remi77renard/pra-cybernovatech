#!/bin/bash
set -e

# Charger les secrets depuis le fichier .env local (non versionne)
source "$(dirname "$0")/.env"

PROXMOX="root@192.168.1.100"
VMID="102"
CT_IP="192.168.10.200"
GW="192.168.10.254"

echo "=== 1/6 - Provisioning Terraform ==="
cd terraform
terraform apply -target=proxmox_lxc.nextcloud -auto-approve
cd ..

echo "=== 2/6 - Ajout des options Docker/apparmor au LXC ==="
ssh $PROXMOX "pct set $VMID --features nesting=1,keyctl=1"
ssh $PROXMOX "grep -q 'lxc.apparmor.profile' /etc/pve/lxc/${VMID}.conf || cat >> /etc/pve/lxc/${VMID}.conf << 'LXCEOF'
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind,create=file 0 0
LXCEOF"

echo "=== 3/6 - Demarrage du conteneur ==="
ssh $PROXMOX "pct start $VMID"
sleep 8

echo "=== 4/6 - Reveil du bridge reseau ==="
ssh $PROXMOX "pct exec $VMID -- ping -c 3 $GW"

echo "=== 5/6 - Attente SSH ==="
ssh-keygen -f /root/.ssh/known_hosts -R $CT_IP 2>/dev/null || true
until timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$CT_IP "echo ok" 2>/dev/null; do
  echo "    Attente SSH..."
  ssh $PROXMOX "pct exec $VMID -- ping -c 2 $GW" 2>/dev/null || true
  sleep 5
done
echo "    SSH disponible !"

echo "=== 6/6 - Configuration Ansible (Docker + Nextcloud + agents) ==="
cd ansible
ansible-playbook -i inventory-nextcloud.ini nextcloud.yml

echo "=== DEPLOIEMENT NEXTCLOUD TERMINE ! ==="
