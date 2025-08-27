# Operations Runbook - Kube-Hetzner CI/CD

## Quick Reference

### Pipeline Health Check
```bash
# Check all pipelines status
gh run list --limit 5

# Check specific pipeline
gh run list --workflow=applications.yml --limit 3

# View failed runs
gh run list --status failure --limit 5
```

## Common Operational Tasks

### 1. Emergency Pipeline Stop
```bash
# List running workflows
gh run list --status in_progress

# Cancel specific run
gh run cancel <run-id>

# Cancel all running workflows
gh run list --status in_progress --json databaseId | jq '.[].databaseId' | xargs -I {} gh run cancel {}
```

### 2. Manual Deployment Trigger
```bash
# Deploy applications
gh workflow run applications.yml

# Test cluster connection
gh workflow run test-connection.yml

# Run security scan
gh workflow run security.yml
```

### 3. Rollback Deployment

#### Option A: Revert Last Commit
```bash
# Revert the last commit
git revert HEAD
git push origin main

# Or revert to specific commit
git revert <commit-hash>
git push origin main
```

#### Option B: Deploy Previous Version
```bash
# Check out previous working state
git checkout <known-good-commit>

# Create a new branch and push
git checkout -b hotfix/rollback-$(date +%s)
git push origin hotfix/rollback-$(date +%s)

# Create PR to main
gh pr create --title "Rollback to stable version" --body "Emergency rollback"
```

### 4. Debug Failed Deployments

#### Get Detailed Logs
```bash
# View full logs for failed run
gh run view <run-id> --log-failed

# Download all logs
gh run download <run-id>
cd <run-id>
find . -name "*.txt" | xargs grep -l "error"
```

#### Check Cluster State
```bash
# Verify cluster connectivity
kubectl get nodes

# Check failing pods
kubectl get pods --all-namespaces | grep -v Running

# Get pod logs
kubectl logs -n <namespace> <pod-name> --tail=50

# Describe problematic resources
kubectl describe pod -n <namespace> <pod-name>
```

### 5. Fix Common Issues

#### StackGres CRDs Missing
```bash
# Check if operator is running
kubectl get pods -n stackgres

# Manually install CRDs if needed
kubectl apply -f https://stackgres.io/downloads/stackgres-k8s/stackgres/latest/crd.yaml

# Restart operator
kubectl rollout restart deployment -n stackgres stackgres-operator
```

#### Helm Repository Issues
```bash
# Manually add repositories
helm repo add stackgres https://stackgres.io/downloads/stackgres-k8s/stackgres/helm
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo update

# List configured repos
helm repo list
```

#### Kubeconfig Secret Issues
```bash
# Verify secret exists
gh secret list | grep KUBECONFIG

# Re-create the secret
./scripts/setup-github-secrets.sh

# Test locally
echo "$KUBECONFIG_BASE64" | base64 -d > /tmp/test-config
kubectl --kubeconfig=/tmp/test-config get nodes
rm /tmp/test-config
```

### 6. Monitor Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods --all-namespaces --sort-by=memory

# Check PVC usage
kubectl get pvc --all-namespaces

# Check events for issues
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

### 7. Clean Up Stuck Resources

#### Remove Finalizers from Stuck Namespace
```bash
# Get stuck namespace
kubectl get namespace <namespace> -o json > ns.json

# Edit ns.json, remove finalizers array
vi ns.json

# Replace the namespace
kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f ns.json
```

#### Force Delete Stuck Pods
```bash
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

### 8. Disaster Recovery

#### Backup Critical Resources
```bash
# Export all deployments
kubectl get deployments --all-namespaces -o yaml > deployments-backup.yaml

# Export all services
kubectl get services --all-namespaces -o yaml > services-backup.yaml

# Export all configmaps
kubectl get configmaps --all-namespaces -o yaml > configmaps-backup.yaml

# Create full backup
kubectl get all --all-namespaces -o yaml > full-backup.yaml
```

#### Restore from Backup
```bash
# Apply backup files
kubectl apply -f deployments-backup.yaml
kubectl apply -f services-backup.yaml
kubectl apply -f configmaps-backup.yaml
```

## Performance Optimization

### Pipeline Speed Improvements
1. **Parallel Jobs**: Workflows run validation and deployment in parallel where possible
2. **Caching**: Helm repositories are cached after first add
3. **Skip Redundant Steps**: Operators only install if namespace doesn't exist

### Resource Optimization
```bash
# Find resource-heavy pods
kubectl top pods --all-namespaces --sort-by=cpu | head -10

# Scale down non-critical deployments
kubectl scale deployment <name> -n <namespace> --replicas=0

# Clean up completed jobs
kubectl delete jobs --field-selector status.successful=1 --all-namespaces
```

## Monitoring & Alerts

### Set Up GitHub Notifications
```bash
# Watch a repository
gh repo set-default jakenelwood/consigliere-dev-pack

# Enable notifications for workflow failures
# Go to: https://github.com/settings/notifications
# Enable: Actions -> Failed workflow runs
```

### Quick Health Dashboard
```bash
#!/bin/bash
echo "=== Cluster Health ==="
kubectl get nodes
echo ""
echo "=== Recent Pipeline Runs ==="
gh run list --limit 3
echo ""
echo "=== Failed Pods ==="
kubectl get pods --all-namespaces | grep -v "Running\|Completed" | head -10
echo ""
echo "=== Recent Events ==="
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "error\|failed" | tail -5
```

## Escalation Procedures

### Severity Levels

#### SEV 1 - Critical (Production Down)
1. Check cluster connectivity: `kubectl get nodes`
2. Check load balancer: `kubectl get svc -n ingress-nginx`
3. Rollback if recent deployment: See "Rollback Deployment" section
4. Contact: Infrastructure team immediately

#### SEV 2 - Major (Degraded Service)
1. Identify failing components: `kubectl get pods --all-namespaces | grep -v Running`
2. Check logs: `kubectl logs -n <namespace> <pod>`
3. Restart failed pods: `kubectl delete pod -n <namespace> <pod>`
4. Monitor recovery: `watch kubectl get pods --all-namespaces`

#### SEV 3 - Minor (Non-Critical Issues)
1. Document in GitHub issue
2. Schedule fix for next maintenance window
3. Add to backlog for resolution

## Maintenance Windows

### Pre-Maintenance Checklist
- [ ] Announce maintenance window
- [ ] Backup current state
- [ ] Prepare rollback plan
- [ ] Test changes in dev environment
- [ ] Have runbook ready

### Post-Maintenance Verification
- [ ] All pods running: `kubectl get pods --all-namespaces`
- [ ] Services accessible: `kubectl get svc --all-namespaces`
- [ ] Ingress working: `curl -I https://<your-domain>`
- [ ] Pipeline status green: `gh run list --limit 3`
- [ ] No critical events: `kubectl get events --all-namespaces`

## Security Incident Response

### Suspected Secret Exposure
1. Rotate the exposed secret immediately
2. Update GitHub secret: `gh secret set <name>`
3. Restart affected deployments
4. Review TruffleHog scan results
5. Audit access logs

### Failed Security Scans
1. Review Checkov results in pipeline logs
2. Determine if violation is false positive
3. If valid, create issue for remediation
4. If false positive, add to skip_check list

## Contact Information

### Escalation Path
1. **On-Call Engineer**: Check PagerDuty
2. **Infrastructure Team**: #infrastructure Slack
3. **Security Team**: #security Slack
4. **Platform Lead**: See team directory

### External Resources
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Hetzner Cloud Console](https://console.hetzner.cloud/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [StackGres Documentation](https://stackgres.io/doc/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)

## Useful Aliases

Add to your shell profile:
```bash
# Pipeline shortcuts
alias pl="gh run list --limit 10"
alias pf="gh run list --status failure --limit 5"
alias pd="gh workflow run applications.yml"

# Kubernetes shortcuts
alias kgp="kubectl get pods --all-namespaces"
alias kgn="kubectl get nodes"
alias kge="kubectl get events --all-namespaces --sort-by='.lastTimestamp'"
alias ktop="kubectl top pods --all-namespaces --sort-by=memory"

# Troubleshooting
alias kerrors="kubectl get events --all-namespaces | grep -i error"
alias kfailed="kubectl get pods --all-namespaces | grep -v 'Running\|Completed'"
```