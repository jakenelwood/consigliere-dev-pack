# CI/CD Pipeline Setup Guide

## Overview
This repository uses GitHub Actions for continuous deployment to the Kube-Hetzner cluster.

## Prerequisites
1. A deployed Kube-Hetzner cluster
2. GitHub CLI (`gh`) installed and authenticated
3. `kubectl` installed
4. Valid kubeconfig for your cluster

## Setup Instructions

### 1. Get your Kubeconfig
After deploying your cluster with Terraform:
```bash
terraform output -raw kubeconfig > ~/.kube/config
```

### 2. Configure GitHub Secrets
Run the setup script to configure the required GitHub secret:
```bash
./scripts/setup-github-secrets.sh
```

This will create the `KUBECONFIG_BASE64` secret in your repository.

### 3. Verify Setup
The pipelines will run automatically on push to main branch. You can also manually trigger them:
```bash
# View workflow runs
gh run list

# Trigger a workflow manually
gh workflow run applications.yml
```

## Troubleshooting

### Invalid Kubeconfig Error
If you see "error loading config file" in the pipeline logs:
1. Ensure your kubeconfig is valid: `kubectl config view`
2. Re-run the setup script: `./scripts/setup-github-secrets.sh`

### Connection Issues
If the pipeline cannot connect to your cluster:
1. Verify the cluster is running: `kubectl get nodes`
2. Check that the API server is accessible from GitHub Actions
3. Ensure firewall rules allow connections from GitHub's IP ranges

## Security Notes
- The kubeconfig is stored as a base64-encoded GitHub secret
- Only workflows in this repository can access the secret
- Consider using OIDC authentication for production environments