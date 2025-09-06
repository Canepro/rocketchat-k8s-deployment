#!/bin/bash
# Apply Monitoring Configuration Fixes
# Created: September 6, 2025
# Purpose: Apply the configuration fixes for enhanced monitoring

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

print_status "🔧 Applying Enhanced Monitoring Configuration Fixes"

# Step 1: Apply fixed PodMonitor configuration
print_status "Step 1: Applying fixed PodMonitor configuration..."
kubectl apply -f monitoring/rocket-chat-podmonitor.yaml
print_success "PodMonitor configuration applied"

# Step 2: Remove old ServiceMonitor if it exists
print_status "Step 2: Cleaning up old ServiceMonitor..."
kubectl delete servicemonitor rocketchat-servicemonitor -n monitoring --ignore-not-found=true
print_success "ServiceMonitor cleanup completed"

# Step 3: Update Rocket.Chat deployment with fixed values
print_status "Step 3: Updating Rocket.Chat deployment (ServiceMonitor disabled)..."
helm upgrade rocketchat rocketchat/rocketchat \
  --namespace rocketchat \
  --values values-official.yaml \
  --wait \
  --timeout=10m
print_success "Rocket.Chat deployment updated"

# Step 4: Deploy/Update Loki with persistence enabled (handle StatefulSet issue)
print_status "Step 4: Updating Loki stack with persistence enabled..."

# Check if Loki stack exists
if helm list -n loki-stack | grep -q loki-stack; then
    print_warning "Existing Loki stack found. StatefulSet persistence changes require recreation."
    print_status "Backing up current Loki configuration..."
    kubectl get pvc -n loki-stack > loki-backup-pvcs.txt 2>/dev/null || echo "No PVCs to backup"
    
    print_status "Uninstalling existing Loki stack..."
    helm uninstall loki-stack -n loki-stack
    
    print_status "Waiting for cleanup..."
    sleep 30
    
    print_status "Installing Loki stack with persistence enabled..."
    helm install loki-stack grafana/loki-stack \
      --namespace loki-stack \
      --create-namespace \
      --values loki-stack-values.yaml \
      --wait \
      --timeout=10m
else
    print_status "Installing new Loki stack with persistence enabled..."
    helm install loki-stack grafana/loki-stack \
      --namespace loki-stack \
      --create-namespace \
      --values loki-stack-values.yaml \
      --wait \
      --timeout=10m
fi

print_success "Loki stack deployed with persistence enabled"

# Step 5: Apply Loki datasource for Grafana
print_status "Step 5: Applying Loki datasource for Grafana..."
kubectl apply -f monitoring/grafana-datasource-loki.yaml
print_success "Loki datasource configured"

# Step 6: Verify deployments
print_status "Step 6: Verifying deployments..."

print_status "Checking Rocket.Chat pods..."
kubectl get pods -n rocketchat

print_status "Checking monitoring pods..."
kubectl get pods -n monitoring

print_status "Checking Loki stack pods..."
kubectl get pods -n loki-stack

print_status "Checking PodMonitor..."
kubectl get podmonitors -n monitoring

print_status "Checking ServiceMonitors (should show only system ones)..."
kubectl get servicemonitors -n monitoring

# Step 7: Test metrics collection
print_status "Step 7: Testing metrics collection..."
print_warning "You can test metrics collection by:"
echo "1. Port-forward to Prometheus: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo "2. Visit: http://localhost:9090/targets"
echo "3. Look for rocketchat targets in 'up' state"
echo ""
echo "🌐 Access URLs:"
echo "   Rocket.Chat: https://chat.canepro.me"
echo "   Grafana: https://grafana.chat.canepro.me"
echo ""
echo "🔧 Next Steps:"
echo "1. Check Prometheus targets are 'up'"
echo "2. Verify Grafana dashboards are working"
echo "3. Test Loki log collection"
echo "4. Monitor for any alerts"

print_success "✅ Enhanced monitoring configuration fixes applied successfully!"
print_warning "⚠️  Please verify that all services are working correctly"
