#!/bin/bash

# Setup GitHub Secrets for CI/CD Pipeline
# This script helps configure the required secrets for GitHub Actions

set -e

echo "GitHub Secrets Setup for Kube-Hetzner CI/CD"
echo "==========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Please run: gh auth login"
    exit 1
fi

# Get repository name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    echo "Error: Could not detect repository. Are you in a git repository?"
    exit 1
fi

echo "Repository: $REPO"
echo ""

# Function to set secret
set_secret() {
    local name=$1
    local value=$2
    echo "Setting secret: $name"
    echo "$value" | gh secret set "$name" --repo="$REPO"
}

# Check for kubeconfig
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Error: Kubeconfig not found at $KUBECONFIG_PATH"
    echo ""
    echo "To get your kubeconfig from Terraform:"
    echo "  terraform output -raw kubeconfig > ~/.kube/config"
    exit 1
fi

echo "Found kubeconfig at: $KUBECONFIG_PATH"
echo ""

# Validate kubeconfig
if ! kubectl config view --minify &> /dev/null; then
    echo "Error: Invalid kubeconfig format"
    exit 1
fi

# Create base64 encoded kubeconfig
echo "Creating base64 encoded kubeconfig..."
KUBECONFIG_BASE64=$(cat "$KUBECONFIG_PATH" | base64 -w 0)

# Set the secret
echo "Setting GitHub secret KUBECONFIG_BASE64..."
set_secret "KUBECONFIG_BASE64" "$KUBECONFIG_BASE64"

echo ""
echo "✓ GitHub secrets configured successfully!"
echo ""
echo "The following secret has been set:"
echo "  - KUBECONFIG_BASE64: Base64 encoded kubeconfig for cluster access"
echo ""
echo "Your CI/CD pipeline is now configured to deploy to your cluster."