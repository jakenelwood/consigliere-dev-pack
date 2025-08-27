SHELL := /bin/bash

.PHONY: init plan up kubeconfig down fmt addons dns stackgres-op stackgres qdrant

init:
	terraform init

plan:
	terraform plan -out=tfplan

up: init
	terraform apply -auto-approve

kubeconfig:
	@terraform output -raw kubeconfig > kubeconfig
	@echo "Wrote kubeconfig to ./kubeconfig"
	@echo "Run: export KUBECONFIG=\$$PWD/kubeconfig"

fmt:
	terraform fmt -recursive

down:
	terraform destroy

# === Add-ons ===
# Apply NodeLocal DNSCache, install StackGres operator + a small SGCluster, and Qdrant with persistence
addons: dns stackgres qdrant

# NodeLocal DNSCache
dns:
	kubectl apply -f manifests/nodelocal-dns.yaml

# StackGres operator (CRDs installed by chart)
stackgres-op:
	helm repo add stackgres https://stackgres.io/downloads/stackgres/helm/ || true
	helm repo update
	helm upgrade --install stackgres-operator stackgres/stackgres-operator \
	  --namespace stackgres-operator --create-namespace

# Minimal dev SGCluster (namespace + cluster CR)
stackgres: stackgres-op
	kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f manifests/stackgres/sgcluster.yaml

# Qdrant vector DB (persisted to hcloud volumes)
qdrant:
	helm repo add qdrant https://qdrant.github.io/qdrant-helm || true
	helm repo update
	helm upgrade --install qdrant qdrant/qdrant -n data --create-namespace \
	  -f values/qdrant-values.yaml

# Quick status check
status:
	@echo "=== Nodes ==="
	@kubectl get nodes
	@echo ""
	@echo "=== Pods in all namespaces ==="
	@kubectl get pods -A
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -A | grep -E "(LoadBalancer|postgres|qdrant)"