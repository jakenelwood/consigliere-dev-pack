# AI Consigliere K3s Cluster - Operational Runbook

## Quick Start Checklist
- [ ] Export kubeconfig: `export KUBECONFIG=~/.kube/config-ai-consigliere`
- [ ] Verify connectivity: `kubectl get nodes`
- [ ] Check all pods running: `kubectl get pods -A | grep -v Running | grep -v Completed`
- [ ] Verify ingress LB: `curl -I http://5.161.35.135`

## Day 1 - Initial Setup Tasks

### 1. Configure DNS
```bash
# Point your domain to ingress LB
# A Record: *.your-domain.com -> 5.161.35.135
```

### 2. Deploy Cert-Manager ClusterIssuer
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 3. Create Application Namespaces
```bash
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace monitoring
```

## Day 2 Operations

### Daily Health Check (5 min)
```bash
#!/bin/bash
echo "=== Cluster Health Check ==="
kubectl get nodes
echo ""
echo "=== Failed Pods ==="
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""
echo "=== Resource Usage ==="
kubectl top nodes
echo ""
echo "=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | head -20
```

### Monitor Disk Usage
```bash
# Check disk usage on nodes
for node in $(kubectl get nodes -o name | cut -d/ -f2); do
  echo "Node: $node"
  kubectl describe node $node | grep -A 5 "Allocated resources"
done
```

### Certificate Renewal Check
```bash
# Check cert expiration
kubectl get certificate -A
kubectl describe certificate -A | grep "Not After"
```

## Common Scenarios

### Scenario: Application Deployment
```bash
# 1. Create namespace
kubectl create namespace my-app

# 2. Deploy application
kubectl apply -f my-app-deployment.yaml -n my-app

# 3. Expose with service
kubectl expose deployment my-app --port=80 -n my-app

# 4. Create ingress with SSL
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - my-app.your-domain.com
    secretName: my-app-tls
  rules:
  - host: my-app.your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
EOF
```

### Scenario: High Memory Usage Alert
```bash
# 1. Identify high memory pods
kubectl top pods -A --sort-by=memory | head -20

# 2. Check specific pod details
kubectl describe pod <pod-name> -n <namespace>

# 3. Check for memory limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 resources:

# 4. If needed, restart pod
kubectl delete pod <pod-name> -n <namespace>
```

### Scenario: Node Maintenance
```bash
# 1. Cordon node
kubectl cordon ai-consigliere-dev-workload-slz

# 2. Drain workloads
kubectl drain ai-consigliere-dev-workload-slz \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# 3. Perform maintenance
ssh -i ~/.ssh/id_ed25519 root@178.156.142.204
# Do maintenance work
exit

# 4. Uncordon node
kubectl uncordon ai-consigliere-dev-workload-slz

# 5. Verify pods scheduled back
kubectl get pods -A -o wide | grep ai-consigliere-dev-workload-slz
```

### Scenario: Emergency Pod Restart
```bash
# Quick restart all pods in namespace
kubectl rollout restart deployment -n <namespace>

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Scale to zero and back
kubectl scale deployment <deployment> --replicas=0 -n <namespace>
kubectl scale deployment <deployment> --replicas=3 -n <namespace>
```

## Disaster Recovery

### Complete Cluster Recovery
```bash
# 1. Ensure terraform state is safe
cd /home/brian/Dev/consigliere-dev-pack
cp terraform.tfstate terraform.tfstate.backup

# 2. Recreate infrastructure
/tmp/terraform apply -auto-approve

# 3. Get new kubeconfig
/tmp/terraform output -raw kubeconfig > ~/.kube/config-ai-consigliere

# 4. Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Single Node Recovery
```bash
# If a control plane node dies:
# The cluster continues with 2 control planes (still HA)

# If workload node dies:
# 1. Remove from cluster
kubectl delete node ai-consigliere-dev-workload-slz

# 2. Recreate via Terraform
cd /home/brian/Dev/consigliere-dev-pack
/tmp/terraform apply -auto-approve -target=module.kube-hetzner.hcloud_server.agents
```

## Performance Tuning

### Optimize Ingress
```bash
# Edit nginx config
kubectl edit configmap nginx-ingress-nginx-controller -n nginx

# Add optimizations:
data:
  worker-processes: "4"
  worker-connections: "16384"
  keepalive-requests: "10000"
  upstream-keepalive-connections: "512"
```

### Resource Limits Template
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

## Monitoring Commands

### Quick Status Dashboard
```bash
#!/bin/bash
clear
echo "===== K3S CLUSTER STATUS ====="
echo ""
echo "NODES:"
kubectl get nodes
echo ""
echo "SYSTEM PODS:"
kubectl get pods -n kube-system | grep -v Running | grep -v Completed
echo ""
echo "INGRESS:"
kubectl get ingress -A
echo ""
echo "SERVICES:"
kubectl get svc -A | grep LoadBalancer
echo ""
echo "TOP MEMORY USERS:"
kubectl top pods -A --sort-by=memory | head -5
echo ""
echo "TOP CPU USERS:"
kubectl top pods -A --sort-by=cpu | head -5
```

### Watch Real-time Changes
```bash
# Watch pods
watch -n 2 'kubectl get pods -A'

# Watch nodes
watch -n 5 'kubectl get nodes'

# Watch events
kubectl get events -A --watch
```

## Security Operations

### Audit Trail
```bash
# Check recent role bindings
kubectl get rolebindings -A --sort-by='.metadata.creationTimestamp' | tail -10

# Check service accounts
kubectl get serviceaccounts -A

# Review network policies
kubectl get networkpolicies -A
```

### Emergency Access Revocation
```bash
# Delete specific user access
kubectl delete rolebinding <binding-name> -n <namespace>

# Rotate service account token
kubectl delete secret <sa-token-secret>
kubectl delete pod -l app=<app-using-sa> -n <namespace>
```

## Capacity Planning

### Check Current Usage
```bash
# Overall cluster capacity
kubectl get nodes -o json | \
  jq '.items[] | {name:.metadata.name, allocatable:.status.allocatable}'

# Pod count per node
kubectl get pods -A -o wide | \
  grep -v NAME | \
  awk '{print $8}' | \
  sort | uniq -c
```

### Scale Recommendations
- **Control Plane**: 3 nodes optimal (current)
- **Workload Nodes**: Add when:
  - Memory usage > 80% sustained
  - CPU usage > 70% sustained
  - Pod count > 100 per node

## Integration Points

### Hetzner Cloud Console
- URL: https://console.hetzner.cloud/
- Resources: Servers, Load Balancers, Networks, Snapshots

### Load Balancer Endpoints
- Control Plane API: `https://5.161.38.104:6443`
- Ingress HTTP: `http://5.161.35.135`
- Ingress HTTPS: `https://5.161.35.135`

### SSH Access
```bash
# Control Plane Nodes
ssh -i ~/.ssh/id_ed25519 root@178.156.206.174  # cp-ash-a
ssh -i ~/.ssh/id_ed25519 root@178.156.207.4    # cp-ash-b
ssh -i ~/.ssh/id_ed25519 root@5.161.75.72      # cp-ash-c

# Workload Node
ssh -i ~/.ssh/id_ed25519 root@178.156.142.204  # workload
```

## Upgrade Procedures

### K3s Version Upgrade
```bash
# System-upgrade-controller handles this automatically
# To trigger manual upgrade:

# 1. Check current version
kubectl get nodes

# 2. Edit upgrade plan
kubectl edit plan k3s-server -n system-upgrade
kubectl edit plan k3s-agent -n system-upgrade

# 3. Update version field to desired version
# version: v1.31.12+k3s1

# 4. Monitor upgrade
kubectl get nodes -w
```

### Terraform Module Upgrade
```bash
cd /home/brian/Dev/consigliere-dev-pack

# 1. Backup state
cp terraform.tfstate terraform.tfstate.backup

# 2. Update module version in kube.tf
# version = "2.18.1"

# 3. Update modules
/tmp/terraform init -upgrade

# 4. Plan changes
/tmp/terraform plan

# 5. Apply if safe
/tmp/terraform apply
```

## Alert Response

### High CPU Alert
1. Identify: `kubectl top pods -A --sort-by=cpu`
2. Investigate: `kubectl describe pod <pod> -n <ns>`
3. Mitigate: Scale or resource limit adjustment
4. Monitor: `watch kubectl top pod <pod> -n <ns>`

### Disk Pressure Alert
1. Check: `kubectl describe nodes | grep -i pressure`
2. Clean: `kubectl delete pod -A --field-selector status.phase=Failed`
3. Prune: `ssh root@<node> && crictl rmi --prune`
4. Monitor: `df -h` on affected nodes

### Network Issues
1. Test: `kubectl run test --image=busybox --rm -it -- wget -O- http://service`
2. Check DNS: `kubectl run test --image=busybox --rm -it -- nslookup kubernetes`
3. Review: `kubectl logs -n kube-system -l k8s-app=kube-dns`
4. Restart if needed: `kubectl rollout restart -n kube-system deployment/coredns`

## Contact Escalation

1. **Infrastructure Issues**: Hetzner Cloud Console
2. **K3s Issues**: https://github.com/k3s-io/k3s/issues
3. **Module Issues**: https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/issues

---

*Keep this runbook updated with lessons learned from incidents.*
*Last Updated: August 26, 2025*