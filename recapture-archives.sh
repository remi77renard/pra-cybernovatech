#!/bin/bash
# Script de re-capture groupee des archives de donnees
# A lancer depuis l'iac quand des modifications ont ete faites sur les services
# Les archives sont ensuite utilisees par les playbooks Ansible pour la restauration

source "$(dirname "$0")/.env"
PROXMOX="root@192.168.1.100"
ANSIBLE_DIR="$(dirname "$0")/ansible"

echo "=== Re-capture des archives de donnees ==="
echo ""

# --- ZABBIX DB (docker-admin, LXC 101) ---
echo "[1/6] Base Zabbix (docker-admin)..."
ssh $PROXMOX "pct exec 101 -- tar czf /tmp/zabbix-db.tar.gz -C /var/lib/docker/volumes/stack_zabbix_db/_data ." 2>/dev/null
ssh $PROXMOX "pct pull 101 /tmp/zabbix-db.tar.gz /tmp/zabbix-db.tar.gz" 2>/dev/null
scp -q $PROXMOX:/tmp/zabbix-db.tar.gz "$ANSIBLE_DIR/zabbix-db.tar.gz"
echo "      OK ($(du -h "$ANSIBLE_DIR/zabbix-db.tar.gz" | cut -f1))"

# --- DASHY (docker-admin, LXC 101) ---
echo "[2/6] Dashy (docker-admin)..."
ssh $PROXMOX "pct exec 101 -- tar czf /tmp/dashy.tar.gz -C /opt/stack dashy-config.yml dashy-data" 2>/dev/null
ssh $PROXMOX "pct pull 101 /tmp/dashy.tar.gz /tmp/dashy.tar.gz" 2>/dev/null
scp -q $PROXMOX:/tmp/dashy.tar.gz "$ANSIBLE_DIR/dashy.tar.gz"
echo "      OK ($(du -h "$ANSIBLE_DIR/dashy.tar.gz" | cut -f1))"

# --- PORTAINER (docker-admin, LXC 101) ---
echo "[3/6] Portainer (docker-admin)..."
ssh $PROXMOX "pct exec 101 -- tar czf /tmp/portainer-data.tar.gz -C /var/lib/docker/volumes/stack_portainer_data/_data ." 2>/dev/null
ssh $PROXMOX "pct pull 101 /tmp/portainer-data.tar.gz /tmp/portainer-data.tar.gz" 2>/dev/null
scp -q $PROXMOX:/tmp/portainer-data.tar.gz "$ANSIBLE_DIR/portainer-data.tar.gz"
echo "      OK ($(du -h "$ANSIBLE_DIR/portainer-data.tar.gz" | cut -f1))"

# --- NEXTCLOUD DATA (nextcloud, LXC 102) ---
echo "[4/6] Nextcloud (donnees + config)..."
ssh $PROXMOX "pct exec 102 -- tar czf /tmp/nextcloud-data.tar.gz -C /var/lib/docker/volumes/nextcloud_nextcloud_data/_data ." 2>/dev/null
ssh $PROXMOX "pct pull 102 /tmp/nextcloud-data.tar.gz /tmp/nextcloud-data.tar.gz" 2>/dev/null
scp -q $PROXMOX:/tmp/nextcloud-data.tar.gz "$ANSIBLE_DIR/nextcloud-data.tar.gz"
echo "      OK ($(du -h "$ANSIBLE_DIR/nextcloud-data.tar.gz" | cut -f1))"

# --- VAULT (vault, LXC 106) ---
echo "[5/6] Vault (coffre chiffre)..."
ssh $PROXMOX "pct exec 106 -- tar czf /tmp/vault-data.tar.gz -C /var/lib/docker/volumes/vault_vault_data/_data ." 2>/dev/null
ssh $PROXMOX "pct pull 106 /tmp/vault-data.tar.gz /tmp/vault-data.tar.gz" 2>/dev/null
scp -q $PROXMOX:/tmp/vault-data.tar.gz "$ANSIBLE_DIR/vault-data.tar.gz"
echo "      OK ($(du -h "$ANSIBLE_DIR/vault-data.tar.gz" | cut -f1))"

# --- MARIADB (mariadb, LXC 103, natif) - dump SQL de la base nextcloud ---
echo "[6/6] Base MariaDB (dump SQL nextcloud)..."
ssh $PROXMOX "pct exec 103 -- mysqldump -u root -p$MARIADB_ROOT_PW nextcloud" > "$ANSIBLE_DIR/nextcloud-dump.sql" 2>/dev/null
echo "      OK ($(du -h "$ANSIBLE_DIR/nextcloud-dump.sql" | cut -f1))"

echo ""
echo "=== Toutes les archives ont ete re-capturees ! ==="
echo "Note : ces archives sont gitignorees (donnees non versionnees)."
ls -lh "$ANSIBLE_DIR"/*.tar.gz
