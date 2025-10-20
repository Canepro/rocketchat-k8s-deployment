#!/bin/bash
# Conditional Monitoring Deployment Script
# Deploys monitoring stack conditionally for cost optimization

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

print_status "📊 Starting conditional monitoring deployment"

# Configuration
ENABLE_MONITORING="${ENABLE_MONITORING:-true}"
MONITORING_TYPE="${MONITORING_TYPE:-full}"  # full, lightweight, none
NAMESPACE="${NAMESPACE:-monitoring}"
DRY_RUN="${DRY_RUN:-false}"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl get nodes &> /dev/null; then
        print_error "Cannot connect to cluster. Check kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy full monitoring stack
deploy_full_monitoring() {
    print_status "Deploying full monitoring stack..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would deploy full monitoring stack"
        return 0
    fi
    
    # Create monitoring namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus
    print_status "Deploying Prometheus..."
    kubectl apply -f k8s/overlays/monitoring/prometheus-deployment.yaml
    
    # Deploy Grafana
    print_status "Deploying Grafana..."
    kubectl apply -f k8s/overlays/monitoring/grafana-deployment.yaml
    
    # Deploy Loki
    print_status "Deploying Loki..."
    kubectl apply -f k8s/overlays/monitoring/loki-deployment.yaml
    
    # Deploy Alertmanager
    print_status "Deploying Alertmanager..."
    kubectl apply -f k8s/overlays/monitoring/alertmanager-deployment.yaml
    
    # Deploy ServiceMonitors
    print_status "Deploying ServiceMonitors..."
    kubectl apply -f k8s/overlays/monitoring/servicemonitors.yaml
    
    # Deploy PodMonitors
    print_status "Deploying PodMonitors..."
    kubectl apply -f k8s/overlays/monitoring/podmonitors.yaml
    
    # Wait for components to be ready
    print_status "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=loki -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=alertmanager -n "$NAMESPACE" --timeout=300s
    
    print_success "Full monitoring stack deployed"
}

# Deploy lightweight monitoring
deploy_lightweight_monitoring() {
    print_status "Deploying lightweight monitoring stack..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would deploy lightweight monitoring stack"
        return 0
    fi
    
    # Create monitoring namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy only Prometheus (no Grafana, Loki, Alertmanager)
    print_status "Deploying Prometheus only..."
    kubectl apply -f k8s/overlays/monitoring/prometheus-deployment.yaml
    
    # Deploy ServiceMonitors
    print_status "Deploying ServiceMonitors..."
    kubectl apply -f k8s/overlays/monitoring/servicemonitors.yaml
    
    # Wait for Prometheus to be ready
    print_status "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n "$NAMESPACE" --timeout=300s
    
    print_success "Lightweight monitoring stack deployed"
}

# Remove monitoring stack
remove_monitoring_stack() {
    print_status "Removing monitoring stack..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would remove monitoring stack"
        return 0
    fi
    
    # Delete monitoring resources
    kubectl delete -f k8s/overlays/monitoring/ 2>/dev/null || true
    
    # Delete namespace
    kubectl delete namespace "$NAMESPACE" --grace-period=300 2>/dev/null || true
    
    print_success "Monitoring stack removed"
}

# Check monitoring status
check_monitoring_status() {
    print_status "Checking monitoring status..."
    
    # Check if monitoring namespace exists
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Monitoring namespace exists"
        
        # Check components
        prometheus_pods=$(kubectl get pods -l app=prometheus -n "$NAMESPACE" --no-headers | wc -l)
        grafana_pods=$(kubectl get pods -l app=grafana -n "$NAMESPACE" --no-headers | wc -l)
        loki_pods=$(kubectl get pods -l app=loki -n "$NAMESPACE" --no-headers | wc -l)
        alertmanager_pods=$(kubectl get pods -l app=alertmanager -n "$NAMESPACE" --no-headers | wc -l)
        
        print_status "Monitoring components:"
        print_status "  • Prometheus pods: $prometheus_pods"
        print_status "  • Grafana pods: $grafana_pods"
        print_status "  • Loki pods: $loki_pods"
        print_status "  • Alertmanager pods: $alertmanager_pods"
        
        if [ "$prometheus_pods" -gt 0 ] && [ "$grafana_pods" -gt 0 ] && [ "$loki_pods" -gt 0 ] && [ "$alertmanager_pods" -gt 0 ]; then
            print_success "Full monitoring stack is deployed"
        elif [ "$prometheus_pods" -gt 0 ]; then
            print_success "Lightweight monitoring stack is deployed"
        else
            print_warning "Monitoring stack is not properly deployed"
        fi
    else
        print_warning "Monitoring namespace does not exist"
    fi
}

# Get monitoring costs
get_monitoring_costs() {
    print_status "Getting monitoring costs..."
    
    # Get resource usage
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Monitoring resource usage:"
        kubectl top pods -n "$NAMESPACE" 2>/dev/null || print_warning "Metrics not available"
        
        # Get PVC usage
        pvc_count=$(kubectl get pvc -n "$NAMESPACE" --no-headers | wc -l)
        if [ "$pvc_count" -gt 0 ]; then
            print_status "Monitoring PVCs: $pvc_count"
            kubectl get pvc -n "$NAMESPACE" -o wide
        fi
    else
        print_warning "Monitoring namespace not found"
    fi
}

# Generate monitoring report
generate_monitoring_report() {
    print_status "Generating monitoring report..."
    
    # Get monitoring status
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        prometheus_pods=$(kubectl get pods -l app=prometheus -n "$NAMESPACE" --no-headers | wc -l)
        grafana_pods=$(kubectl get pods -l app=grafana -n "$NAMESPACE" --no-headers | wc -l)
        loki_pods=$(kubectl get pods -l app=loki -n "$NAMESPACE" --no-headers | wc -l)
        alertmanager_pods=$(kubectl get pods -l app=alertmanager -n "$NAMESPACE" --no-headers | wc -l)
        
        monitoring_type="none"
        if [ "$prometheus_pods" -gt 0 ] && [ "$grafana_pods" -gt 0 ] && [ "$loki_pods" -gt 0 ] && [ "$alertmanager_pods" -gt 0 ]; then
            monitoring_type="full"
        elif [ "$prometheus_pods" -gt 0 ]; then
            monitoring_type="lightweight"
        fi
    else
        monitoring_type="none"
    fi
    
    echo "📊 Monitoring Deployment Report"
    echo "==============================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Monitoring Type: $monitoring_type"
    echo "Namespace: $NAMESPACE"
    echo "Dry Run: $DRY_RUN"
    echo ""
    echo "📦 Monitoring Components:"
    echo "   • Prometheus: $(if [ "$prometheus_pods" -gt 0 ]; then echo "DEPLOYED"; else echo "NOT DEPLOYED"; fi)"
    echo "   • Grafana: $(if [ "$grafana_pods" -gt 0 ]; then echo "DEPLOYED"; else echo "NOT DEPLOYED"; fi)"
    echo "   • Loki: $(if [ "$loki_pods" -gt 0 ]; then echo "DEPLOYED"; else echo "NOT DEPLOYED"; fi)"
    echo "   • Alertmanager: $(if [ "$alertmanager_pods" -gt 0 ]; then echo "DEPLOYED"; else echo "NOT DEPLOYED"; fi)"
    echo ""
    echo "💰 Cost Impact:"
    if [ "$monitoring_type" = "full" ]; then
        echo "   • High cost impact (all components)"
        echo "   • Estimated cost: £15-25/month"
    elif [ "$monitoring_type" = "lightweight" ]; then
        echo "   • Medium cost impact (Prometheus only)"
        echo "   • Estimated cost: £5-10/month"
    else
        echo "   • No cost impact (monitoring disabled)"
        echo "   • Estimated cost: £0/month"
    fi
    echo ""
    echo "📋 Recommendations:"
    if [ "$monitoring_type" = "full" ]; then
        echo "   • Full monitoring is active"
        echo "   • Monitor costs and performance"
        echo "   • Consider switching to lightweight for cost savings"
    elif [ "$monitoring_type" = "lightweight" ]; then
        echo "   • Lightweight monitoring is active"
        echo "   • Good balance of monitoring and cost"
        echo "   • Upgrade to full monitoring if needed"
    else
        echo "   • No monitoring is active"
        echo "   • Deploy monitoring for production use"
        echo "   • Start with lightweight monitoring"
    fi
}

# Main execution
main() {
    print_status "Starting conditional monitoring deployment process..."
    
    check_prerequisites
    
    case "$MONITORING_TYPE" in
        "full")
            if [ "$ENABLE_MONITORING" = "true" ]; then
                deploy_full_monitoring
            else
                remove_monitoring_stack
            fi
            ;;
        "lightweight")
            if [ "$ENABLE_MONITORING" = "true" ]; then
                deploy_lightweight_monitoring
            else
                remove_monitoring_stack
            fi
            ;;
        "none")
            remove_monitoring_stack
            ;;
        *)
            print_error "Invalid monitoring type: $MONITORING_TYPE"
            exit 1
            ;;
    esac
    
    check_monitoring_status
    get_monitoring_costs
    generate_monitoring_report
    
    print_success "Conditional monitoring deployment completed successfully!"
    echo ""
    echo "📊 Monitoring Summary:"
    echo "   • Type: $MONITORING_TYPE"
    echo "   • Enabled: $ENABLE_MONITORING"
    echo "   • Namespace: $NAMESPACE"
    echo "   • Status: Completed successfully"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Monitor resource usage and costs"
    echo "   2. Configure monitoring dashboards"
    echo "   3. Set up alerting rules"
    echo "   4. Review cost optimization opportunities"
}

# Run main function
main "$@"
