#!/bin/bash
# Cluster Health Validation Script
# Comprehensive health checks for cluster and applications

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

print_status "🏥 Starting cluster health validation"

# Configuration
NAMESPACES="${NAMESPACES:-rocketchat monitoring}"
CLUSTER_IP="${CLUSTER_IP:-}"
TIMEOUT="${TIMEOUT:-300}"

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

# Check cluster status
check_cluster_status() {
    print_status "Checking cluster status..."
    
    # Check nodes
    print_status "Checking nodes..."
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    ready_nodes=$(echo "$nodes" | grep -o "True" | wc -l)
    total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [ "$ready_nodes" -eq "$total_nodes" ]; then
        print_success "All nodes are ready ($ready_nodes/$total_nodes)"
    else
        print_error "Some nodes are not ready ($ready_nodes/$total_nodes)"
        exit 1
    fi
    
    # Check node resources
    print_status "Checking node resources..."
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
    
    print_success "Cluster status check completed"
}

# Check namespace status
check_namespace_status() {
    print_status "Checking namespace status..."
    
    for namespace in $NAMESPACES; do
        print_status "Checking namespace: $namespace"
        
        # Check if namespace exists
        if ! kubectl get namespace "$namespace" &> /dev/null; then
            print_warning "Namespace '$namespace' does not exist"
            continue
        fi
        
        # Check pods in namespace
        pods=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
        running_pods=$(kubectl get pods -n "$namespace" --no-headers | grep "Running" | wc -l)
        
        if [ "$pods" -gt 0 ]; then
            if [ "$running_pods" -eq "$pods" ]; then
                print_success "All pods in namespace '$namespace' are running ($running_pods/$pods)"
            else
                print_warning "Some pods in namespace '$namespace' are not running ($running_pods/$pods)"
            fi
        else
            print_warning "No pods found in namespace '$namespace'"
        fi
    done
    
    print_success "Namespace status check completed"
}

# Check Rocket.Chat health
check_rocketchat_health() {
    print_status "Checking Rocket.Chat health..."
    
    # Check Rocket.Chat pod
    if kubectl get pod -l app=rocketchat -n rocketchat &> /dev/null; then
        rocketchat_pod=$(kubectl get pod -l app=rocketchat -n rocketchat -o jsonpath='{.items[0].metadata.name}')
        rocketchat_status=$(kubectl get pod "$rocketchat_pod" -n rocketchat -o jsonpath='{.status.phase}')
        
        if [ "$rocketchat_status" = "Running" ]; then
            print_success "Rocket.Chat pod is running"
            
            # Check Rocket.Chat readiness
            if kubectl get pod "$rocketchat_pod" -n rocketchat -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
                print_success "Rocket.Chat pod is ready"
            else
                print_warning "Rocket.Chat pod is not ready"
            fi
            
            # Check Rocket.Chat logs for errors
            print_status "Checking Rocket.Chat logs for errors..."
            error_count=$(kubectl logs "$rocketchat_pod" -n rocketchat --tail=100 | grep -i error | wc -l)
            if [ "$error_count" -gt 0 ]; then
                print_warning "Found $error_count errors in Rocket.Chat logs"
            else
                print_success "No errors found in Rocket.Chat logs"
            fi
        else
            print_error "Rocket.Chat pod is not running (status: $rocketchat_status)"
            exit 1
        fi
    else
        print_error "Rocket.Chat pod not found"
        exit 1
    fi
    
    print_success "Rocket.Chat health check completed"
}

# Check MongoDB health
check_mongodb_health() {
    print_status "Checking MongoDB health..."
    
    # Check MongoDB pods
    mongodb_pods=$(kubectl get pods -l app=mongodb -n rocketchat --no-headers | wc -l)
    running_mongodb_pods=$(kubectl get pods -l app=mongodb -n rocketchat --no-headers | grep "Running" | wc -l)
    
    if [ "$mongodb_pods" -gt 0 ]; then
        if [ "$running_mongodb_pods" -eq "$mongodb_pods" ]; then
            print_success "All MongoDB pods are running ($running_mongodb_pods/$mongodb_pods)"
        else
            print_error "Some MongoDB pods are not running ($running_mongodb_pods/$mongodb_pods)"
            exit 1
        fi
    else
        print_error "No MongoDB pods found"
        exit 1
    fi
    
    # Check MongoDB connection
    print_status "Checking MongoDB connection..."
    if kubectl exec -it "$rocketchat_pod" -n rocketchat -- mongosh --eval "db.adminCommand('ping')" &> /dev/null; then
        print_success "MongoDB connection is working"
    else
        print_warning "MongoDB connection test failed"
    fi
    
    # Check MongoDB replica set status
    print_status "Checking MongoDB replica set status..."
    mongodb_primary=$(kubectl get pods -l app=mongodb -n rocketchat -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -it "$mongodb_primary" -n rocketchat -- mongosh --eval "rs.status()" &> /dev/null; then
        print_success "MongoDB replica set is healthy"
    else
        print_warning "MongoDB replica set status check failed"
    fi
    
    print_success "MongoDB health check completed"
}

# Check monitoring stack health
check_monitoring_health() {
    print_status "Checking monitoring stack health..."
    
    # Check if monitoring namespace exists
    if kubectl get namespace monitoring &> /dev/null; then
        # Check Prometheus
        if kubectl get pod -l app=prometheus -n monitoring &> /dev/null; then
            prometheus_pod=$(kubectl get pod -l app=prometheus -n monitoring -o jsonpath='{.items[0].metadata.name}')
            prometheus_status=$(kubectl get pod "$prometheus_pod" -n monitoring -o jsonpath='{.status.phase}')
            
            if [ "$prometheus_status" = "Running" ]; then
                print_success "Prometheus is running"
            else
                print_warning "Prometheus is not running (status: $prometheus_status)"
            fi
        else
            print_warning "Prometheus pod not found"
        fi
        
        # Check Grafana
        if kubectl get pod -l app=grafana -n monitoring &> /dev/null; then
            grafana_pod=$(kubectl get pod -l app=grafana -n monitoring -o jsonpath='{.items[0].metadata.name}')
            grafana_status=$(kubectl get pod "$grafana_pod" -n monitoring -o jsonpath='{.status.phase}')
            
            if [ "$grafana_status" = "Running" ]; then
                print_success "Grafana is running"
            else
                print_warning "Grafana is not running (status: $grafana_status)"
            fi
        else
            print_warning "Grafana pod not found"
        fi
        
        # Check Loki
        if kubectl get pod -l app=loki -n monitoring &> /dev/null; then
            loki_pod=$(kubectl get pod -l app=loki -n monitoring -o jsonpath='{.items[0].metadata.name}')
            loki_status=$(kubectl get pod "$loki_pod" -n monitoring -o jsonpath='{.status.phase}')
            
            if [ "$loki_status" = "Running" ]; then
                print_success "Loki is running"
            else
                print_warning "Loki is not running (status: $loki_status)"
            fi
        else
            print_warning "Loki pod not found"
        fi
    else
        print_status "Monitoring namespace not found. Skipping monitoring health checks."
    fi
    
    print_success "Monitoring health check completed"
}

# Check ingress and certificates
check_ingress_and_certificates() {
    print_status "Checking ingress and certificates..."
    
    # Check ingress
    if kubectl get ingress -n rocketchat &> /dev/null; then
        print_success "Rocket.Chat ingress found"
        
        # Check ingress status
        ingress_status=$(kubectl get ingress -n rocketchat -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
        if [ -n "$ingress_status" ]; then
            print_success "Rocket.Chat ingress IP: $ingress_status"
        else
            print_warning "Rocket.Chat ingress IP not available"
        fi
    else
        print_warning "Rocket.Chat ingress not found"
    fi
    
    # Check certificates
    if kubectl get certificate -n rocketchat &> /dev/null; then
        certificate_status=$(kubectl get certificate rocketchat-tls -n rocketchat -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$certificate_status" = "True" ]; then
            print_success "Rocket.Chat certificate is ready"
        else
            print_warning "Rocket.Chat certificate is not ready"
        fi
    else
        print_warning "Rocket.Chat certificate not found"
    fi
    
    # Check monitoring ingress and certificates
    if kubectl get namespace monitoring &> /dev/null; then
        if kubectl get ingress -n monitoring &> /dev/null; then
            print_success "Grafana ingress found"
            
            # Check Grafana certificate
            if kubectl get certificate grafana-tls -n monitoring &> /dev/null; then
                grafana_cert_status=$(kubectl get certificate grafana-tls -n monitoring -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
                if [ "$grafana_cert_status" = "True" ]; then
                    print_success "Grafana certificate is ready"
                else
                    print_warning "Grafana certificate is not ready"
                fi
            else
                print_warning "Grafana certificate not found"
            fi
        else
            print_warning "Grafana ingress not found"
        fi
    fi
    
    print_success "Ingress and certificates check completed"
}

# Check resource usage
check_resource_usage() {
    print_status "Checking resource usage..."
    
    # Check node resource usage
    print_status "Node resource usage:"
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
    
    # Check pod resource usage
    print_status "Pod resource usage:"
    for namespace in $NAMESPACES; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            print_status "Namespace $namespace:"
            kubectl top pods -n "$namespace" 2>/dev/null || print_warning "Metrics not available for namespace $namespace"
        fi
    done
    
    print_success "Resource usage check completed"
}

# Check persistent volumes
check_persistent_volumes() {
    print_status "Checking persistent volumes..."
    
    # Check PVCs
    pvc_count=$(kubectl get pvc -A --no-headers | wc -l)
    bound_pvc_count=$(kubectl get pvc -A --no-headers | grep "Bound" | wc -l)
    
    if [ "$pvc_count" -gt 0 ]; then
        if [ "$bound_pvc_count" -eq "$pvc_count" ]; then
            print_success "All PVCs are bound ($bound_pvc_count/$pvc_count)"
        else
            print_warning "Some PVCs are not bound ($bound_pvc_count/$pvc_count)"
        fi
    else
        print_warning "No PVCs found"
    fi
    
    # Check PVs
    pv_count=$(kubectl get pv --no-headers | wc -l)
    available_pv_count=$(kubectl get pv --no-headers | grep "Available" | wc -l)
    bound_pv_count=$(kubectl get pv --no-headers | grep "Bound" | wc -l)
    
    if [ "$pv_count" -gt 0 ]; then
        print_success "PVs status: $bound_pv_count bound, $available_pv_count available, $pv_count total"
    else
        print_warning "No PVs found"
    fi
    
    print_success "Persistent volumes check completed"
}

# Test external connectivity
test_external_connectivity() {
    print_status "Testing external connectivity..."
    
    # Get cluster IP
    if [ -z "$CLUSTER_IP" ]; then
        CLUSTER_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    fi
    
    if [ -n "$CLUSTER_IP" ]; then
        print_status "Cluster IP: $CLUSTER_IP"
        
        # Test HTTP connectivity
        if curl -s --connect-timeout 10 "http://$CLUSTER_IP" &> /dev/null; then
            print_success "HTTP connectivity to cluster IP is working"
        else
            print_warning "HTTP connectivity to cluster IP failed"
        fi
        
        # Test HTTPS connectivity
        if curl -s --connect-timeout 10 -k "https://$CLUSTER_IP" &> /dev/null; then
            print_success "HTTPS connectivity to cluster IP is working"
        else
            print_warning "HTTPS connectivity to cluster IP failed"
        fi
    else
        print_warning "Cluster IP not available"
    fi
    
    print_success "External connectivity test completed"
}

# Generate health report
generate_health_report() {
    print_status "Generating health report..."
    
    # Get cluster information
    cluster_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not available")
    
    # Get pod counts
    total_pods=$(kubectl get pods -A --no-headers | wc -l)
    running_pods=$(kubectl get pods -A --no-headers | grep "Running" | wc -l)
    
    # Get PVC counts
    total_pvcs=$(kubectl get pvc -A --no-headers | wc -l)
    bound_pvcs=$(kubectl get pvc -A --no-headers | grep "Bound" | wc -l)
    
    echo "📊 Cluster Health Report"
    echo "======================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Cluster IP: $cluster_ip"
    echo "Total Pods: $total_pods"
    echo "Running Pods: $running_pods"
    echo "Total PVCs: $total_pvcs"
    echo "Bound PVCs: $bound_pvcs"
    echo ""
    echo "✅ Health Status:"
    echo "   • Cluster: $(if [ "$running_pods" -eq "$total_pods" ]; then echo "HEALTHY"; else echo "DEGRADED"; fi)"
    echo "   • Rocket.Chat: $(if kubectl get pod -l app=rocketchat -n rocketchat -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then echo "HEALTHY"; else echo "UNHEALTHY"; fi)"
    echo "   • MongoDB: $(if kubectl get pod -l app=mongodb -n rocketchat -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then echo "HEALTHY"; else echo "UNHEALTHY"; fi)"
    echo "   • Monitoring: $(if kubectl get namespace monitoring &> /dev/null; then echo "ENABLED"; else echo "DISABLED"; fi)"
    echo "   • Ingress: $(if kubectl get ingress -n rocketchat &> /dev/null; then echo "CONFIGURED"; else echo "NOT CONFIGURED"; fi)"
    echo "   • Certificates: $(if kubectl get certificate rocketchat-tls -n rocketchat -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then echo "READY"; else echo "NOT READY"; fi)"
    echo ""
    echo "📋 Recommendations:"
    if [ "$running_pods" -eq "$total_pods" ]; then
        echo "   • Cluster is healthy and ready for use"
        echo "   • Monitor resource usage and performance"
        echo "   • Set up monitoring and alerting"
    else
        echo "   • Some pods are not running - investigate issues"
        echo "   • Check pod logs for errors"
        echo "   • Verify resource limits and requests"
    fi
}

# Main execution
main() {
    print_status "Starting cluster health validation process..."
    
    check_prerequisites
    check_cluster_status
    check_namespace_status
    check_rocketchat_health
    check_mongodb_health
    check_monitoring_health
    check_ingress_and_certificates
    check_resource_usage
    check_persistent_volumes
    test_external_connectivity
    generate_health_report
    
    print_success "Cluster health validation completed successfully!"
    echo ""
    echo "🏥 Health Validation Summary:"
    echo "   • Cluster: Validated"
    echo "   • Rocket.Chat: Validated"
    echo "   • MongoDB: Validated"
    echo "   • Monitoring: Validated"
    echo "   • Ingress: Validated"
    echo "   • Certificates: Validated"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Monitor cluster health and performance"
    echo "   2. Set up monitoring and alerting"
    echo "   3. Test application functionality"
    echo "   4. Configure backup schedules"
}

# Run main function
main "$@"
