#!/bin/bash
# 🏥 Comprehensive Health Check Script for Rocket.Chat AKS Deployment
# Performs end-to-end health checks for all components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACES=("rocketchat" "monitoring" "ingress-nginx" "cert-manager")
TIMEOUT=300
HEALTH_CHECK_INTERVAL=10

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Health check results
declare -A HEALTH_RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to record health check results
record_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    HEALTH_RESULTS["$check_name"]="$status|$message"
    
    if [[ "$status" == "PASS" ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        log_success "$check_name: $message"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        log_error "$check_name: $message"
    fi
}

# Check if kubectl is available and cluster is accessible
check_cluster_connectivity() {
    log_info "🔍 Checking cluster connectivity..."
    
    if ! kubectl cluster-info &> /dev/null; then
        record_check "cluster-connectivity" "FAIL" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    local cluster_info=$(kubectl cluster-info --short 2>/dev/null || echo "Cluster info not available")
    record_check "cluster-connectivity" "PASS" "Connected to cluster: $cluster_info"
}

# Check node health
check_node_health() {
    log_info "🔍 Checking node health..."
    
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
    local not_ready_nodes=$((total_nodes - ready_nodes))
    
    if [[ $not_ready_nodes -gt 0 ]]; then
        record_check "node-health" "FAIL" "$not_ready_nodes out of $total_nodes nodes not ready"
        kubectl get nodes
    else
        record_check "node-health" "PASS" "All $total_nodes nodes are ready"
    fi
}

# Check namespace existence
check_namespaces() {
    log_info "🔍 Checking required namespaces..."
    
    for namespace in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            record_check "namespace-$namespace" "PASS" "Namespace $namespace exists"
        else
            record_check "namespace-$namespace" "FAIL" "Namespace $namespace not found"
        fi
    done
}

# Check pod health in namespace
check_pod_health() {
    local namespace="$1"
    local app_label="$2"
    local expected_replicas="${3:-1}"
    
    log_info "🔍 Checking pod health in namespace $namespace..."
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        record_check "pods-$namespace" "FAIL" "Namespace $namespace not found"
        return 1
    fi
    
    local total_pods=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
    local ready_pods=$(kubectl get pods -n "$namespace" --no-headers | grep -c "Running" || echo "0")
    local pending_pods=$(kubectl get pods -n "$namespace" --no-headers | grep -c "Pending" || echo "0")
    local failed_pods=$(kubectl get pods -n "$namespace" --no-headers | grep -c "Failed\|CrashLoopBackOff\|Error" || echo "0")
    
    if [[ $failed_pods -gt 0 ]]; then
        record_check "pods-$namespace" "FAIL" "$failed_pods failed pods, $ready_pods running, $pending_pods pending"
        kubectl get pods -n "$namespace"
    elif [[ $pending_pods -gt 0 ]]; then
        record_check "pods-$namespace" "WARN" "$pending_pods pending pods, $ready_pods running"
    else
        record_check "pods-$namespace" "PASS" "All $ready_pods pods running successfully"
    fi
}

# Check service endpoints
check_service_endpoints() {
    local namespace="$1"
    local service_name="$2"
    
    log_info "🔍 Checking service $service_name in namespace $namespace..."
    
    if ! kubectl get service "$service_name" -n "$namespace" &> /dev/null; then
        record_check "service-$service_name" "FAIL" "Service $service_name not found"
        return 1
    fi
    
    local endpoints=$(kubectl get endpoints "$service_name" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [[ -z "$endpoints" ]]; then
        record_check "service-$service_name" "FAIL" "No endpoints available for service $service_name"
    else
        local endpoint_count=$(echo "$endpoints" | wc -w)
        record_check "service-$service_name" "PASS" "Service $service_name has $endpoint_count endpoints"
    fi
}

# Check Rocket.Chat application health
check_rocketchat_health() {
    log_info "🔍 Checking Rocket.Chat application health..."
    
    # Check Rocket.Chat pods
    check_pod_health "rocketchat" "rocketchat" 1
    
    # Check Rocket.Chat service
    check_service_endpoints "rocketchat" "rocketchat-rocketchat"
    
    # Check Rocket.Chat ingress
    if kubectl get ingress -n rocketchat &> /dev/null; then
        local ingress_status=$(kubectl get ingress -n rocketchat -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
        if [[ "$ingress_status" != "pending" && -n "$ingress_status" ]]; then
            record_check "rocketchat-ingress" "PASS" "Ingress IP: $ingress_status"
        else
            record_check "rocketchat-ingress" "WARN" "Ingress IP not yet assigned"
        fi
    else
        record_check "rocketchat-ingress" "FAIL" "No ingress found for Rocket.Chat"
    fi
    
    # Test Rocket.Chat connectivity (if ingress is available)
    local ingress_ip=$(kubectl get ingress -n rocketchat -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$ingress_ip" && "$ingress_ip" != "pending" ]]; then
        if curl -s -o /dev/null -w "%{http_code}" "http://$ingress_ip" | grep -q "200\|301\|302"; then
            record_check "rocketchat-connectivity" "PASS" "Rocket.Chat responding on $ingress_ip"
        else
            record_check "rocketchat-connectivity" "WARN" "Rocket.Chat not responding on $ingress_ip"
        fi
    else
        record_check "rocketchat-connectivity" "WARN" "Cannot test connectivity - no ingress IP"
    fi
}

# Check MongoDB health
check_mongodb_health() {
    log_info "🔍 Checking MongoDB health..."
    
    # Check MongoDB pods
    check_pod_health "rocketchat" "mongodb" 1
    
    # Check MongoDB service
    check_service_endpoints "rocketchat" "mongodb-headless"
    
    # Test MongoDB connectivity
    local mongodb_pod=$(kubectl get pods -n rocketchat -l app=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$mongodb_pod" ]]; then
        if kubectl exec -n rocketchat "$mongodb_pod" -- mongo --eval "db.stats()" &> /dev/null; then
            record_check "mongodb-connectivity" "PASS" "MongoDB responding to queries"
        else
            record_check "mongodb-connectivity" "FAIL" "MongoDB not responding to queries"
        fi
    else
        record_check "mongodb-connectivity" "FAIL" "No MongoDB pod found"
    fi
}

# Check monitoring stack health
check_monitoring_health() {
    log_info "🔍 Checking monitoring stack health..."
    
    # Check Prometheus
    check_pod_health "monitoring" "prometheus" 1
    check_service_endpoints "monitoring" "monitoring-kube-prometheus-prometheus"
    
    # Check Grafana
    check_pod_health "monitoring" "grafana" 1
    check_service_endpoints "monitoring" "monitoring-grafana"
    
    # Check Loki
    check_pod_health "monitoring" "loki" 1
    check_service_endpoints "monitoring" "loki-stack"
    
    # Check Alertmanager
    check_pod_health "monitoring" "alertmanager" 1
    check_service_endpoints "monitoring" "monitoring-kube-prometheus-alertmanager"
}

# Check SSL certificates
check_ssl_certificates() {
    log_info "🔍 Checking SSL certificates..."
    
    # Check cert-manager
    check_pod_health "cert-manager" "cert-manager" 1
    
    # Check Rocket.Chat certificate
    if kubectl get certificate rocketchat-tls -n rocketchat &> /dev/null; then
        local cert_status=$(kubectl get certificate rocketchat-tls -n rocketchat -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [[ "$cert_status" == "True" ]]; then
            record_check "ssl-rocketchat" "PASS" "Rocket.Chat SSL certificate is ready"
        else
            record_check "ssl-rocketchat" "WARN" "Rocket.Chat SSL certificate not ready: $cert_status"
        fi
    else
        record_check "ssl-rocketchat" "FAIL" "Rocket.Chat SSL certificate not found"
    fi
    
    # Check Grafana certificate
    if kubectl get certificate grafana-tls -n monitoring &> /dev/null; then
        local cert_status=$(kubectl get certificate grafana-tls -n monitoring -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [[ "$cert_status" == "True" ]]; then
            record_check "ssl-grafana" "PASS" "Grafana SSL certificate is ready"
        else
            record_check "ssl-grafana" "WARN" "Grafana SSL certificate not ready: $cert_status"
        fi
    else
        record_check "ssl-grafana" "WARN" "Grafana SSL certificate not found"
    fi
}

# Check resource usage
check_resource_usage() {
    log_info "🔍 Checking resource usage..."
    
    # Check node resource usage
    local node_count=$(kubectl get nodes --no-headers | wc -l)
    local high_cpu_nodes=$(kubectl top nodes --no-headers | awk '$3 > 80 {print $1}' | wc -l)
    local high_memory_nodes=$(kubectl top nodes --no-headers | awk '$5 > 80 {print $1}' | wc -l)
    
    if [[ $high_cpu_nodes -gt 0 ]]; then
        record_check "resource-cpu" "WARN" "$high_cpu_nodes nodes with high CPU usage (>80%)"
    else
        record_check "resource-cpu" "PASS" "CPU usage within normal limits"
    fi
    
    if [[ $high_memory_nodes -gt 0 ]]; then
        record_check "resource-memory" "WARN" "$high_memory_nodes nodes with high memory usage (>80%)"
    else
        record_check "resource-memory" "PASS" "Memory usage within normal limits"
    fi
    
    # Check pod resource usage
    local high_cpu_pods=$(kubectl top pods -A --no-headers | awk '$3 > 80 {print $1"/"$2}' | wc -l)
    local high_memory_pods=$(kubectl top pods -A --no-headers | awk '$5 > 80 {print $1"/"$2}' | wc -l)
    
    if [[ $high_cpu_pods -gt 0 ]]; then
        record_check "resource-pods-cpu" "WARN" "$high_cpu_pods pods with high CPU usage"
    else
        record_check "resource-pods-cpu" "PASS" "Pod CPU usage within normal limits"
    fi
    
    if [[ $high_memory_pods -gt 0 ]]; then
        record_check "resource-pods-memory" "WARN" "$high_memory_pods pods with high memory usage"
    else
        record_check "resource-pods-memory" "PASS" "Pod memory usage within normal limits"
    fi
}

# Check persistent volumes
check_persistent_volumes() {
    log_info "🔍 Checking persistent volumes..."
    
    local total_pvs=$(kubectl get pv --no-headers | wc -l)
    local bound_pvs=$(kubectl get pv --no-headers | grep -c "Bound" || echo "0")
    local available_pvs=$(kubectl get pv --no-headers | grep -c "Available" || echo "0")
    local failed_pvs=$(kubectl get pv --no-headers | grep -c "Failed" || echo "0")
    
    if [[ $failed_pvs -gt 0 ]]; then
        record_check "persistent-volumes" "FAIL" "$failed_pvs failed PVs, $bound_pvs bound, $available_pvs available"
    else
        record_check "persistent-volumes" "PASS" "$bound_pvs bound PVs, $available_pvs available"
    fi
}

# Generate health check report
generate_report() {
    log_info "📊 Generating health check report..."
    
    local report_file="health-check-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat << EOF > "$report_file"
# 🏥 Health Check Report

**Date**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Cluster**: $(kubectl config current-context 2>/dev/null || echo "Unknown")
**Total Checks**: $TOTAL_CHECKS
**Passed**: $PASSED_CHECKS
**Failed**: $FAILED_CHECKS
**Success Rate**: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%

## 📊 Summary

EOF

    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo "✅ **All health checks passed!**" >> "$report_file"
    else
        echo "❌ **$FAILED_CHECKS health checks failed**" >> "$report_file"
    fi
    
    cat << EOF >> "$report_file"

## 🔍 Detailed Results

EOF

    for check_name in "${!HEALTH_RESULTS[@]}"; do
        local status=$(echo "${HEALTH_RESULTS[$check_name]}" | cut -d'|' -f1)
        local message=$(echo "${HEALTH_RESULTS[$check_name]}" | cut -d'|' -f2)
        
        if [[ "$status" == "PASS" ]]; then
            echo "- ✅ **$check_name**: $message" >> "$report_file"
        elif [[ "$status" == "WARN" ]]; then
            echo "- ⚠️ **$check_name**: $message" >> "$report_file"
        else
            echo "- ❌ **$check_name**: $message" >> "$report_file"
        fi
    done
    
    cat << EOF >> "$report_file"

## 🚀 Cluster Status

\`\`\`
$(kubectl get nodes)
\`\`\`

## 📊 Pod Status

### Rocket.Chat
\`\`\`
$(kubectl get pods -n rocketchat)
\`\`\`

### Monitoring
\`\`\`
$(kubectl get pods -n monitoring)
\`\`\`

## 💾 Resource Usage

\`\`\`
$(kubectl top nodes 2>/dev/null || echo "Metrics not available")
\`\`\`

\`\`\`
$(kubectl top pods -A 2>/dev/null || echo "Metrics not available")
\`\`\`

## 🔗 Access Information

- **Rocket.Chat**: https://chat.canepro.me
- **Grafana**: https://grafana.chat.canepro.me
- **Port Forward**: \`kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring\`

EOF

    log_success "Health check report generated: $report_file"
    echo "$report_file"
}

# Main health check execution
main() {
    log_info "🏥 Starting comprehensive health check..."
    echo "=========================================="
    
    # Core cluster checks
    check_cluster_connectivity
    check_node_health
    check_namespaces
    
    # Application health checks
    check_rocketchat_health
    check_mongodb_health
    check_monitoring_health
    
    # Infrastructure checks
    check_ssl_certificates
    check_resource_usage
    check_persistent_volumes
    
    # Generate report
    local report_file=$(generate_report)
    
    echo ""
    echo "=========================================="
    log_info "🏥 Health check completed!"
    echo ""
    echo "📊 **Summary**:"
    echo "   • Total Checks: $TOTAL_CHECKS"
    echo "   • Passed: $PASSED_CHECKS"
    echo "   • Failed: $FAILED_CHECKS"
    echo "   • Success Rate: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
    echo ""
    echo "📄 **Report**: $report_file"
    echo ""
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        log_success "🎉 All health checks passed!"
        exit 0
    else
        log_error "❌ $FAILED_CHECKS health checks failed"
        exit 1
    fi
}

# Run main function
main "$@"
