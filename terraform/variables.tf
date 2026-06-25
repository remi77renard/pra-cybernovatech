variable "pm_api_token_id" {
  description = "ID du token API Proxmox"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Secret du token API Proxmox"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Noeud Proxmox cible"
  type        = string
  default     = "proxmox1"
}
