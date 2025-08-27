# CLAUDE.md - Kube-Hetzner Development Pack

This directory contains the Kube-Hetzner infrastructure for the AI Consigliere project.

## Main Project Documentation
See the primary CLAUDE.md at: `/home/brian/Dev/espocm_n8n/espocrm_n8n/ai-chatbot/CLAUDE.md`

## Directory-Specific Constraints for Kube-Hetzner

### CRITICAL: Server Types (ONLY use these)
**ALL resources MUST be in location: "ash" (Ashburn, VA)**

- **Control Plane**: 3× CCX13 (80GB NVMe, dedicated vCPU)
- **Workload Node**: 1× CCX33 (160GB NVMe, dedicated vCPU)  
- **Load Balancers**: LB11
- **Network Region**: us-east
- **Location**: ash (ONLY)

### Why These Constraints Matter
- CCX = x86 architecture with dedicated vCPU (required for production workloads)
- CAX = ARM servers (NOT available in ash, don't use)
- CX = Shared vCPU (not suitable for our workloads)

### Snapshot Creation Exception
- ARM snapshot can be created in fsn1 (Germany) where CAX servers exist
- This is ONLY to satisfy the kube-hetzner module requirement
- We never actually use ARM servers in our cluster

## Project Structure
```
/home/brian/Dev/consigliere-dev-pack/
├── kube.tf                  # Main Terraform configuration
├── terraform.tfvars         # Variables (contains API token)
├── hcloud-microos-snapshots.pkr.hcl  # Packer config for MicroOS
└── .terraform/              # Terraform modules
```

## Quick Commands
```bash
# Create snapshots (one-time)
packer build hcloud-microos-snapshots.pkr.hcl

# Deploy cluster
terraform apply

# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/config
```