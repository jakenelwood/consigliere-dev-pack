variable "hcloud_token" {
  description = "Hetzner Cloud API token (export as TF_VAR_hcloud_token)"
  type        = string
  sensitive   = true
}

variable "my_admin_cidrs" {
  description = "CIDRs allowed to reach node SSH and kube-API"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Open to world, replace with your IP(s)
}