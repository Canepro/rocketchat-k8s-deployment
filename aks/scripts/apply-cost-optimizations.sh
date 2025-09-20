#!/bin/bash

# 🚀 Cost Optimization Deployment Script
# Applies resource rightsizing optimizations for cost reduction
# Date: September 19, 2025

set -e

echo "💰 Applying Cost Optimizations for Rocket.Chat AKS Deployment"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pre-deployment checks
print_status "Performing pre-deployment checks..."

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "kubectl not configured or cluster not accessible"
    exit 1
fi

# Check current resource usage
print_status "Checking current resource usage..."
kubectl top pods -n rocketchat > /tmp/pre-optimization-resources.txt 2>/dev/null || print_warning "Unable to get resource metrics (metrics-server may not be available)"

# Backup current configurations
print_status "Creating configuration backups..."
cp aks/config/helm-values/values-official.yaml aks/config/helm-values/values-official-backup-$(date +%Y%m%d-%H%M%S).yaml
cp aks/config/mongodb-standalone.yaml aks/config/mongodb-standalone-backup-$(date +%Y%m%d-%H%M%S).yaml

print_success "Backups created successfully"

# Apply Rocket.Chat optimizations
print_status "Applying Rocket.Chat resource optimizations..."
helm upgrade rocketchat rocketchat/rocketchat \
  -f aks/config/helm-values/values-official.yaml \
  -n rocketchat \
  --wait \
  --timeout 600s

if [ $? -eq 0 ]; then
    print_success "Rocket.Chat optimizations applied successfully"
else
    print_error "Failed to apply Rocket.Chat optimizations"
    exit 1
fi

# Apply MongoDB optimizations
print_status "Applying MongoDB resource optimizations..."
kubectl apply -f aks/config/mongodb-standalone.yaml

if [ $? -eq 0 ]; then
    print_success "MongoDB optimizations applied successfully"
else
    print_error "Failed to apply MongoDB optimizations"
    exit 1
fi

# Wait for rollout to complete
print_status "Waiting for deployments to stabilize..."
kubectl rollout status deployment/rocketchat-rocketchat -n rocketchat --timeout=300s
kubectl rollout status statefulset/mongodb -n rocketchat --timeout=300s

# Post-deployment verification
print_status "Performing post-deployment verification..."

# Check pod status
print_status "Checking pod status..."
kubectl get pods -n rocketchat

# Check resource usage after optimization
print_status "Checking resource usage after optimization..."
kubectl top pods -n rocketchat > /tmp/post-optimization-resources.txt 2>/dev/null || print_warning "Unable to get resource metrics"

# Display optimization summary
echo ""
echo "🎯 Cost Optimization Summary"
echo "==========================="
echo ""
echo "✅ Applied Optimizations:"
echo "   • Rocket.Chat CPU limit: 1000m → 500m (-50%)"
echo "   • Rocket.Chat Memory limit: 2Gi → 1.5Gi (-25%)"
echo "   • MongoDB CPU limit: 1000m → 300m (-70%)"
echo "   • MongoDB Memory limit: 2Gi → 512Mi (-75%)"
echo ""
echo "📊 Expected Cost Savings:"
echo "   • Monthly savings: £5-10/month"
echo "   • Total reduction: 15-25% of compute costs"
echo ""
echo "🔍 Monitoring Recommendations:"
echo "   • Monitor performance for 24-48 hours"
echo "   • Check Grafana dashboards for any issues"
echo "   • Review logs for application errors"
echo ""
echo "📞 Rollback Plan:"
echo "   • If issues occur, use backup configurations"
echo "   • Previous configs saved with timestamp"
echo ""
print_success "Cost optimization deployment completed successfully!"

echo ""
print_status "Next steps:"
echo "1. Monitor application performance for 24 hours"
echo "2. Check Grafana dashboards for any anomalies"
echo "3. Review Azure Cost Management for savings"
echo "4. Consider storage optimization in next phase"
