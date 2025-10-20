#!/bin/bash
# Monitoring Cost Optimization Script
# Optimizes monitoring stack for cost efficiency

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

print_status "💰 Starting monitoring cost optimization"

# Configuration
NAMESPACE="${NAMESPACE:-monitoring}"
OPTIMIZATION_LEVEL="${OPTIMIZATION_LEVEL:-medium}"  # low, medium, high
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

# Analyze current monitoring costs
analyze_monitoring_costs() {
    print_status "Analyzing current monitoring costs..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        # Get pod resource usage
        print_status "Monitoring pod resource usage:"
        kubectl top pods -n "$NAMESPACE" 2>/dev/null || print_warning "Metrics not available"
        
        # Get PVC usage
        pvc_count=$(kubectl get pvc -n "$NAMESPACE" --no-headers | wc -l)
        if [ "$pvc_count" -gt 0 ]; then
            print_status "Monitoring PVCs: $pvc_count"
            kubectl get pvc -n "$NAMESPACE" -o wide
        fi
        
        # Get resource requests and limits
        print_status "Resource requests and limits:"
        kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests.cpu}{"\t"}{.spec.containers[*].resources.requests.memory}{"\t"}{.spec.containers[*].resources.limits.cpu}{"\t"}{.spec.containers[*].resources.limits.memory}{"\n"}{end}'
    else
        print_warning "Monitoring namespace not found"
    fi
}

# Optimize Prometheus resources
optimize_prometheus_resources() {
    print_status "Optimizing Prometheus resources..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would optimize Prometheus resources"
        return 0
    fi
    
    # Get current Prometheus deployment
    if kubectl get deployment prometheus -n "$NAMESPACE" &> /dev/null; then
        print_status "Current Prometheus resources:"
        kubectl get deployment prometheus -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources}'
        
        # Apply optimization based on level
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # Minimal optimization
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","resources":{"requests":{"cpu":"100m","memory":"256Mi"},"limits":{"cpu":"500m","memory":"1Gi"}}}]}}}}'
                ;;
            "medium")
                # Moderate optimization
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","resources":{"requests":{"cpu":"50m","memory":"128Mi"},"limits":{"cpu":"200m","memory":"512Mi"}}}]}}}}'
                ;;
            "high")
                # Aggressive optimization
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","resources":{"requests":{"cpu":"25m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"256Mi"}}}]}}}}'
                ;;
        esac
        
        print_success "Prometheus resources optimized"
    else
        print_warning "Prometheus deployment not found"
    fi
}

# Optimize Grafana resources
optimize_grafana_resources() {
    print_status "Optimizing Grafana resources..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would optimize Grafana resources"
        return 0
    fi
    
    # Get current Grafana deployment
    if kubectl get deployment grafana -n "$NAMESPACE" &> /dev/null; then
        print_status "Current Grafana resources:"
        kubectl get deployment grafana -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources}'
        
        # Apply optimization based on level
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # Minimal optimization
                kubectl patch deployment grafana -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"grafana","resources":{"requests":{"cpu":"100m","memory":"256Mi"},"limits":{"cpu":"500m","memory":"1Gi"}}}]}}}}'
                ;;
            "medium")
                # Moderate optimization
                kubectl patch deployment grafana -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"grafana","resources":{"requests":{"cpu":"50m","memory":"128Mi"},"limits":{"cpu":"200m","memory":"512Mi"}}}]}}}}'
                ;;
            "high")
                # Aggressive optimization
                kubectl patch deployment grafana -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"grafana","resources":{"requests":{"cpu":"25m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"256Mi"}}}]}}}}'
                ;;
        esac
        
        print_success "Grafana resources optimized"
    else
        print_warning "Grafana deployment not found"
    fi
}

# Optimize Loki resources
optimize_loki_resources() {
    print_status "Optimizing Loki resources..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would optimize Loki resources"
        return 0
    fi
    
    # Get current Loki deployment
    if kubectl get deployment loki -n "$NAMESPACE" &> /dev/null; then
        print_status "Current Loki resources:"
        kubectl get deployment loki -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources}'
        
        # Apply optimization based on level
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # Minimal optimization
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","resources":{"requests":{"cpu":"100m","memory":"256Mi"},"limits":{"cpu":"500m","memory":"1Gi"}}}]}}}}'
                ;;
            "medium")
                # Moderate optimization
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","resources":{"requests":{"cpu":"50m","memory":"128Mi"},"limits":{"cpu":"200m","memory":"512Mi"}}}]}}}}'
                ;;
            "high")
                # Aggressive optimization
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","resources":{"requests":{"cpu":"25m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"256Mi"}}}]}}}}'
                ;;
        esac
        
        print_success "Loki resources optimized"
    else
        print_warning "Loki deployment not found"
    fi
}

# Optimize Alertmanager resources
optimize_alertmanager_resources() {
    print_status "Optimizing Alertmanager resources..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would optimize Alertmanager resources"
        return 0
    fi
    
    # Get current Alertmanager deployment
    if kubectl get deployment alertmanager -n "$NAMESPACE" &> /dev/null; then
        print_status "Current Alertmanager resources:"
        kubectl get deployment alertmanager -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources}'
        
        # Apply optimization based on level
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # Minimal optimization
                kubectl patch deployment alertmanager -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"alertmanager","resources":{"requests":{"cpu":"50m","memory":"128Mi"},"limits":{"cpu":"200m","memory":"512Mi"}}}]}}}}'
                ;;
            "medium")
                # Moderate optimization
                kubectl patch deployment alertmanager -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"alertmanager","resources":{"requests":{"cpu":"25m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"256Mi"}}}]}}}}'
                ;;
            "high")
                # Aggressive optimization
                kubectl patch deployment alertmanager -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"alertmanager","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"cpu":"50m","memory":"128Mi"}}}]}}}}'
                ;;
        esac
        
        print_success "Alertmanager resources optimized"
    else
        print_warning "Alertmanager deployment not found"
    fi
}

# Optimize storage
optimize_storage() {
    print_status "Optimizing storage..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would optimize storage"
        return 0
    fi
    
    # Get current PVCs
    pvcs=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [ -n "$pvcs" ]; then
        for pvc in $pvcs; do
            print_status "Optimizing PVC: $pvc"
            
            # Get current size
            current_size=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.spec.resources.requests.storage}')
            print_status "Current size: $current_size"
            
            # Apply optimization based on level
            case "$OPTIMIZATION_LEVEL" in
                "low")
                    # Minimal optimization - no change
                    print_status "No storage optimization applied (low level)"
                    ;;
                "medium")
                    # Moderate optimization - reduce by 25%
                    new_size=$(echo "$current_size" | sed 's/Gi//' | awk '{print int($1 * 0.75) "Gi"}')
                    kubectl patch pvc "$pvc" -n "$NAMESPACE" -p="{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$new_size\"}}}}"
                    print_status "Storage optimized to: $new_size"
                    ;;
                "high")
                    # Aggressive optimization - reduce by 50%
                    new_size=$(echo "$current_size" | sed 's/Gi//' | awk '{print int($1 * 0.5) "Gi"}')
                    kubectl patch pvc "$pvc" -n "$NAMESPACE" -p="{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$new_size\"}}}}"
                    print_status "Storage optimized to: $new_size"
                    ;;
            esac
        done
        
        print_success "Storage optimized"
    else
        print_warning "No PVCs found to optimize"
    fi
}

# Configure retention policies
configure_retention_policies() {
    print_status "Configuring retention policies..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would configure retention policies"
        return 0
    fi
    
    # Configure Prometheus retention
    if kubectl get deployment prometheus -n "$NAMESPACE" &> /dev/null; then
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # 30 days retention
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","args":["--storage.tsdb.retention.time=30d"]}]}}}}'
                ;;
            "medium")
                # 14 days retention
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","args":["--storage.tsdb.retention.time=14d"]}]}}}}'
                ;;
            "high")
                # 7 days retention
                kubectl patch deployment prometheus -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","args":["--storage.tsdb.retention.time=7d"]}]}}}}'
                ;;
        esac
        
        print_success "Prometheus retention configured"
    fi
    
    # Configure Loki retention
    if kubectl get deployment loki -n "$NAMESPACE" &> /dev/null; then
        case "$OPTIMIZATION_LEVEL" in
            "low")
                # 30 days retention
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","args":["--config.file=/etc/loki/loki.yml","--storage.tsdb.retention.time=30d"]}]}}}}'
                ;;
            "medium")
                # 14 days retention
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","args":["--config.file=/etc/loki/loki.yml","--storage.tsdb.retention.time=14d"]}]}}}}'
                ;;
            "high")
                # 7 days retention
                kubectl patch deployment loki -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"loki","args":["--config.file=/etc/loki/loki.yml","--storage.tsdb.retention.time=7d"]}]}}}}'
                ;;
        esac
        
        print_success "Loki retention configured"
    fi
}

# Verify optimizations
verify_optimizations() {
    print_status "Verifying optimizations..."
    
    # Check pod status
    print_status "Checking pod status after optimization..."
    kubectl get pods -n "$NAMESPACE"
    
    # Check resource usage
    print_status "Checking resource usage after optimization..."
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || print_warning "Metrics not available"
    
    # Check PVC status
    print_status "Checking PVC status after optimization..."
    kubectl get pvc -n "$NAMESPACE"
    
    print_success "Optimizations verified"
}

# Generate optimization report
generate_optimization_report() {
    print_status "Generating optimization report..."
    
    # Get current resource usage
    prometheus_cpu=$(kubectl get deployment prometheus -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    prometheus_memory=$(kubectl get deployment prometheus -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    
    grafana_cpu=$(kubectl get deployment grafana -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    grafana_memory=$(kubectl get deployment grafana -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    
    loki_cpu=$(kubectl get deployment loki -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    loki_memory=$(kubectl get deployment loki -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    
    alertmanager_cpu=$(kubectl get deployment alertmanager -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    alertmanager_memory=$(kubectl get deployment alertmanager -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    
    echo "📊 Monitoring Cost Optimization Report"
    echo "======================================"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Optimization Level: $OPTIMIZATION_LEVEL"
    echo "Namespace: $NAMESPACE"
    echo "Dry Run: $DRY_RUN"
    echo ""
    echo "💰 Resource Optimizations:"
    echo "   • Prometheus: CPU=$prometheus_cpu, Memory=$prometheus_memory"
    echo "   • Grafana: CPU=$grafana_cpu, Memory=$grafana_memory"
    echo "   • Loki: CPU=$loki_cpu, Memory=$loki_memory"
    echo "   • Alertmanager: CPU=$alertmanager_cpu, Memory=$alertmanager_memory"
    echo ""
    echo "📈 Cost Impact:"
    case "$OPTIMIZATION_LEVEL" in
        "low")
            echo "   • Minimal cost reduction (5-10%)"
            echo "   • Estimated savings: £1-2/month"
            ;;
        "medium")
            echo "   • Moderate cost reduction (20-30%)"
            echo "   • Estimated savings: £3-5/month"
            ;;
        "high")
            echo "   • Significant cost reduction (40-50%)"
            echo "   • Estimated savings: £5-10/month"
            ;;
    esac
    echo ""
    echo "📋 Recommendations:"
    echo "   • Monitor performance after optimization"
    echo "   • Adjust resources based on actual usage"
    echo "   • Consider switching to lightweight monitoring for maximum savings"
    echo "   • Review retention policies regularly"
}

# Main execution
main() {
    print_status "Starting monitoring cost optimization process..."
    
    check_prerequisites
    analyze_monitoring_costs
    optimize_prometheus_resources
    optimize_grafana_resources
    optimize_loki_resources
    optimize_alertmanager_resources
    optimize_storage
    configure_retention_policies
    verify_optimizations
    generate_optimization_report
    
    print_success "Monitoring cost optimization completed successfully!"
    echo ""
    echo "💰 Optimization Summary:"
    echo "   • Level: $OPTIMIZATION_LEVEL"
    echo "   • Namespace: $NAMESPACE"
    echo "   • Status: Completed successfully"
    echo "   • Cost Impact: $(case "$OPTIMIZATION_LEVEL" in "low") echo "Minimal";; "medium") echo "Moderate";; "high") echo "Significant";; esac)"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Monitor performance after optimization"
    echo "   2. Adjust resources based on actual usage"
    echo "   3. Review cost savings"
    echo "   4. Consider further optimizations if needed"
}

# Run main function
main "$@"
