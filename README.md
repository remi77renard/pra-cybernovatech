# Projet PRA - CyberNovaTech

Infrastructure as Code pour le déploiement d'une architecture sécurisée
avec Plan de Reprise d'Activité (Bac+4 Architecte Cybersécurité).

## Structure

- `terraform/` : provisioning des VMs/conteneurs sur Proxmox
- `ansible/`   : configuration des machines et déploiement des services

## Prérequis

- Proxmox VE 8.x avec un token API
- Terraform >= 1.x
- Ansible >= 2.x

## Déploiement

```bash
cd terraform
terraform init
terraform plan
terraform apply
```
