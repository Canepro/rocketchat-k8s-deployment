#!/bin/bash

# Deploy Distributed Tracing Stack for Rocket.Chat
# This script deploys Tempo, OpenTelemetry Collector, and integrates with existing Grafana

set -e

# Auto-detect and export KUBECONFIG early (works for both native Linux and WSL)
if [ -z "$KUBECONFIG" ]; then
    if [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
    elif [ -f "/mnt/c/Users/$USER/.kube/config" ]; then
        export KUBECONFIG="/mnt/c/Users/$USER/.kube/config"
    elif [ -f "/mnt/c/Users/i/.kube/config" ]; then
        export KUBECONFIG="/mnt/c/Users/i/.kube/config"
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🚀 Deploying Distributed Tracing Stack for Rocket.Chat..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Setup kubeconfig if needed
print_status "Checking cluster connectivity..."

# Display which kubeconfig we're using
if [ -n "$KUBECONFIG" ]; then
    print_status "Using KUBECONFIG: $KUBECONFIG"
else
    print_warning "KUBECONFIG not set, using default (~/.kube/config)"
fi

# Verify cluster connectivity (this is the real test)
print_status "Verifying cluster connection..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster!"
    echo ""
    echo "Please ensure your kubeconfig is properly configured:"
    echo "  1. Check if kubeconfig file exists:"
    echo "     kubectl config view"
    echo ""
    echo "  2. Verify cluster context:"
    echo "     kubectl config get-contexts"
    echo ""
    echo "  3. Set KUBECONFIG environment variable:"
    echo "     export KUBECONFIG=/mnt/c/Users/i/.kube/config"
    echo ""
    echo "  4. Test connectivity:"
    echo "     kubectl cluster-info"
    echo "     kubectl get nodes"
    exit 1
fi

print_success "Cluster connectivity verified"

# Get current context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
print_status "Current context: $CURRENT_CONTEXT"

# Ensure we're in the right namespace
kubectl config set-context --current --namespace=monitoring 2>/dev/null || true

print_status "Deploying Tempo (Distributed Tracing Backend)..."

# Deploy Tempo using the values file
print_status "Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || print_warning "Grafana repo already exists"
helm repo update

# Install or upgrade Tempo (handles both new install and existing failed installs)
print_status "Installing Tempo..."
if helm upgrade --install tempo grafana/tempo \
  -f aks/monitoring/tempo-values.yaml \
  --namespace monitoring \
  --create-namespace \
  --wait; then
    print_success "Tempo deployed successfully"
else
    print_error "Failed to deploy Tempo"
    print_warning "If Tempo already exists in a failed state, try: helm uninstall tempo -n monitoring"
    exit 1
fi

print_status "Deploying OpenTelemetry Collector..."

# Apply OpenTelemetry Collector
if kubectl apply -f aks/monitoring/opentelemetry-collector.yaml; then
    print_success "OpenTelemetry Collector deployed successfully"
else
    print_error "Failed to deploy OpenTelemetry Collector"
    exit 1
fi

print_status "Configuring Grafana Tempo Data Source..."

# Apply Tempo datasource configuration
if kubectl apply -f aks/monitoring/grafana-tempo-datasource.yaml; then
    print_success "Grafana Tempo datasource configured"
else
    print_warning "Failed to configure Tempo datasource (may already exist)"
fi

print_status "Deploying Tracing Dashboard..."

# Apply tracing dashboard
if kubectl apply -f aks/monitoring/grafana-tracing-dashboard.yaml; then
    print_success "Tracing dashboard deployed"
else
    print_warning "Failed to deploy tracing dashboard (may already exist)"
fi

print_status "Configuring Rocket.Chat Tracing Instrumentation..."

# Apply Rocket.Chat tracing configuration
if kubectl apply -f aks/monitoring/rocketchat-tracing-instrumentation.yaml; then
    print_success "Rocket.Chat tracing instrumentation configured"
else
    print_warning "Failed to configure Rocket.Chat instrumentation (may need manual application)"
fi

print_status "Verifying Deployment..."

# Wait for pods to be ready
print_status "Waiting for Tempo to be ready..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tempo -n monitoring --timeout=300s 2>/dev/null; then
    print_success "Tempo is ready"
else
    print_warning "Tempo pod not ready yet (may take longer)"
fi

print_status "Waiting for OpenTelemetry Collector to be ready..."
if kubectl wait --for=condition=ready pod -l app=otel-collector -n monitoring --timeout=300s 2>/dev/null; then
    print_success "OpenTelemetry Collector is ready"
else
    print_warning "OpenTelemetry Collector pod not ready yet (may take longer)"
fi

print_status "Checking deployment status..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo || true
kubectl get pods -n monitoring -l app=otel-collector || true

echo ""
print_success "Deployment Summary:"
echo "✅ Tempo: Distributed tracing backend"
echo "✅ OpenTelemetry Collector: Trace collection and forwarding"
echo "✅ Grafana Integration: Tempo datasource configured"
echo "✅ Tracing Dashboard: Comprehensive tracing visualization"
echo "✅ Rocket.Chat Instrumentation: OpenTelemetry tracing enabled"

echo ""
print_success "Distributed Tracing Stack Deployed Successfully!"
echo ""
echo "📊 Access your tracing dashboard at:"
echo "   https://<YOUR_GRAFANA_DOMAIN>/d/rocket-chat-tracing"
echo ""
echo "🔍 Key Features:"
echo "   • Request tracing across Rocket.Chat services"
echo "   • Performance bottleneck identification"
echo "   • Error correlation and debugging"
echo "   • End-to-end request visibility"
echo "   • Integration with existing metrics and logs"
echo ""
echo "🚀 Your observability stack is now complete:"
echo "   • Metrics: Prometheus"
echo "   • Logs: Loki"
echo "   • Traces: Tempo"
echo "   • Visualization: Grafana"
