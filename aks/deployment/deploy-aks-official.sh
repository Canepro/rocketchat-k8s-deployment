#!/bin/bash
# Official Rocket.Chat AKS Deployment Script
# Based on: https://docs.rocket.chat/docs/deploy-with-kubernetes

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

print_status "🚀 Starting Official Rocket.Chat AKS Deployment"

# Step 1: Add Rocket.Chat Helm repository
print_status "Step 1: Adding Rocket.Chat Helm repository..."
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo update
print_success "Rocket.Chat Helm repository added"

# Step 2: Install NGINX Ingress Controller (if not already installed)
print_status "Step 2: Checking NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

    # Wait for ingress controller to be ready
    print_status "Waiting for NGINX Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s
    print_success "NGINX Ingress Controller installed"
else
    print_success "NGINX Ingress Controller already installed"
fi

# Step 3: Install cert-manager (if not already installed)
print_status "Step 3: Checking cert-manager..."
if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
    print_status "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml

    # Wait for cert-manager to be ready
    print_status "Waiting for cert-manager..."
    kubectl wait --namespace cert-manager \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/instance=cert-manager \
      --timeout=300s
    print_success "cert-manager installed"
else
    print_success "cert-manager already installed"
fi

# Step 4: Apply ClusterIssuer
print_status "Step 4: Applying ClusterIssuer configuration..."
kubectl apply -f ../config/certificates/clusterissuer.yaml

# Wait for ClusterIssuer to be ready
print_status "Waiting for ClusterIssuer..."
sleep 30
kubectl get clusterissuer
print_success "ClusterIssuer configured"

# Step 5: Install monitoring stack (kube-prometheus-stack)
print_status "Step 5: Installing monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring -f ../config/helm-values/values-monitoring.yaml prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout=10m
print_success "Monitoring stack installed"

# Step 6: Deploy Rocket.Chat
print_status "Step 6: Deploying Rocket.Chat..."
helm install rocketchat -f ../config/helm-values/values-official.yaml rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --wait \
  --timeout=15m
print_success "Rocket.Chat deployed successfully"

# Step 7: Verify deployment
print_status "Step 7: Verifying deployment..."

# Check pods
print_status "Checking pods..."
kubectl get pods -n rocketchat
kubectl get pods -n monitoring

# Check ingress
print_status "Checking ingress..."
kubectl get ingress -n rocketchat
kubectl get ingress -n monitoring

# Get service details
print_status "Getting service information..."
ROCKETCHAT_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
print_success "AKS Ingress IP: $ROCKETCHAT_IP"

# Step 8: Data migration reminder
print_warning "DATA MIGRATION REQUIRED:"
echo "1. Your existing data is backed up in MicroK8s"
echo "2. After deployment, restore data from backup files:"
echo "   - mongodb-backup-20250903_231852.tar.gz"
echo "   - app-config-backup-20250903_232521.tar.gz"
echo "3. Update DNS to point to: $ROCKETCHAT_IP"

# Step 9: Access information
print_success "DEPLOYMENT COMPLETE!"
echo ""
echo "🌐 Access URLs (after DNS update):"
echo "   Rocket.Chat: https://<YOUR_DOMAIN>"
echo "   Grafana: https://grafana.<YOUR_DOMAIN>"
echo "   Grafana credentials from Secret 'grafana-admin' (see deployment README)"
echo ""
echo "📊 Monitoring:"
echo "   Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo ""
echo "🔧 Next Steps:"
echo "1. Update DNS A records to point to: $ROCKETCHAT_IP"
echo "2. Restore data from MicroK8s backup"
echo "3. Test Rocket.Chat functionality"
echo "4. Configure additional monitoring (Azure Monitor, Loki - optional)"
echo ""
echo "🛟 Rollback:"
echo "   Keep MicroK8s VM running for 3-5 days"
echo "   Current MicroK8s IP: 20.68.53.249"
echo ""
echo "💰 Cost Estimate:"
echo "   AKS: ~£65-95/month (within your £100 Azure credit)"
echo "   Storage: Premium SSD included"
echo "   Monitoring: Basic included, enhanced optional"

print_success "Official Rocket.Chat deployment completed successfully!"
