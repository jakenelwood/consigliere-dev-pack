#!/bin/bash
set -e

echo "=== AI Consigliere Dev Pack Deployment ==="
echo "Region: Ashburn (us-east)"
echo "Cluster: 3x CCX13 control planes + 1x CCX33 workload node"
echo ""

# Set PATH for Terraform and other tools
export PATH="$HOME/.local/bin:$PATH"

# Verify Terraform is available
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform not found. Please install Terraform first."
    exit 1
fi

echo "Terraform version: $(terraform version | head -n1)"
echo ""

export TF_VAR_hcloud_token="F82LTClTVOph6A6LwUo2m0BcKHFyYpuuqQUQjn5YFm2DMo2yQQEfRqSJLaj35jVM"

cd ~/consigliere-dev-pack

echo "Starting Terraform deployment..."
terraform apply -auto-approve

echo ""
echo "Deployment complete! Getting kubeconfig..."
make kubeconfig

echo ""
echo "Cluster is ready! To use it:"
echo "export KUBECONFIG=$PWD/kubeconfig"
echo "kubectl get nodes"