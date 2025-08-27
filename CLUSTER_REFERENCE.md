# AI Consigliere K3s Cluster Reference Documentation

## Quick Access
```bash
# Set kubeconfig for this session
export KUBECONFIG=~/.kube/config-ai-consigliere

# Or use inline for single commands
kubectl --kubeconfig ~/.kube/config-ai-consigliere get nodes
```

## Cluster Infrastructure

### Nodes
| Node Role | Server Type | Name | Public IP | Private IP | Location |
|-----------|------------|------|-----------|------------|----------|
| Control Plane #1 | CCX13 (80GB NVMe) | ai-consigliere-dev-cp-ash-a-swj | 178.156.206.174 | 10.64.0.101 | Ashburn, VA |
| Control Plane #2 | CCX13 (80GB NVMe) | ai-consigliere-dev-cp-ash-b-dxw | 178.156.207.4 | 10.64.64.101 | Ashburn, VA |
| Control Plane #3 | CCX13 (80GB NVMe) | ai-consigliere-dev-cp-ash-c-fbh | 5.161.75.72 | 10.64.128.101 | Ashburn, VA |
| Workload Node | CCX33 (160GB NVMe) | ai-consigliere-dev-workload-slz | 178.156.142.204 | 10.0.0.101 | Ashburn, VA |

### Load Balancers
| Purpose | Name | Public IP | Port | Status |
|---------|------|-----------|------|--------|
| Control Plane API | ai-consigliere-dev-control-plane | 5.161.38.104 | 6443 | Healthy |
| Ingress (HTTP/HTTPS) | ai-consigliere-dev-nginx | 5.161.35.135 | 80, 443 | Healthy |

### Network Configuration
- **Region**: us-east
- **Location**: ash (Ashburn, VA)
- **Private Network**: 10.0.0.0/12
- **Placement Groups**: 
  - `cp-spread` - Control plane nodes (physical host separation)
  - `agent-spread` - Workload nodes (physical host separation)

## System Components

### Core Services
- **Kubernetes Version**: v1.31.11+k3s1
- **Container Runtime**: containerd 2.0.5-k3s2.32
- **OS**: openSUSE MicroOS
- **Kernel**: 6.16.1-1-default

### Deployed Add-ons
| Component | Namespace | Purpose |
|-----------|-----------|---------|
| cert-manager | cert-manager | SSL certificate management |
| nginx-ingress | nginx | Ingress controller for HTTP/HTTPS traffic |
| hcloud-cloud-controller-manager | kube-system | Hetzner Cloud integration |
| hcloud-csi | kube-system | Persistent volume support |
| coredns | kube-system | Cluster DNS |
| metrics-server | kube-system | Resource metrics |
| kured | kube-system | Automatic node reboots |
| system-upgrade-controller | system-upgrade | K3s upgrades |

## Common Operations

### Cluster Access
```bash
# Export kubeconfig for session
export KUBECONFIG=~/.kube/config-ai-consigliere

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# View component health
kubectl get componentstatuses
```

### Node Management
```bash
# Get node details
kubectl describe node <node-name>

# Cordon node (prevent new pods)
kubectl cordon <node-name>

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node after maintenance
kubectl uncordon <node-name>

# Label nodes
kubectl label nodes ai-consigliere-dev-workload-slz workload=app
```

### Debugging & Troubleshooting
```bash
# View pod logs
kubectl logs -n <namespace> <pod-name>

# Get pod events
kubectl describe pod -n <namespace> <pod-name>

# Execute into pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Get ingress details
kubectl get ingress -A
kubectl describe ingress -n <namespace> <ingress-name>
```

### Application Deployment
```bash
# Create namespace
kubectl create namespace my-app

# Deploy application
kubectl apply -f deployment.yaml

# Scale deployment
kubectl scale deployment/my-app --replicas=3 -n my-app

# Create service
kubectl expose deployment my-app --port=80 --target-port=8080 -n my-app

# Create ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: my-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: my-app.example.com
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

### Storage Operations
```bash
# List storage classes
kubectl get storageclass

# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: hcloud-volumes
  resources:
    requests:
      storage: 10Gi
EOF

# Check PVC status
kubectl get pvc -n my-app
```

## Terraform Management

### Directory Structure
```
/home/brian/Dev/consigliere-dev-pack/
├── kube.tf                 # Main configuration
├── terraform.tfvars        # Variables (contains token)
├── terraform.tfstate       # Current state
└── .terraform/             # Modules
```

### Common Terraform Commands
```bash
cd /home/brian/consigliere-dev-pack

# Check planned changes
/tmp/terraform plan

# Apply changes
/tmp/terraform apply

# Destroy cluster (CAREFUL!)
/tmp/terraform destroy

# Refresh state
/tmp/terraform refresh

# Output kubeconfig
/tmp/terraform output -raw kubeconfig
```

## Monitoring & Maintenance

### Health Checks
```bash
# Cluster health
kubectl get cs
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed

# Certificate status
kubectl get certificate -A
kubectl describe certificate -A

# Ingress status
kubectl get ingress -A
kubectl describe ingress -A
```

### Resource Monitoring
```bash
# Node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Pod resource usage
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Check for pending pods
kubectl get pods -A | grep Pending
```

### Log Collection
```bash
# System component logs
kubectl logs -n kube-system -l app=hcloud-cloud-controller-manager
kubectl logs -n nginx -l app.kubernetes.io/name=ingress-nginx
kubectl logs -n cert-manager -l app=cert-manager

# All logs from namespace
kubectl logs -n <namespace> --all-containers=true --since=1h
```

## Security Considerations

### Network Security
- SSH access restricted to configured CIDR blocks
- Kubernetes API access restricted to configured CIDR blocks
- All inter-node communication via private network
- Firewall rules managed by Hetzner Cloud

### Best Practices
1. Always use namespaces for application isolation
2. Apply NetworkPolicies for pod-to-pod communication
3. Use RBAC for access control
4. Regularly update k3s version via system-upgrade-controller
5. Monitor audit logs for suspicious activity

## Backup & Recovery

### Backup Critical Data
```bash
# Backup etcd (run on control plane)
kubectl exec -n kube-system etcd-<node-name> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  snapshot save /tmp/etcd-backup.db

# Export all resources
kubectl get all -A -o yaml > cluster-resources.yaml

# Backup persistent volumes
kubectl get pv -o yaml > persistent-volumes.yaml
```

## Useful Aliases
```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl --kubeconfig ~/.kube/config-ai-consigliere'
alias kga='kubectl --kubeconfig ~/.kube/config-ai-consigliere get all -A'
alias kgn='kubectl --kubeconfig ~/.kube/config-ai-consigliere get nodes'
alias kgp='kubectl --kubeconfig ~/.kube/config-ai-consigliere get pods -A'
alias klog='kubectl --kubeconfig ~/.kube/config-ai-consigliere logs'
alias kdesc='kubectl --kubeconfig ~/.kube/config-ai-consigliere describe'
```

## Troubleshooting Quick Reference

### Pod Won't Start
1. Check events: `kubectl describe pod <pod-name> -n <namespace>`
2. Check logs: `kubectl logs <pod-name> -n <namespace>`
3. Check resources: `kubectl describe nodes`
4. Check PVC: `kubectl get pvc -n <namespace>`

### Can't Access Application
1. Check ingress: `kubectl get ingress -n <namespace>`
2. Check service: `kubectl get svc -n <namespace>`
3. Check endpoints: `kubectl get endpoints -n <namespace>`
4. Check nginx logs: `kubectl logs -n nginx -l app.kubernetes.io/name=ingress-nginx`

### Node Issues
1. Check node status: `kubectl describe node <node-name>`
2. Check system pods: `kubectl get pods -n kube-system -o wide | grep <node-name>`
3. SSH to node: `ssh -i ~/.ssh/id_ed25519 root@<node-ip>`
4. Check k3s service: `systemctl status k3s-agent` or `systemctl status k3s`

## Contact & Support

- **Cluster Name**: ai-consigliere-dev
- **Terraform Module**: kube-hetzner/kube-hetzner/hcloud v2.18.0
- **Module Docs**: https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner
- **Hetzner Console**: https://console.hetzner.cloud/
- **Created**: August 26, 2025

---

*Last Updated: August 26, 2025*