#!/bin/bash
# Script to expose OKE services for external access
# Run this on your OKE cluster
#
# Usage:
#   ./expose-oke-services.sh [loadbalancer|nodeport|ingress]
#
# Example:
#   ./expose-oke-services.sh loadbalancer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

METHOD=${1:-loadbalancer}

if [[ ! "$METHOD" =~ ^(loadbalancer|nodeport|ingress)$ ]]; then
    print_error "Invalid method: $METHOD"
    echo "Usage: $0 [loadbalancer|nodeport|ingress]"
    exit 1
fi

print_status "Exposing OKE services using method: $METHOD"

# Function to wait for LoadBalancer IP
wait_for_loadbalancer() {
    local service=$1
    local namespace=$2
    print_status "Waiting for LoadBalancer IP for $service..."
    
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc $service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ]; then
            print_status "$service external IP: $EXTERNAL_IP"
            return 0
        fi
        sleep 2
    done
    
    print_warning "LoadBalancer IP not assigned yet. Check with: kubectl get svc $service -n $namespace"
    return 1
}

if [ "$METHOD" == "loadbalancer" ]; then
    print_status "Exposing services via LoadBalancer..."
    
    # Expose Prometheus
    print_status "Exposing Prometheus..."
    kubectl patch svc prometheus-prometheus -n monitoring \
        -p '{"spec": {"type": "LoadBalancer"}}' || true
    
    wait_for_loadbalancer prometheus-prometheus monitoring
    
    # Expose Loki Gateway
    print_status "Exposing Loki Gateway..."
    kubectl patch svc loki-gateway -n monitoring \
        -p '{"spec": {"type": "LoadBalancer"}}' || true
    
    wait_for_loadbalancer loki-gateway monitoring
    
    # Expose Tempo
    print_status "Exposing Tempo..."
    kubectl patch svc tempo -n monitoring \
        -p '{"spec": {"type": "LoadBalancer"}}' || true
    
    wait_for_loadbalancer tempo monitoring
    
    # Display all external IPs
    print_status ""
    print_status "=========================================="
    print_status "Service External IPs:"
    print_status "=========================================="
    echo ""
    echo "Prometheus:"
    kubectl get svc prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo "Pending..."
    echo ""
    echo "Loki Gateway:"
    kubectl get svc loki-gateway -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo "Pending..."
    echo ""
    echo "Tempo:"
    kubectl get svc tempo -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo "Pending..."
    echo ""
    
elif [ "$METHOD" == "nodeport" ]; then
    print_status "Exposing services via NodePort..."
    
    # Expose Prometheus
    kubectl patch svc prometheus-prometheus -n monitoring \
        -p '{"spec": {"type": "NodePort"}}' || true
    
    # Expose Loki Gateway
    kubectl patch svc loki-gateway -n monitoring \
        -p '{"spec": {"type": "NodePort"}}' || true
    
    # Expose Tempo
    kubectl patch svc tempo -n monitoring \
        -p '{"spec": {"type": "NodePort"}}' || true
    
    # Get NodePorts and node IPs
    print_status ""
    print_status "=========================================="
    print_status "Service NodePorts:"
    print_status "=========================================="
    echo ""
    echo "Prometheus:"
    NODE_PORT=$(kubectl get svc prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    echo "  Node IP: $NODE_IP"
    echo "  NodePort: $NODE_PORT"
    echo "  Access: http://$NODE_IP:$NODE_PORT"
    echo ""
    
    echo "Loki Gateway:"
    NODE_PORT=$(kubectl get svc loki-gateway -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    echo "  Node IP: $NODE_IP"
    echo "  NodePort: $NODE_PORT"
    echo "  Access: http://$NODE_IP:$NODE_PORT"
    echo ""
    
    echo "Tempo:"
    NODE_PORT=$(kubectl get svc tempo -n monitoring -o jsonpath='{.spec.ports[?(@.name=="otlp-grpc")].nodePort}')
    echo "  Node IP: $NODE_IP"
    echo "  NodePort: $NODE_PORT"
    echo "  Access: $NODE_IP:$NODE_PORT"
    echo ""
    
elif [ "$METHOD" == "ingress" ]; then
    print_warning "Ingress method requires manual configuration"
    print_status "See aks/docs/OKE_EXPOSE_SERVICES.md for Ingress setup instructions"
    exit 0
fi

print_status ""
print_status "=========================================="
print_status "Next Steps:"
print_status "=========================================="
print_status ""
print_status "1. Note the external IPs/NodePorts above"
print_status "2. Update configuration files with these IPs:"
print_status "   - aks/config/helm-values/prometheus-oke-remote-write.yaml"
print_status "   - aks/monitoring/promtail-oke-forward.yaml"
print_status "   - aks/monitoring/otel-collector-oke-forward.yaml"
print_status ""
print_status "3. Run setup script from AKS cluster:"
print_status "   ./aks/scripts/setup-oke-forwarding.sh <PROMETHEUS_IP> <LOKI_IP> <TEMPO_IP>"
print_status ""

