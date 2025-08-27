# AI Consigliere — Inner-loop HA Dev (Ashburn)

![Application Deployment](https://github.com/jakenelwood/consigliere-dev-pack/actions/workflows/applications.yml/badge.svg)
![Security Scanning](https://github.com/jakenelwood/consigliere-dev-pack/actions/workflows/security.yml/badge.svg)
![Test Connection](https://github.com/jakenelwood/consigliere-dev-pack/actions/workflows/test-connection.yml/badge.svg)

This stands up an HA k3s control plane in Ashburn with a single **CCX33** agent for a snappy dev feel, fronted by a **Hetzner LB11** running **ingress‑nginx**. Control planes remain tainted so app pods don't land there (prod‑like scheduling).

## Prereqs
- Terraform ≥ 1.5.0
- Hetzner Cloud API token with write perms
- Your public IP (for firewall allowlist)
- An SSH key available locally (ed25519 recommended)

## Quickstart
```bash
# 1) Clone (or create an empty folder) and place these files there
# 2) Export your Hetzner API token
export TF_VAR_hcloud_token="<your-hetzner-token>"

# 3) Set your IP in terraform.tfvars (copy from example)
cp terraform.tfvars.example terraform.tfvars

# 4) Bring it up
make up

# 5) Get kubeconfig
make kubeconfig
export KUBECONFIG="$PWD/kubeconfig"

# 6) Check nodes & ingress
kubectl get nodes -o wide
kubectl -n ingress-nginx get svc
```

## Toggle API HA feel (optional)
To practice **kube‑API HA**, edit `kube.tf` and set:
```hcl
use_control_plane_lb = true
control_plane_lb_type = "lb11"
# control_plane_lb_enable_public_interface = false  # use private-only if you prefer
```
Apply again: `make up`.

## Scale later for tests
- **10 users:** add a second agent (CCX23) and set `ingress_replica_count = 2`.
- **25 users:** add an autoscaler pool (CCX23 min 0 / max 3) or a third agent.

## Tear down
```bash
make down   # destroy with confirmation
```

## Notes
- Firewalls in this pack restrict **node** SSH & kube‑API to your IP; Hetzner LBs can't be firewalled, so rely on K8s auth/RBAC if you enable the control‑plane LB.
- Keep all nodepools in **location `ash`** and **network_region `us-east`**.