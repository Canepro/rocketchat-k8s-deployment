#!/bin/bash
# Fix MongoDB Image Pull Issue for Rocket.Chat on AKS
# This script fixes the MongoDB image pull issue by using Docker Hub instead of ghcr.io

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

print_status "🔧 Starting MongoDB Image Fix for Rocket.Chat Deployment"
echo ""

# Step 1: Check current status
print_status "Step 1: Checking current deployment status..."
echo "Current pod status:"
kubectl get pods -n rocketchat
echo ""

# Step 2: Delete the stuck MongoDB StatefulSet to force recreation with new image
print_status "Step 2: Deleting stuck MongoDB StatefulSet..."
print_warning "This will temporarily delete MongoDB pods (data is preserved in PVCs)"

# Scale down Rocket.Chat deployments first to prevent connection attempts
print_status "Scaling down Rocket.Chat services..."
kubectl scale deployment --all --replicas=0 -n rocketchat 2>/dev/null || true
kubectl scale statefulset --all --replicas=0 -n rocketchat 2>/dev/null || true
sleep 5

# Delete the MongoDB StatefulSet
print_status "Deleting MongoDB StatefulSet..."
kubectl delete statefulset rocketchat-mongodb -n rocketchat --force --grace-period=0 2>/dev/null || true
sleep 5

# Step 3: Upgrade Helm release with corrected values
print_status "Step 3: Upgrading Rocket.Chat Helm release with fixed MongoDB image..."
print_status "Using Docker Hub registry (docker.io) instead of ghcr.io..."

# Update Helm repos first
helm repo update

# Upgrade the release with the corrected values
helm upgrade rocketchat rocketchat/rocketchat \
  -f ../config/helm-values/values-official.yaml \
  --namespace rocketchat \
  --timeout=15m \
  --wait

print_success "Helm release upgraded successfully"

# Step 4: Monitor deployment
print_status "Step 4: Monitoring deployment..."
echo ""
print_status "Waiting for MongoDB pods to be ready..."

# Wait for MongoDB pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=mongodb \
  -n rocketchat \
  --timeout=600s || {
    print_warning "MongoDB pods are taking longer than expected. Checking status..."
    kubectl describe pod -l app.kubernetes.io/name=mongodb -n rocketchat | head -50
}

# Check MongoDB pod status
print_status "MongoDB pod status:"
kubectl get pods -n rocketchat -l app.kubernetes.io/name=mongodb
echo ""

# Step 5: Check all pods
print_status "Step 5: Checking all Rocket.Chat pods..."
sleep 10
kubectl get pods -n rocketchat
echo ""

# Step 6: Verify MongoDB connection
print_status "Step 6: Verifying MongoDB connection..."
MONGODB_POD=$(kubectl get pod -n rocketchat -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$MONGODB_POD" ]; then
    print_status "MongoDB pod found: $MONGODB_POD"
    print_status "Checking MongoDB replica set status..."
    
    # Check if MongoDB is accessible
    kubectl exec -n rocketchat $MONGODB_POD -c mongodb -- mongosh --eval "rs.status().ok" --quiet 2>/dev/null && {
        print_success "MongoDB replica set is healthy"
    } || {
        print_warning "MongoDB replica set check failed, but this may be normal during initialization"
    }
else
    print_warning "MongoDB pod not found yet, it may still be initializing"
fi

# Step 7: Check Rocket.Chat logs
print_status "Step 7: Checking Rocket.Chat application logs..."
echo ""
ROCKETCHAT_POD=$(kubectl get pod -n rocketchat -l app.kubernetes.io/name=rocketchat,app.kubernetes.io/component=rocketchat -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$ROCKETCHAT_POD" ]; then
    print_status "Rocket.Chat pod: $ROCKETCHAT_POD"
    echo "Recent logs:"
    kubectl logs -n rocketchat $ROCKETCHAT_POD --tail=20 2>/dev/null || echo "Logs not available yet"
else
    print_warning "Rocket.Chat main pod not ready yet"
fi

# Step 8: Final status
echo ""
print_status "Step 8: Final deployment status..."
echo ""
echo "=== DEPLOYMENT STATUS ==="
kubectl get pods -n rocketchat | grep -E "NAME|mongodb|rocketchat"
echo ""

# Check if deployment is successful
MONGODB_READY=$(kubectl get pods -n rocketchat -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o "true" | wc -l)
ROCKETCHAT_READY=$(kubectl get pods -n rocketchat -l app.kubernetes.io/name=rocketchat -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o "true" | wc -l)

if [ "$MONGODB_READY" -ge 1 ] && [ "$ROCKETCHAT_READY" -ge 1 ]; then
    print_success "✅ MongoDB image issue fixed! Deployment is recovering."
    echo ""
    echo "📊 Next steps:"
    echo "1. Wait 2-3 minutes for all services to stabilize"
    echo "2. Check the application at: https://chat.canepro.me"
    echo "3. Monitor pods with: kubectl get pods -n rocketchat -w"
else
    print_warning "⏳ Deployment is still initializing. This is normal."
    echo ""
    echo "📊 What to do:"
    echo "1. Wait 3-5 minutes for pods to initialize"
    echo "2. Monitor progress with: kubectl get pods -n rocketchat -w"
    echo "3. Check events with: kubectl get events -n rocketchat --sort-by='.lastTimestamp'"
    echo "4. If issues persist, check pod logs:"
    echo "   kubectl logs -n rocketchat -l app.kubernetes.io/name=mongodb"
    echo "   kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat"
fi

echo ""
print_status "Script completed. Monitor the deployment for the next few minutes."
