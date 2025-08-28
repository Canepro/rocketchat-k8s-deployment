#!/bin/bash

# Rocket.Chat Kubernetes Deployment Script with Monitoring
# Based on official Rocket.Chat documentation

set -e

echo "🚀 Starting Rocket.Chat deployment with monitoring on Kubernetes..."

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

# Configure kubectl to use MicroK8s kubeconfig
mkdir -p ~/.kube
microk8s config > ~/.kube/config

# Check if MicroK8s is installed and running
if ! command -v microk8s &> /dev/null; then
    print_error "MicroK8s is not installed. Please run setup-ubuntu-server.sh first."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please run setup-ubuntu-server.sh first."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please run setup-ubuntu-server.sh first."
    exit 1
fi

# Check if MicroK8s is running
print_status "Checking MicroK8s status..."
if ! microk8s status &> /dev/null; then
    print_error "MicroK8s is not running. Please start it with: sudo microk8s start"
    exit 1
fi

# Check if we can connect to the cluster
print_status "Checking Kubernetes cluster connection..."
if ! kubectl get nodes &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check MicroK8s status."
    exit 1
fi

print_success "Connected to MicroK8s cluster"

# Step 1: Enable MicroK8s Ingress
print_status "Enabling MicroK8s Ingress (class 'public')..."
microk8s enable ingress

# Wait for ingress to be ready
print_status "Waiting for Ingress to be ready..."
sleep 30

print_success "MicroK8s Ingress enabled successfully"

# Step 2: Enable MicroK8s cert-manager
print_status "Enabling MicroK8s cert-manager..."
microk8s enable cert-manager

# Wait for cert-manager to be ready
print_status "Waiting for cert-manager to be ready..."
sleep 60

print_success "MicroK8s cert-manager enabled successfully"

# Step 3: Apply ClusterIssuer
print_status "Applying ClusterIssuer configuration..."
kubectl apply -f clusterissuer.yaml

# Wait for ClusterIssuer to be ready
print_status "Waiting for ClusterIssuer to be ready..."
sleep 30

print_success "ClusterIssuer configured successfully"

# Step 4: Add Rocket.Chat Helm repository
print_status "Adding Rocket.Chat Helm repository..."
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo update

print_success "Rocket.Chat Helm repository added"

# Step 5: Add Prometheus-Community Helm repository for monitoring
print_status "Adding Prometheus-Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_success "Prometheus-Community Helm repository added"

# Step 6: Install Prometheus Stack (Prometheus + Grafana)
print_status "Installing Prometheus Stack for monitoring..."
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring-values.yaml

print_success "Prometheus Stack installed successfully"

# Step 7: Deploy Rocket.Chat
print_status "Deploying Rocket.Chat..."
helm install rocketchat -f values-production.yaml rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --wait \
  --timeout=10m

print_success "Rocket.Chat deployed successfully"

# Step 8: Wait for all pods to be ready
print_status "Waiting for all pods to be ready..."
kubectl wait --namespace rocketchat \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=rocketchat \
  --timeout=600s

# Apply ServiceMonitor for Rocket.Chat metrics
print_status "Applying ServiceMonitor for Rocket.Chat metrics..."
kubectl apply -f servicemonitor-rocketchat.yaml

print_success "All Rocket.Chat pods are ready"

# Step 9: Display deployment information
echo ""
print_success "🎉 Rocket.Chat deployment completed successfully!"
echo ""
echo "📋 Deployment Information:"
echo "=========================="
echo "Rocket.Chat URL: https://$(kubectl get ingress -n rocketchat -o jsonpath='{.items[0].spec.rules[0].host}')"
echo "Grafana: use port-forward -> kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "Grafana Username: admin"
echo "Grafana Password: (see monitoring-values.yaml)"
echo ""
echo "🔍 Useful Commands:"
echo "==================="
echo "Check Rocket.Chat pods: kubectl get pods -n rocketchat"
echo "Check Rocket.Chat logs: kubectl logs -f deployment/rocketchat -n rocketchat"
echo "Check monitoring pods: kubectl get pods -n monitoring"
echo "Access Grafana: kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo ""
echo "⚠️  Important Notes:"
echo "==================="
echo "1. Ingress class is 'public' for MicroK8s; values and ClusterIssuer aligned"
echo "2. Change the default passwords for production use"
echo "3. For higher load, scale VM and set replicaCount > 1"
echo ""
print_success "Deployment script completed!"
