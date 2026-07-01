#!/bin/bash
set -e

PROXMOX="root@${PROXMOX_HOST:-192.168.1.100}"
# Test RTO : si PROXMOX_HOST surcharge, Terraform utilise aussi cette IP
if [ -n "$PROXMOX_HOST" ]; then
  export TF_VAR_pm_api_url="https://${PROXMOX_HOST}:8006/api2/json"
fi
VMID="100"
DISK="local-lvm:vm-${VMID}-disk-0"
WAN_IP="192.168.20.253"

echo "========================================="
echo " DEPLOIEMENT AUTOMATISE OPNSENSE (PRA)"
echo "========================================="

echo ""
echo "=== 1/5 - Provisioning Terraform (clone du template) ==="
cd terraform
terraform apply -auto-approve
cd ..

echo ""
echo "=== 2/5 - Attente de l'enregistrement du clone ==="
sleep 10

echo ""
echo "=== 3/5 - Correction disque (SCSI) + boot order ==="
# Le provider telmate detache le disque au clonage : on le rattache en SCSI
ssh $PROXMOX "qm set $VMID --scsi0 ${DISK},iothread=1"
ssh $PROXMOX "qm set $VMID --boot order=scsi0"
# Redemarrage pour appliquer le boot sur disque
ssh $PROXMOX "qm stop $VMID 2>/dev/null || true; sleep 3; qm start $VMID"

echo ""
echo "=== 4/5 - Attente du demarrage d'OPNsense (SSH) ==="
cd ansible
COUNTER=0
until nc -z $WAN_IP 22 2>/dev/null; do
  echo "    OPNsense pas encore pret, attente 10s..."
  sleep 10
  COUNTER=$((COUNTER+1))
  if [ $COUNTER -gt 18 ]; then
    echo "ERREUR : OPNsense ne demarre pas (timeout 3 min)"
    exit 1
  fi
done
echo "    SSH disponible ! Stabilisation 15s..."
sleep 15

echo ""
echo "=== 5/5 - Injection de la configuration (Ansible) ==="
ansible-playbook -i inventory-opnsense.ini inject-opnsense.yml

echo ""
echo "=== Reboot final pour appliquer la configuration ==="
ansible -i inventory-opnsense.ini opnsense -m raw -a "/sbin/reboot" 2>/dev/null || true

echo ""
echo "========================================="
echo " DEPLOIEMENT TERMINE !"
echo " OPNsense reconstruit et configure."
echo " (reboot en cours, ~90s pour etre operationnel)"
echo "========================================="
