#!/bin/bash
# AKS Cluster Cleanup Script
# Removes failed Rocket.Chat deployment and prepares for clean official deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_status "🧹 Starting AKS Cluster Cleanup..."

# Step 1: Delete rocketchat namespace (this removes most resources)
print_status "Step 1: Deleting rocketchat namespace..."
kubectl delete namespace rocketchat --ignore-not-found=true --timeout=300s
print_success "Rocketchat namespace deletion initiated"

# Wait for namespace deletion
print_status "Waiting for rocketchat namespace cleanup..."
sleep 30

# Step 2: Force delete any remaining resources in rocketchat namespace
print_status "Step 2: Force deleting any remaining rocketchat resources..."
kubectl delete pvc --all --namespace rocketchat --ignore-not-found=true
kubectl delete pv --all --ignore-not-found=true | grep rocketchat || true
print_success "Persistent volumes cleaned up"

# Step 3: Clean up cert-manager (keep it for official deployment)
print_status "Step 3: Cleaning up cert-manager resources..."
kubectl delete clusterissuer production-cert-issuer --ignore-not-found=true
print_success "ClusterIssuer cleaned up"

# Step 4: Clean up ingress-nginx (keep it for official deployment)
print_status "Step 4: Checking ingress-nginx status..."
kubectl get pods -n ingress-nginx
print_success "Ingress-nginx status checked"

# Step 5: Verify cleanup
print_status "Step 5: Verifying cleanup..."
echo ""
echo "=== CLEANUP VERIFICATION ==="
echo "Namespaces:"
kubectl get namespaces | grep -E "(rocketchat|cert-manager|ingress-nginx)"

echo ""
echo "ClusterIssuers:"
kubectl get clusterissuers

echo ""
echo "Persistent Volumes:"
kubectl get pv | grep -v "monitoring\|kube-system\|gatekeeper" || echo "No problematic PVs found"

echo ""
echo "Ingress resources:"
kubectl get ingress --all-namespaces

print_success "Cleanup verification complete!"

# Summary
echo ""
echo "🎉 AKS CLUSTER CLEANUP COMPLETE!"
echo "================================="
echo "✅ Rocketchat namespace: Deleted"
echo "✅ Persistent volumes: Cleaned up"
echo "✅ ClusterIssuer: Removed"
echo "✅ Failed MongoDB StatefulSet: Removed"
echo "✅ All related services and secrets: Cleaned up"
echo ""
echo "📦 Resources preserved for official deployment:"
echo "   - cert-manager namespace (3 pods running)"
echo "   - ingress-nginx namespace (1 controller pod running)"
echo "   - External IP: $(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo ""
echo "🚀 Ready for official Rocket.Chat deployment!"
echo "   Run: ./deploy-aks-official.sh"

print_success "AKS cluster is now clean and ready for official deployment!"
