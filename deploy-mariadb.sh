#!/bin/bash
set -e

# Charger les secrets depuis le fichier .env local (non versionne)
source "$(dirname "$0")/.env"

PROXMOX="root@192.168.1.100"
VMID="103"
CT_IP="192.168.30.200"
GW="192.168.30.254"


echo "=== 1/5 - Provisioning Terraform ==="
cd terraform
terraform apply -target=proxmox_lxc.mariadb -auto-approve
cd ..

echo "=== 2/5 - Demarrage du conteneur ==="
ssh $PROXMOX "pct start $VMID 2>/dev/null || true"
sleep 8

echo "=== 3/5 - Reveil du bridge reseau (ping sortant) ==="
# Le conteneur doit emettre du trafic pour que le bridge apprenne sa MAC
until ssh $PROXMOX "pct exec $VMID -- ping -c 2 $GW" >/dev/null 2>&1; do
  echo "    Reseau pas encore pret, nouvelle tentative..."
  sleep 5
done

echo "=== 4/5 - Attente SSH ==="
ssh-keygen -f /root/.ssh/known_hosts -R $CT_IP 2>/dev/null || true
until timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$CT_IP "echo ok" 2>/dev/null; do
  echo "    Attente SSH..."
  ssh $PROXMOX "pct exec $VMID -- ping -c 2 $GW" 2>/dev/null || true
  sleep 5
done
echo "    SSH disponible !"

echo "=== 5/5 - Configuration Ansible ==="
cd ansible
ansible-playbook -i inventory-mariadb.ini mariadb.yml

echo "=== DEPLOIEMENT MARIADB TERMINE ! ==="
