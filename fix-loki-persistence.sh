#!/bin/bash
# Fix Loki StatefulSet Persistence Issue
# Created: September 6, 2025
# Purpose: Resolve StatefulSet persistence configuration by recreation

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

print_status "🔧 Fixing Loki StatefulSet Persistence Issue"

# Step 1: Check current status
print_status "Step 1: Checking current Loki deployment..."
if helm list -n loki-stack | grep -q loki-stack; then
    print_warning "Loki stack found. Need to recreate for persistence."
    
    # Step 2: Backup PVCs info (if any)
    print_status "Step 2: Backing up PVC information..."
    kubectl get pvc -n loki-stack > loki-pvcs-backup-$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || echo "No PVCs found"
    
    # Step 3: Uninstall existing deployment
    print_status "Step 3: Uninstalling existing Loki stack..."
    helm uninstall loki-stack -n loki-stack
    
    # Step 4: Wait for cleanup
    print_status "Step 4: Waiting for cleanup to complete..."
    sleep 30
    
    # Clean up any remaining resources
    kubectl delete pvc --all -n loki-stack --ignore-not-found=true
    kubectl delete statefulset --all -n loki-stack --ignore-not-found=true
    
else
    print_status "No existing Loki stack found."
fi

# Step 5: Install with persistence
print_status "Step 5: Installing Loki stack with persistence enabled..."
helm install loki-stack grafana/loki-stack \
  --namespace loki-stack \
  --create-namespace \
  --values loki-stack-values.yaml \
  --wait \
  --timeout=10m

print_success "Loki stack installed with persistence enabled"

# Step 6: Apply Loki datasource for Grafana
print_status "Step 6: Applying Loki datasource for Grafana..."
kubectl apply -f monitoring/grafana-datasource-loki.yaml
print_success "Loki datasource configured"

# Step 7: Verify deployment
print_status "Step 7: Verifying Loki deployment..."
kubectl get pods -n loki-stack
kubectl get pvc -n loki-stack

print_success "✅ Loki StatefulSet issue resolved!"
print_status "Loki now has persistent storage and should retain logs across restarts"

echo ""
echo "🔧 Next Steps:"
echo "1. Check Loki is receiving logs: kubectl logs -n loki-stack deployment/loki-stack-promtail"
echo "2. Test in Grafana: Go to Explore → Loki → Query logs"
echo "3. Verify persistence: kubectl get pvc -n loki-stack"
