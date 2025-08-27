# CI/CD Pipeline Setup Guide

## Overview
This repository uses GitHub Actions for continuous deployment to the Kube-Hetzner cluster.

## Pipeline Architecture

### Workflows
1. **Application Deployment** (`applications.yml`) - Deploys applications to the cluster
2. **Security Scanning** (`security.yml`) - Runs security checks on code and manifests  
3. **Test Connection** (`test-connection.yml`) - Validates cluster connectivity

### Deployment Order
1. Core Services (StackGres, Qdrant, NodeLocal DNS)
2. Application manifests from `k8s/`, `apps/`, and `manifests/` directories
3. Health checks and validation

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

# Check specific workflow status
gh run list --workflow=applications.yml --limit 5
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. StackGres CRD Not Found
**Error:** `no matches for kind "SGCluster" in version "stackgres.io/v1"`
**Solution:** The pipeline now waits for CRDs to be installed. If this still occurs:
- Check if StackGres operator is running: `kubectl get pods -n stackgres`
- Verify CRDs are installed: `kubectl get crd sgclusters.stackgres.io`
- The pipeline will wait up to 60 seconds for CRDs to be ready

#### 2. Empty Directory Errors
**Error:** `error reading [apps/]: recognized file extensions are [.json .yaml .yml]`
**Solution:** The pipeline now skips directories without YAML files. Directories with only `.gitkeep` are ignored.

#### 3. Helm Repository Issues
**Error:** `failed to fetch https://...index.yaml : 404 Not Found`
**Solution:** The pipeline includes retry logic (3 attempts) for Helm repositories. If it still fails:
- Verify the repository URL is correct
- Check if the repository is temporarily down
- Manual fix: Update the Helm repo URL in `.github/workflows/applications.yml`

#### 4. Invalid Kubeconfig
**Error:** `error loading config file` or `current-context must exist`
**Solution:** 
1. Ensure your kubeconfig is valid: `kubectl config view`
2. Re-run the setup script: `./scripts/setup-github-secrets.sh`
3. Verify the secret is set: `gh secret list`

#### 5. Connection Issues
**Error:** `Unable to connect to the server`
**Solution:**
1. Verify the cluster is running: `kubectl get nodes`
2. Check that the API server is accessible from GitHub Actions
3. Ensure firewall rules allow connections from GitHub's IP ranges
4. The cluster API endpoint must be publicly accessible

#### 6. Security Scan Failures
**Note:** Security scanning is now non-blocking (soft_fail enabled)
- Policy violations will be reported but won't fail the pipeline
- SARIF upload is disabled by default (requires GitHub Advanced Security)
- To enable strict security checks: Remove `soft_fail: true` from `security.yml`

### Deployment Behavior

#### Operator Installation
- StackGres and Qdrant operators are only installed if their namespaces don't exist
- This prevents reinstalling operators on every pipeline run
- To force reinstall: Delete the namespace first

#### Manifest Deployment
The pipeline deploys from these directories in order:
1. `apps/` - Application manifests
2. `k8s/` - Kubernetes resources
3. `manifests/stackgres/` - Database clusters (only if CRDs exist)
4. `manifests/` - Other manifests

Each file is applied individually for better error visibility.

### Pipeline Features

#### Retry Logic
- Helm repository additions: 3 attempts with 5-second delays
- CRD availability check: 30 attempts with 2-second delays

#### Validation
- Pre-deployment YAML syntax validation
- Directory content checking before kubectl apply
- Individual file deployment for error isolation

#### Logging
- Clear status messages for each operation
- File-by-file deployment tracking
- Total deployment count at the end

## Security Notes

### Secrets Management
- The kubeconfig is stored as a base64-encoded GitHub secret
- Only workflows in this repository can access the secret
- Never commit kubeconfig files to the repository

### Security Scanning
- Checkov scans Terraform and Kubernetes manifests
- TruffleHog scans for secrets in code
- Dependency check for vulnerable dependencies
- All security scans run in soft-fail mode by default

### Best Practices
- Use OIDC authentication for production environments
- Regularly rotate cluster credentials
- Review security scan results even when non-blocking
- Enable GitHub Advanced Security for SARIF uploads if available

## Monitoring Pipelines

### Quick Status Check
```bash
# Check all recent runs
gh run list --limit 10

# Check failed runs only
gh run list --status failure

# View specific run details
gh run view <run-id>

# View logs for failed jobs
gh run view <run-id> --log-failed
```

### Manual Intervention
If a deployment is stuck:
```bash
# Cancel a running workflow
gh run cancel <run-id>

# Re-run a failed workflow
gh run rerun <run-id>

# Download workflow logs
gh run download <run-id>
```