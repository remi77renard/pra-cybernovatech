#!/bin/bash
# ============================================
# TEST RTO - Reconstruction complete PRA
# (la destruction est faite manuellement AVANT)
# ============================================
source "$(dirname "$0")/.env"

START=$(date +%s)
LOG="/root/pra-cybernovatech/rto-test-$(date +%Y%m%d-%H%M%S).log"

echo "==========================================" | tee "$LOG"
echo " TEST RTO - DEBUT : $(date)" | tee -a "$LOG"
echo "==========================================" | tee -a "$LOG"

# Nettoyer le state Terraform (ressources detruites manuellement)
cd "$(dirname "$0")/terraform"
for RES in proxmox_vm_qemu.opnsense proxmox_lxc.vault proxmox_lxc.docker_admin proxmox_lxc.wazuh proxmox_lxc.mariadb proxmox_lxc.nextcloud; do
  terraform state rm "$RES" 2>/dev/null || true
done
cd ..

# ---------- [1/6] OPNSENSE (via IP LAN .20.1 car routage down) ----------
echo "" | tee -a "$LOG"
echo ">>> [1/6] OPNSENSE (pare-feu)..." | tee -a "$LOG"
PROXMOX_HOST=192.168.20.1 ./deploy-opnsense.sh 2>&1 | tee -a "$LOG"

# ---------- PAUSE ACTIVE (retablissement routage) ----------
echo "" | tee -a "$LOG"
echo ">>> ATTENTE RETABLISSEMENT OPNSENSE ET ROUTAGE..." | tee -a "$LOG"
until ping -c1 -W2 192.168.20.254 >/dev/null 2>&1; do
  echo "    Passerelle Admin .254 pas encore prete..." | tee -a "$LOG"
  sleep 10
done
echo "    Passerelle Admin OK." | tee -a "$LOG"
until ping -c1 -W2 192.168.1.100 >/dev/null 2>&1; do
  echo "    Routage mgmt pas encore pret..." | tee -a "$LOG"
  sleep 10
done
echo "    Routage mgmt OK. Attente des zones APP et DMZ..." | tee -a "$LOG"
until ping -c1 -W2 192.168.30.254 >/dev/null 2>&1; do
  echo "    Zone APP (.30.254) pas encore prete..." | tee -a "$LOG"
  sleep 10
done
until ping -c1 -W2 192.168.10.254 >/dev/null 2>&1; do
  echo "    Zone DMZ (.10.254) pas encore prete..." | tee -a "$LOG"
  sleep 10
done
echo "    Toutes les zones routent. Stabilisation (30s)..." | tee -a "$LOG"
sleep 60

# ---------- [2/6] VAULT + DESCELLEMENT ----------
echo "" | tee -a "$LOG"
echo ">>> [2/6] VAULT..." | tee -a "$LOG"
./deploy-vault.sh 2>&1 | tee -a "$LOG"
echo "    Attente que Vault reponde..." | tee -a "$LOG"
until curl -k -s http://192.168.20.210:8200/v1/sys/health >/dev/null 2>&1; do sleep 3; done
echo "    Descellement Vault (quorum de cles, avec verification)..." | tee -a "$LOG"
until curl -k -s http://192.168.20.210:8200/v1/sys/health | grep -q '"sealed":false'; do
  for KEY in "$UNSEAL_KEY_1" "$UNSEAL_KEY_2" "$UNSEAL_KEY_3"; do
    ssh root@192.168.1.100 "pct exec 106 -- docker exec vault sh -c 'VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal $KEY'" >/dev/null 2>&1
  done
  sleep 3
done
echo "    Vault DESCELLE et confirme (sealed:false)." | tee -a "$LOG"

# ---------- [3/6] DOCKER-ADMIN (zone Admin) ----------
echo "" | tee -a "$LOG"
echo ">>> [3/6] DOCKER-ADMIN (Zabbix + Portainer + Dashy)..." | tee -a "$LOG"
./deploy-docker-admin.sh 2>&1 | tee -a "$LOG"

# ---------- [4/6] WAZUH (zone Admin) ----------
echo "" | tee -a "$LOG"
echo ">>> [4/6] WAZUH (SIEM)..." | tee -a "$LOG"
./deploy-wazuh.sh 2>&1 | tee -a "$LOG"

# ---------- [5/6] MARIADB (zone APP) ----------
echo "" | tee -a "$LOG"
echo ">>> [5/6] MARIADB (base de donnees)..." | tee -a "$LOG"
./deploy-mariadb.sh 2>&1 | tee -a "$LOG"

# ---------- [6/6] NEXTCLOUD (zone DMZ) ----------
echo "" | tee -a "$LOG"
echo ">>> [6/6] NEXTCLOUD (application)..." | tee -a "$LOG"
./deploy-nextcloud.sh 2>&1 | tee -a "$LOG"

# ---------- CHRONO FINAL ----------
END=$(date +%s)
ELAPSED=$((END - START))
echo "" | tee -a "$LOG"
echo "==========================================" | tee -a "$LOG"
echo " TEST RTO - FIN : $(date)" | tee -a "$LOG"
echo " RTO TOTAL : $((ELAPSED / 60)) min $((ELAPSED % 60)) s" | tee -a "$LOG"
echo "==========================================" | tee -a "$LOG"
echo "Log complet : $LOG"
