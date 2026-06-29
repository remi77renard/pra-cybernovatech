# PRA CyberNovaTech — Infrastructure as Code

Déploiement automatisé et reproductible d'une architecture sécurisée dans le cadre d'un Plan de Reprise d'Activité (PRA), réalisé avec **Terraform** et **Ansible** sur deux hyperviseurs **Proxmox VE**.

Projet de fin d'année — Bac+4 Architecte Cybersécurité.

---

## 1. Présentation

Ce dépôt contient l'ensemble du code d'infrastructure permettant de reconstruire « from scratch » les composants critiques du site primaire de l'entreprise fictive *CyberNovaTech*, dans une démarche de PRA.

L'objectif est de démontrer qu'en cas de sinistre, chaque service peut être reprovisionné de manière automatisée, reproductible et sécurisée, à partir du code versionné (source de vérité) et des sauvegardes.

Trois composants sont entièrement automatisés en IaC :

| Composant | Rôle | Type |
|-----------|------|------|
| **OPNsense** | Pare-feu / routeur inter-zones, terminaison VPN | VM (clone de template) |
| **MariaDB** | Base de données applicative (Nextcloud) | Conteneur LXC |
| **Wazuh** | SIEM (manager + indexer + dashboard) | Conteneur LXC (Docker) |

Chaque déploiement se lance via une commande unique et récupère ses secrets depuis un coffre **HashiCorp Vault** : aucun secret n'est présent dans le dépôt.

---

## 2. Architecture

### Hyperviseurs

- **Proxmox 1 — Site primaire** : héberge les services de production (pare-feu, base de données, SIEM, etc.).
- **Proxmox 2 — Site secondaire** : endpoint VPN, dépôt de sauvegardes (PBS) et récepteur de logs.

### Segmentation réseau (site primaire)

L'architecture applique une logique de **déni par défaut** avec une segmentation en zones, routées par le pare-feu OPNsense.

| Zone | Bridge | Sous-réseau | Passerelle |
|------|--------|-------------|------------|
| WAN / Management | vmbr0 | 192.168.1.0/24 | Box FAI |
| DMZ | vmbr10 | 192.168.10.0/24 | 192.168.10.254 |
| Admin | vmbr20 | 192.168.20.0/24 | 192.168.20.254 |
| Application | vmbr30 | 192.168.30.0/24 | 192.168.30.254 |

Les passerelles des zones internes sont portées par OPNsense.

### Interconnexion des sites

Un tunnel **WireGuard** relie les deux sites. Le client (initiateur) est porté par OPNsense sur le site primaire, le serveur côté site secondaire. Il transporte la réplication des sauvegardes et l'acheminement des logs vers le site distant.

---

## 3. Prérequis

- Deux hyperviseurs **Proxmox VE 8.x** opérationnels et joignables.
- Les bridges réseau (vmbr0, vmbr10, vmbr20, vmbr30) configurés sur le site primaire.
- Un poste/machine disposant de :
  - **Terraform** ≥ 1.x
  - **Ansible** (avec la collection `community.hashi_vault` et le module `hvac` côté Python)
- Un **template Proxmox** de l'image OPNsense préparé (voir §5).
- Un **coffre Vault** opérationnel et descellé, contenant les secrets des services.
- Une **clé SSH** autorisée sur les hyperviseurs Proxmox (authentification sans mot de passe).

---

## 4. Structure du dépôt

\`\`\`
.
├── terraform/
│   ├── provider.tf          # Configuration du provider Proxmox
│   ├── variables.tf         # Déclaration des variables
│   ├── opnsense.tf          # VM OPNsense (clone de template)
│   ├── mariadb.tf           # Conteneur LXC MariaDB
│   └── wazuh.tf             # Conteneur LXC Wazuh
│
├── ansible/
│   ├── inject-opnsense.yml  # Injection de la configuration OPNsense
│   ├── mariadb.yml          # Installation MariaDB + restauration + agents
│   ├── wazuh.yml            # Déploiement de la stack Wazuh (Docker)
│   └── inventory-*.ini      # Inventaires (clé SSH, sans secret)
│
├── deploy-opnsense.sh       # Script de déploiement OPNsense
├── deploy-mariadb.sh        # Script de déploiement MariaDB
├── deploy-wazuh.sh          # Script de déploiement Wazuh
│
├── .gitignore               # Exclut tous les fichiers sensibles
└── README.md
\`\`\`

> Les fichiers contenant des données sensibles (\`.env\`, \`*.tfvars\`, \`*.tfstate\`, dumps SQL, configuration OPNsense, inventaires avec mots de passe) sont exclus du dépôt via \`.gitignore\`.

---

## 5. Configuration initiale

Avant tout déploiement, quelques éléments doivent être préparés **localement** (hors dépôt).

### 5.1 Token API Proxmox

Créer un token API sur Proxmox pour permettre à Terraform de piloter l'hyperviseur, puis le renseigner dans la configuration locale du provider (non versionnée).

### 5.2 Fichier \`.env\` (secrets d'accès à Vault)

Le déploiement charge l'adresse et le token Vault depuis un fichier \`.env\` à la racine, **exclu du dépôt** :

\`\`\`bash
# .env (NE JAMAIS versionner — déjà dans .gitignore)
export VAULT_ADDR='http://<ip-vault>:8200'
export VAULT_TOKEN='<votre-token-vault>'
\`\`\`

Les scripts de déploiement sourcent automatiquement ce fichier. Le code versionné reste donc exempt de tout secret tout en gardant un déploiement en une seule commande.

### 5.3 Vault descellé

Le coffre Vault doit être **descellé** avant le déploiement (les playbooks Ansible y lisent les mots de passe des services). Les secrets sont organisés par moteur KV v2, un chemin par service.

### 5.4 Template OPNsense

La VM OPNsense est déployée par **clonage d'un template** Proxmox préparé au préalable (image OPNsense avec accès SSH activé). La configuration spécifique (interfaces, règles, VPN) est ensuite injectée par Ansible.

---

## 6. Ordre de déploiement

L'ordre est important en raison d'une dépendance d'amorçage (*bootstrap*).

> **Note sur le bootstrap** : la machine qui exécute l'IaC se trouve dans la zone Admin et joint l'hyperviseur Proxmox **via** le routage assuré par OPNsense. Pour reconstruire OPNsense lui-même alors qu'il n'existe pas encore, on place temporairement la machine IaC sur un réseau joignant directement l'hyperviseur (procédure documentée comme exception). Une fois OPNsense en place, le reste se déploie normalement.

1. **OPNsense** (le pare-feu, prérequis réseau des autres zones)
2. **MariaDB** (base de données)
3. **Wazuh** (SIEM)

---

## 7. Déploiement

Chaque composant se déploie via son script dédié. Au préalable, s'assurer que le fichier \`.env\` est présent et que Vault est descellé.

### OPNsense

\`\`\`bash
./deploy-opnsense.sh
\`\`\`

Le script clone la VM depuis le template, corrige le rattachement du disque et l'ordre de démarrage, attend l'accès SSH, puis injecte la configuration via Ansible et redémarre.

### MariaDB

\`\`\`bash
./deploy-mariadb.sh
\`\`\`

Le script provisionne le conteneur via Terraform, le démarre, « réveille » le bridge réseau, attend l'accès SSH, puis Ansible installe MariaDB, restaure les données depuis un dump, recrée l'utilisateur applicatif (secrets depuis Vault) et installe les agents Wazuh et Zabbix.

### Wazuh

\`\`\`bash
./deploy-wazuh.sh
\`\`\`

Le script provisionne le conteneur LXC, applique les options nécessaires à Docker (nesting, keyctl, profil AppArmor), le démarre, puis Ansible installe Docker, clone le dépôt officiel \`wazuh-docker\`, injecte les mots de passe depuis Vault, ajuste les limites système incompatibles avec un LXC non-privilégié, dimensionne la mémoire de l'indexer, génère les certificats et lance la stack.

> La stack Wazuh demande quelques minutes après le déploiement pour être pleinement opérationnelle (initialisation de l'indexer et migration du dashboard).

---

## 8. Sécurité des secrets

La gestion des secrets est un point central du projet :

- **Aucun secret dans le dépôt** : mots de passe, tokens, dumps de données et configuration du pare-feu sont exclus via \`.gitignore\`.
- **Vault comme source des secrets** : les playbooks Ansible récupèrent les mots de passe des services dynamiquement depuis Vault au moment du déploiement.
- **Fichier \`.env\` local** : les accès à Vault (adresse + token) sont chargés depuis un fichier local non versionné.
- **Vérification systématique** : chaque commit fait l'objet d'un contrôle anti-secret avant publication.

---

## 9. Limitations connues et axes d'amélioration

Ce projet est réalisé dans un contexte de laboratoire ; plusieurs points sont identifiés comme axes de durcissement :

- **TLS interne** : certains services internes communiquent en HTTP (lab) ; à passer en TLS.
- **Comptes Proxmox** : utilisation d'un compte privilégié pour l'API ; à remplacer par un compte dédié à privilèges restreints.
- **Mots de passe** : mots de passe par défaut à renforcer (le changement des mots de passe par défaut de Wazuh nécessite la régénération des empreintes dans la configuration de l'indexer).
- **Dépendance du coffre** : Vault est hébergé sur une machine de la zone Admin ; à isoler sur un hôte dédié, sauvegardé et restauré en priorité dans le scénario de reprise.
- **Factorisation Ansible** : les tâches d'installation des agents pourraient être factorisées en rôle réutilisable.
- **Couverture IaC** : étendre l'automatisation aux composants restants (application Nextcloud, services d'administration, machines du site secondaire).

---

*Projet pédagogique — architecture et données fictives.*
