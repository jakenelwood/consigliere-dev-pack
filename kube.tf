terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.51.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

module "kube-hetzner" {
  # Terraform Registry module
  source  = "kube-hetzner/kube-hetzner/hcloud"
  version = "2.18.0"

  providers = {
    hcloud = hcloud
  }

  # Required authentication
  hcloud_token = var.hcloud_token
  ssh_public_key = file("~/.ssh/id_ed25519.pub")
  ssh_private_key = file("~/.ssh/id_ed25519")

  # MicroOS snapshot IDs (ARM is only for module requirement, not used)
  microos_x86_snapshot_id = "312761478"
  microos_arm_snapshot_id = "312777220"

  cluster_name   = "ai-consigliere-dev"
  network_region = "us-east"           # keep locations inside this region

  # Ingress path (prod-like): Hetzner LB11 -> ingress-nginx
  ingress_controller     = "nginx"
  load_balancer_type     = "lb11"
  load_balancer_location = "ash"
  
  # Optional: custom NGINX values (e.g., PROXY protocol)
  # nginx_values = file("values/ingress-nginx-values.yaml")

  # Security: restrict node firewalls to your IP(s)
  firewall_ssh_source      = var.my_admin_cidrs
  firewall_kube_api_source = var.my_admin_cidrs

  # === HA control plane (small) with spread placement groups ===
  # Each control plane will be on a different physical host (best-effort)
  control_plane_nodepools = [
    { name = "cp-ash-a", server_type = "ccx13", location = "ash", count = 1, placement_group = "cp-spread", labels = [], taints = [] },
    { name = "cp-ash-b", server_type = "ccx13", location = "ash", count = 1, placement_group = "cp-spread", labels = [], taints = [] },
    { name = "cp-ash-c", server_type = "ccx13", location = "ash", count = 1, placement_group = "cp-spread", labels = [], taints = [] },
  ]
  # Control planes are tainted by default; app pods won't schedule here.

  # === Workload node (your snappy box) with separate spread group ===
  agent_nodepools = [
    { 
      name = "workload", 
      server_type = "ccx33", 
      location = "ash", 
      count = 1, 
      placement_group = "agent-spread",
      labels = [
        "node.kubernetes.io/role=worker",
        "workload=app"
      ],
      taints = []
    }
  ]

  # === API HA endpoint ===
  # Enable dedicated LB for :6443 and point kubeconfig at it for HA access
  use_control_plane_lb = true
  control_plane_lb_type = "lb11"
  control_plane_lb_enable_public_interface = true  # Public access to API
}

output "kubeconfig" {
  value     = module.kube-hetzner.kubeconfig
  sensitive = true
}