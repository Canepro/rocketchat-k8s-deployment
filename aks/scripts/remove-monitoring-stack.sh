#!/bin/bash
# Script to remove monitoring stack from AKS cluster
# This will disconnect grafana.canepro.me and remove all monitoring pods to reduce costs

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

print_status "🗑️  Starting Monitoring Stack Removal from AKS Cluster"
echo ""

# Step 1: Verify we're on the correct cluster
print_status "Step 1: Verifying Kubernetes context..."
CURRENT_CONTEXT=$(kubectl config current-context)
print_status "Current context: $CURRENT_CONTEXT"

if [[ ! "$CURRENT_CONTEXT" =~ "aks" ]]; then
    print_warning "Current context doesn't appear to be AKS cluster"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted. Please switch to AKS context first:"
        echo "  kubectl config use-context aks-uksouth"
        exit 1
    fi
fi

# Step 2: List current monitoring resources
print_status "Step 2: Listing current monitoring resources..."
echo ""
print_status "Helm releases in monitoring namespace:"
helm list -n monitoring || print_warning "No Helm releases found or namespace doesn't exist"
echo ""

print_status "Pods in monitoring namespace:"
kubectl get pods -n monitoring 2>/dev/null || print_warning "Monitoring namespace doesn't exist or no pods found"
echo ""

# Step 3: Remove Grafana Ingress (disconnect grafana.canepro.me)
print_status "Step 3: Removing Grafana Ingress (grafana.canepro.me)..."
if kubectl get ingress grafana-new-domain -n monitoring >/dev/null 2>&1; then
    kubectl delete ingress grafana-new-domain -n monitoring
    print_success "Grafana ingress removed"
else
    print_warning "Grafana ingress not found (may already be removed)"
fi

# Also check for other Grafana ingress resources
if kubectl get ingress -n monitoring 2>/dev/null | grep -q grafana; then
    print_status "Removing other Grafana ingress resources..."
    kubectl delete ingress -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || true
fi
echo ""

# Step 4: Uninstall Helm releases
print_status "Step 4: Uninstalling Helm releases..."

# Uninstall Tempo if exists
if helm list -n monitoring | grep -q tempo; then
    print_status "Uninstalling Tempo..."
    helm uninstall tempo -n monitoring || print_warning "Failed to uninstall Tempo (may not exist)"
    print_success "Tempo uninstalled"
else
    print_warning "Tempo Helm release not found"
fi

# Uninstall Loki stack if exists
if helm list -n monitoring | grep -q loki-stack; then
    print_status "Uninstalling Loki stack..."
    helm uninstall loki-stack -n monitoring || print_warning "Failed to uninstall Loki stack (may not exist)"
    print_success "Loki stack uninstalled"
else
    print_warning "Loki stack Helm release not found"
fi

# Check for Loki in other namespaces
if helm list -A | grep -q loki; then
    print_status "Found Loki in other namespaces, checking..."
    helm list -A | grep loki
    read -p "Uninstall Loki from other namespaces? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm list -A | grep loki | awk '{print $2 " -n " $1}' | xargs -I {} sh -c 'helm uninstall {} || true'
    fi
fi

# Uninstall main monitoring stack (kube-prometheus-stack)
if helm list -n monitoring | grep -q monitoring; then
    print_status "Uninstalling kube-prometheus-stack (monitoring)..."
    helm uninstall monitoring -n monitoring || print_warning "Failed to uninstall monitoring stack"
    print_success "Monitoring stack uninstalled"
else
    print_warning "Monitoring Helm release not found"
fi
echo ""

# Step 5: Remove OpenTelemetry Collector
print_status "Step 5: Removing OpenTelemetry Collector..."
if kubectl get deployment otel-collector -n monitoring >/dev/null 2>&1; then
    kubectl delete deployment otel-collector -n monitoring
    print_success "OpenTelemetry Collector removed"
else
    print_warning "OpenTelemetry Collector not found"
fi

# Also check for OpenTelemetry in other namespaces
if kubectl get deployment -A | grep -q otel-collector; then
    print_status "Found OpenTelemetry Collector in other namespaces, removing..."
    kubectl delete deployment -A -l app=otel-collector 2>/dev/null || true
fi
echo ""

# Step 6: Remove additional monitoring resources
print_status "Step 6: Removing additional monitoring resources..."

# Remove ServiceMonitors
print_status "Removing ServiceMonitors..."
kubectl delete servicemonitor -n monitoring --all 2>/dev/null || print_warning "No ServiceMonitors found"
kubectl delete servicemonitor -n rocketchat --all 2>/dev/null || print_warning "No ServiceMonitors in rocketchat namespace"

# Remove PrometheusRules
print_status "Removing PrometheusRules..."
kubectl delete prometheusrule -n monitoring --all 2>/dev/null || print_warning "No PrometheusRules found"

# Remove ConfigMaps related to monitoring
print_status "Removing monitoring ConfigMaps..."
kubectl delete configmap -n monitoring -l app.kubernetes.io/part-of=kube-prometheus-stack 2>/dev/null || true
kubectl delete configmap -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || true

# Remove Secrets related to monitoring (be careful - keep grafana-admin if needed elsewhere)
print_status "Removing monitoring Secrets (keeping grafana-admin)..."
kubectl delete secret -n monitoring -l app.kubernetes.io/part-of=kube-prometheus-stack 2>/dev/null || true

# Remove Services
print_status "Removing monitoring Services..."
kubectl delete svc -n monitoring -l app.kubernetes.io/part-of=kube-prometheus-stack 2>/dev/null || true
kubectl delete svc -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || true
kubectl delete svc -n monitoring -l app.kubernetes.io/name=loki 2>/dev/null || true
kubectl delete svc -n monitoring -l app.kubernetes.io/name=tempo 2>/dev/null || true
echo ""

# Step 7: Remove PersistentVolumeClaims (optional - will delete data)
print_status "Step 7: Checking PersistentVolumeClaims..."
PVC_COUNT=$(kubectl get pvc -n monitoring 2>/dev/null | wc -l || echo "0")
if [ "$PVC_COUNT" -gt 1 ]; then  # More than header line
    print_warning "Found PersistentVolumeClaims in monitoring namespace:"
    kubectl get pvc -n monitoring
    echo ""
    read -p "Delete PersistentVolumeClaims? This will PERMANENTLY delete monitoring data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete pvc -n monitoring --all
        print_success "PersistentVolumeClaims deleted"
    else
        print_warning "Keeping PersistentVolumeClaims (data preserved)"
    fi
else
    print_warning "No PersistentVolumeClaims found"
fi
echo ""

# Step 8: Remove monitoring namespace (optional)
print_status "Step 8: Checking monitoring namespace..."
if kubectl get namespace monitoring >/dev/null 2>&1; then
    # Check if namespace is empty
    RESOURCE_COUNT=$(kubectl get all -n monitoring 2>/dev/null | wc -l || echo "0")
    if [ "$RESOURCE_COUNT" -le 1 ]; then
        read -p "Monitoring namespace appears empty. Delete it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace monitoring
            print_success "Monitoring namespace deleted"
        else
            print_warning "Keeping monitoring namespace"
        fi
    else
        print_warning "Monitoring namespace still contains resources, keeping it"
        print_status "Remaining resources:"
        kubectl get all -n monitoring
    fi
else
    print_warning "Monitoring namespace doesn't exist"
fi
echo ""

# Step 9: Final verification
print_status "Step 9: Final verification..."
echo ""
print_status "Remaining Helm releases:"
helm list -A | grep -E "monitoring|loki|tempo|grafana" || print_success "No monitoring Helm releases found"
echo ""

print_status "Remaining pods in monitoring namespace:"
if kubectl get namespace monitoring >/dev/null 2>&1; then
    kubectl get pods -n monitoring 2>/dev/null || print_success "No pods in monitoring namespace"
else
    print_success "Monitoring namespace doesn't exist"
fi
echo ""

print_status "Remaining ingress resources:"
kubectl get ingress -A | grep -E "grafana|monitoring" || print_success "No monitoring ingress found"
echo ""

# Summary
print_success "✅ Monitoring Stack Removal Complete!"
echo ""
print_status "Summary:"
echo "  - Grafana ingress (grafana.canepro.me) removed"
echo "  - Helm releases uninstalled"
echo "  - Monitoring pods removed"
echo "  - Monitoring resources cleaned up"
echo ""
print_warning "Note: If you kept PVCs, you can delete them later with:"
echo "  kubectl delete pvc -n monitoring --all"
echo ""
print_status "Next steps:"
echo "  1. Verify monitoring is removed: kubectl get pods -n monitoring"
echo "  2. Switch to OKE cluster for Grafana access"
echo "  3. Update DNS if needed (grafana.canepro.me should point to OKE)"
echo "  4. Monitor cost reduction in Azure portal"
echo ""

