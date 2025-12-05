#!/bin/bash
# Deploy Standalone MongoDB to bypass Bitnami Brownout
# This script deploys MongoDB using the official image and connects Rocket.Chat to it

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

print_status "🔧 Deploying Standalone MongoDB to bypass Bitnami Brownout"
echo ""
print_warning "Bitnami MongoDB images are unavailable Sept 17-19, 2025 due to brownout"
print_status "Using official MongoDB image (mongo:6.0) instead"
echo ""

# Step 1: Clean up existing MongoDB deployment
print_status "Step 1: Cleaning up existing MongoDB deployment..."

# Delete the broken MongoDB StatefulSet from Bitnami subchart
kubectl delete statefulset rocketchat-mongodb -n rocketchat --force --grace-period=0 2>/dev/null || true

# Delete MongoDB services if they exist
kubectl delete service rocketchat-mongodb -n rocketchat 2>/dev/null || true
kubectl delete service rocketchat-mongodb-headless -n rocketchat 2>/dev/null || true

# Delete any MongoDB jobs
kubectl delete job -n rocketchat -l app.kubernetes.io/name=mongodb 2>/dev/null || true

print_success "Cleanup complete"
echo ""

# Step 2: Deploy standalone MongoDB
print_status "Step 2: Deploying standalone MongoDB with official image..."
kubectl apply -f ../config/mongodb-standalone.yaml

# Wait for MongoDB StatefulSet to be created
sleep 5

# Wait for MongoDB pods to be ready
print_status "Waiting for MongoDB pods to start..."
for i in 0 1 2; do
    print_status "Waiting for mongodb-$i..."
    kubectl wait --for=condition=ready pod/mongodb-$i -n rocketchat --timeout=300s || {
        print_warning "mongodb-$i is taking longer than expected"
        kubectl describe pod mongodb-$i -n rocketchat | tail -20
    }
done

print_success "MongoDB pods are running"
echo ""

# Step 3: Wait for MongoDB initialization job
print_status "Step 3: Waiting for MongoDB replica set initialization..."

# Wait for the init job to complete
kubectl wait --for=condition=complete job/mongodb-init -n rocketchat --timeout=120s || {
    print_warning "MongoDB initialization is taking longer than expected"
    kubectl logs job/mongodb-init -n rocketchat
}

print_success "MongoDB replica set initialized"
echo ""

# Step 4: Update Rocket.Chat deployment
print_status "Step 4: Updating Rocket.Chat to use external MongoDB..."

# Upgrade Rocket.Chat with the new configuration
helm upgrade rocketchat rocketchat/rocketchat \
  -f ../config/helm-values/values-official.yaml \
  --namespace rocketchat \
  --timeout=5m

print_success "Rocket.Chat configuration updated"
echo ""

# Step 5: Restart Rocket.Chat pods to pick up new configuration
print_status "Step 5: Restarting Rocket.Chat pods..."

# Delete all Rocket.Chat pods to force restart with new config
kubectl delete pods -n rocketchat -l app.kubernetes.io/name=rocketchat --force --grace-period=0 2>/dev/null || true

# Wait a moment for pods to restart
sleep 10

# Step 6: Monitor deployment
print_status "Step 6: Monitoring deployment status..."
echo ""

# Function to check pod status
check_pods() {
    local ready_count=0
    local total_count=0
    
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^NAME ]]; then
            total_count=$((total_count + 1))
            if [[ "$line" =~ ([0-9]+)/([0-9]+) ]]; then
                local ready="${BASH_REMATCH[1]}"
                local total="${BASH_REMATCH[2]}"
                if [ "$ready" == "$total" ] && [ "$ready" != "0" ]; then
                    ready_count=$((ready_count + 1))
                fi
            fi
        fi
    done < <(kubectl get pods -n rocketchat 2>/dev/null)
    
    echo "$ready_count/$total_count"
}

# Monitor for up to 5 minutes
end_time=$(($(date +%s) + 300))
while [ $(date +%s) -lt $end_time ]; do
    status=$(check_pods)
    print_status "Pods ready: $status"
    
    # Check if all required services are running
    mongodb_ready=$(kubectl get pods -n rocketchat -l app=mongodb -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o "true" | wc -l)
    rocketchat_ready=$(kubectl get pods -n rocketchat -l app.kubernetes.io/name=rocketchat -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o "true" | wc -l)
    
    if [ "$mongodb_ready" -ge 3 ] && [ "$rocketchat_ready" -ge 1 ]; then
        print_success "✅ Deployment successful!"
        break
    fi
    
    sleep 10
done

echo ""
print_status "Current pod status:"
kubectl get pods -n rocketchat
echo ""

# Test MongoDB connectivity
print_status "Testing MongoDB connectivity..."
MONGODB_POD="mongodb-0"
kubectl exec -n rocketchat $MONGODB_POD -- mongosh --eval "db.adminCommand('ping')" --quiet && {
    print_success "MongoDB is responding to ping"
} || {
    print_warning "MongoDB ping failed, but this may be normal during initialization"
}

# Check Rocket.Chat logs
print_status "Recent Rocket.Chat logs:"
ROCKETCHAT_POD=$(kubectl get pod -n rocketchat -l app.kubernetes.io/name=rocketchat,app.kubernetes.io/component=rocketchat -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$ROCKETCHAT_POD" ]; then
    kubectl logs -n rocketchat $ROCKETCHAT_POD --tail=10 2>/dev/null || echo "Logs not available yet"
fi

echo ""
print_success "🚀 Deployment complete!"
echo ""
echo "📝 Summary:"
echo "  - MongoDB deployed using official mongo:6.0 image"
echo "  - Rocket.Chat configured to use external MongoDB"
echo "  - Bypassed Bitnami brownout issue (Sept 17-19, 2025)"
echo ""
echo "🔍 Next steps:"
echo "  1. Monitor pods: kubectl get pods -n rocketchat -w"
echo "  2. Check MongoDB: kubectl logs mongodb-0 -n rocketchat"
echo "  3. Check Rocket.Chat: kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat"
echo "  4. Access Rocket.Chat at: https://<YOUR_DOMAIN> (after DNS update)"
echo ""
print_warning "Note: After Sept 19, 2025, you can switch back to Bitnami MongoDB if desired"
