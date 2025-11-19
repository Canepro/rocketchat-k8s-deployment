#!/bin/bash
# Setup script for forwarding metrics, logs, and traces to OKE central hub (Secure)
# 
# Usage:
#   ./setup-oke-forwarding.sh [CLUSTER_NAME]
#
# Example:
#   ./setup-oke-forwarding.sh rocket-chat-aks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Secure Endpoints
OKE_PROMETHEUS_URL="https://observability.canepro.me/prometheus/api/v1/write"
OKE_LOKI_URL="https://observability.canepro.me/loki/loki/api/v1/push"
OKE_TEMPO_ENDPOINT="observability.canepro.me:443"

CLUSTER_NAME=${1:-rocket-chat-aks}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Configuring forwarding to OKE central hub (Secure Ingress)..."
print_status "Prometheus URL: $OKE_PROMETHEUS_URL"
print_status "Loki URL: $OKE_LOKI_URL"
print_status "Tempo Endpoint: $OKE_TEMPO_ENDPOINT"
print_status "Cluster Name: $CLUSTER_NAME"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Step 0: Create Authentication Secret
print_status "Step 0: Creating authentication secret..."
kubectl apply -f "$PROJECT_ROOT/monitoring/oke-auth-secret.yaml"

# Step 1: Configure Prometheus Remote Write
print_status "Step 1: Configuring Prometheus remote write..."

# Update the Helm values file
PROMETHEUS_VALUES="$PROJECT_ROOT/config/helm-values/prometheus-oke-remote-write.yaml"
if [ -f "$PROMETHEUS_VALUES" ]; then
    # Ensure correct values are in place (already updated in repo)
    sed -i.bak "s|rocket-chat-aks|$CLUSTER_NAME|g" "$PROMETHEUS_VALUES"
    
    # Apply via Helm
    if helm list -n monitoring | grep -q monitoring; then
        print_status "Upgrading Prometheus with remote write configuration..."
        helm upgrade monitoring prometheus-community/kube-prometheus-stack \
            -f "$PROJECT_ROOT/config/helm-values/values-monitoring.yaml" \
            -f "$PROMETHEUS_VALUES" \
            -n monitoring \
            --wait \
            --timeout=10m
        print_status "Prometheus remote write configured"
    else
        print_status "Installing Prometheus monitoring stack..."
        helm install monitoring prometheus-community/kube-prometheus-stack \
            -f "$PROJECT_ROOT/config/helm-values/values-monitoring.yaml" \
            -f "$PROMETHEUS_VALUES" \
            -n monitoring \
            --wait \
            --timeout=10m
    fi
else
    print_error "Prometheus remote write values file not found: $PROMETHEUS_VALUES"
    exit 1
fi

# Step 2: Configure Promtail
print_status "Step 2: Configuring Promtail for dual forwarding..."

# Update Promtail configuration
PROMTAIL_CONFIG="$PROJECT_ROOT/monitoring/promtail-oke-forward.yaml"
if [ -f "$PROMTAIL_CONFIG" ]; then
    sed -i.bak "s|rocket-chat-aks|$CLUSTER_NAME|g" "$PROMTAIL_CONFIG"
    
    # Upgrade Loki/Promtail
    print_status "Upgrading Loki stack..."
    helm upgrade loki grafana/loki-stack \
        -f "$PROJECT_ROOT/monitoring/loki-values.yaml" \
        -f "$PROMTAIL_CONFIG" \
        -n monitoring
else
    print_error "Promtail configuration file not found: $PROMTAIL_CONFIG"
    exit 1
fi

# Step 3: Configure OTEL Collector
print_status "Step 3: Configuring OTEL Collector for dual forwarding..."

OTEL_CONFIG="$PROJECT_ROOT/monitoring/otel-collector-oke-forward.yaml"
if [ -f "$OTEL_CONFIG" ]; then
    sed -i.bak "s|rocket-chat-aks|$CLUSTER_NAME|g" "$OTEL_CONFIG"
    
    # Apply the configuration
    print_status "Applying OTEL Collector configuration..."
    kubectl apply -f "$OTEL_CONFIG"
    
    # Restart OTEL Collector
    if kubectl get deployment otel-collector -n monitoring >/dev/null 2>&1; then
        print_status "Restarting OTEL Collector..."
        kubectl rollout restart deployment/otel-collector -n monitoring
        kubectl rollout status deployment/otel-collector -n monitoring --timeout=5m
        print_status "OTEL Collector configured and restarted"
    else
        print_warning "OTEL Collector deployment not found. Creating it..."
        kubectl apply -f "$PROJECT_ROOT/monitoring/opentelemetry-collector.yaml"
        # Apply config again to be sure
        kubectl apply -f "$OTEL_CONFIG"
        kubectl rollout restart deployment/otel-collector -n monitoring
    fi
else
    print_error "OTEL Collector configuration file not found: $OTEL_CONFIG"
    exit 1
fi

print_status "Configuration complete!"
