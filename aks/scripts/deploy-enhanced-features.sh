#!/bin/bash
# 🚀 Enhanced Features Deployment Script
# Deploys autoscaling, high availability, cost monitoring, and health checks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
ENABLE_AUTOSCALING="${ENABLE_AUTOSCALING:-true}"
ENABLE_HA="${ENABLE_HA:-true}"
# Cost monitoring requires Azure Service Principal by default
# Set to 'true' only if you have service principal credentials or Managed Identity
ENABLE_COST_MONITORING="${ENABLE_COST_MONITORING:-false}"
ENABLE_HEALTH_CHECKS="${ENABLE_HEALTH_CHECKS:-true}"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_ROCKETCHAT="rocketchat"

# Check prerequisites
check_prerequisites() {
    log_info "🔍 Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "No active Kubernetes cluster connection"
        exit 1
    fi
    
    # Check if required namespaces exist
    for namespace in "$NAMESPACE_ROCKETCHAT" "$NAMESPACE_MONITORING"; do
        if ! kubectl get namespace "$namespace" &> /dev/null; then
            log_error "Namespace $namespace does not exist"
            exit 1
        fi
    done
    
    log_success "Prerequisites check completed"
}

# Deploy autoscaling configuration
deploy_autoscaling() {
    if [[ "$ENABLE_AUTOSCALING" == "true" ]]; then
        log_info "📈 Deploying autoscaling configuration..."
        
        # Check if metrics server is available
        if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
            log_warning "Metrics server not found. Installing..."
            kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
            kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=300s
        fi
        
        # Deploy HPA and VPA configurations
        kubectl apply -f aks/monitoring/autoscaling-config.yaml
        
        # Wait for HPA to be ready
        kubectl wait --for=condition=ready hpa/rocketchat-hpa -n "$NAMESPACE_ROCKETCHAT" --timeout=60s || true
        
        log_success "Autoscaling configuration deployed"
    else
        log_info "⏭️ Autoscaling deployment skipped (ENABLE_AUTOSCALING=false)"
    fi
}

# Deploy high availability configuration
deploy_high_availability() {
    if [[ "$ENABLE_HA" == "true" ]]; then
        log_info "🔄 Deploying high availability configuration..."
        
        # Deploy PDBs, network policies, and priority classes
        kubectl apply -f aks/monitoring/high-availability-config.yaml
        
        # Verify PDBs are created
        kubectl get pdb -n "$NAMESPACE_ROCKETCHAT"
        kubectl get pdb -n "$NAMESPACE_MONITORING"
        
        log_success "High availability configuration deployed"
    else
        log_info "⏭️ High availability deployment skipped (ENABLE_HA=false)"
    fi
}

# Deploy cost monitoring
deploy_cost_monitoring() {
    if [[ "$ENABLE_COST_MONITORING" == "true" ]]; then
        log_info "💰 Deploying cost monitoring..."
        
        # Check if Azure credentials are available
        if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
            log_warning "Azure credentials not found. Cost monitoring will be limited."
        fi
        
        # Deploy Azure cost monitoring
        kubectl apply -f aks/monitoring/azure-cost-monitoring.yaml
        
        # Create Azure credentials secret if not exists
        if kubectl get secret azure-credentials -n "$NAMESPACE_MONITORING" &> /dev/null; then
            log_info "Azure credentials secret already exists"
        else
            log_warning "Azure credentials secret not found. Please create it manually:"
            echo "kubectl create secret generic azure-credentials -n $NAMESPACE_MONITORING \\"
            echo "  --from-literal=subscription-id=\$AZURE_SUBSCRIPTION_ID \\"
            echo "  --from-literal=client-id=\$AZURE_CLIENT_ID \\"
            echo "  --from-literal=client-secret=\$AZURE_CLIENT_SECRET \\"
            echo "  --from-literal=tenant-id=\$AZURE_TENANT_ID"
        fi
        
        log_success "Cost monitoring deployed"
    else
        log_info "⏭️ Cost monitoring deployment skipped (ENABLE_COST_MONITORING=false)"
    fi
}

# Deploy health check system
deploy_health_checks() {
    if [[ "$ENABLE_HEALTH_CHECKS" == "true" ]]; then
        log_info "🏥 Deploying health check system..."
        
        # Make health check script executable
        chmod +x scripts/health-check.sh
        
        # Create health check cron job
        cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-check-cronjob
  namespace: $NAMESPACE_MONITORING
  labels:
    app: health-check
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-check
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              # Run health check script
              if [ -f /scripts/health-check.sh ]; then
                /scripts/health-check.sh
              else
                echo "Health check script not found"
                exit 1
              fi
            volumeMounts:
            - name: scripts
              mountPath: /scripts
          volumes:
          - name: scripts
            configMap:
              name: health-check-scripts
          restartPolicy: OnFailure
EOF

        # Create health check scripts configmap
        kubectl create configmap health-check-scripts -n "$NAMESPACE_MONITORING" \
          --from-file=health-check.sh=scripts/health-check.sh \
          --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "Health check system deployed"
    else
        log_info "⏭️ Health check deployment skipped (ENABLE_HEALTH_CHECKS=false)"
    fi
}

# Verify deployment
verify_deployment() {
    log_info "🔍 Verifying deployment..."
    
    # Check autoscaling
    if [[ "$ENABLE_AUTOSCALING" == "true" ]]; then
        log_info "Checking autoscaling components..."
        kubectl get hpa -n "$NAMESPACE_ROCKETCHAT" || log_warning "HPA not found"
        kubectl get vpa -n "$NAMESPACE_ROCKETCHAT" || log_warning "VPA not found"
    fi
    
    # Check high availability
    if [[ "$ENABLE_HA" == "true" ]]; then
        log_info "Checking high availability components..."
        kubectl get pdb -n "$NAMESPACE_ROCKETCHAT" || log_warning "PDB not found"
        kubectl get networkpolicy -n "$NAMESPACE_ROCKETCHAT" || log_warning "NetworkPolicy not found"
        kubectl get priorityclass || log_warning "PriorityClass not found"
    fi
    
    # Check cost monitoring
    if [[ "$ENABLE_COST_MONITORING" == "true" ]]; then
        log_info "Checking cost monitoring components..."
        kubectl get deployment azure-cost-exporter -n "$NAMESPACE_MONITORING" || log_warning "Azure cost exporter not found"
        kubectl get servicemonitor azure-cost-exporter -n "$NAMESPACE_MONITORING" || log_warning "ServiceMonitor not found"
    fi
    
    # Check health checks
    if [[ "$ENABLE_HEALTH_CHECKS" == "true" ]]; then
        log_info "Checking health check components..."
        kubectl get cronjob health-check-cronjob -n "$NAMESPACE_MONITORING" || log_warning "Health check cronjob not found"
    fi
    
    log_success "Deployment verification completed"
}

# Run health check
run_health_check() {
    log_info "🏥 Running comprehensive health check..."
    
    if [[ -f "scripts/health-check.sh" ]]; then
        ./scripts/health-check.sh
    else
        log_warning "Health check script not found"
    fi
}

# Generate deployment report
generate_report() {
    log_info "📊 Generating deployment report..."
    
    local report_file="enhanced-features-deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat << EOF > "$report_file"
# 🚀 Enhanced Features Deployment Report

**Date**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Cluster**: $(kubectl config current-context 2>/dev/null || echo "Unknown")

## 🎯 Deployment Summary

### ✅ Features Deployed
- **Autoscaling**: $ENABLE_AUTOSCALING
- **High Availability**: $ENABLE_HA
- **Cost Monitoring**: $ENABLE_COST_MONITORING
- **Health Checks**: $ENABLE_HEALTH_CHECKS

## 📊 Component Status

### Autoscaling Components
\`\`\`
$(kubectl get hpa,vpa -n $NAMESPACE_ROCKETCHAT 2>/dev/null || echo "Not deployed")
\`\`\`

### High Availability Components
\`\`\`
$(kubectl get pdb,networkpolicy,priorityclass 2>/dev/null || echo "Not deployed")
\`\`\`

### Cost Monitoring Components
\`\`\`
$(kubectl get deployment,servicemonitor -n $NAMESPACE_MONITORING -l app=azure-cost-exporter 2>/dev/null || echo "Not deployed")
\`\`\`

### Health Check Components
\`\`\`
$(kubectl get cronjob -n $NAMESPACE_MONITORING -l app=health-check 2>/dev/null || echo "Not deployed")
\`\`\`

## 🔗 Access Information

- **Rocket.Chat**: https://chat.canepro.me
- **Grafana**: https://grafana.chat.canepro.me
- **Health Check**: \`./scripts/health-check.sh\`

## 📋 Next Steps

1. **Monitor Autoscaling**: Check HPA status and scaling events
2. **Verify HA**: Test pod disruption and recovery
3. **Review Costs**: Monitor cost dashboard in Grafana
4. **Health Monitoring**: Review health check reports

EOF

    log_success "Deployment report generated: $report_file"
    echo "$report_file"
}

# Main execution
main() {
    log_info "🚀 Starting enhanced features deployment..."
    echo "=========================================="
    
    check_prerequisites
    deploy_autoscaling
    deploy_high_availability
    deploy_cost_monitoring
    deploy_health_checks
    verify_deployment
    run_health_check
    
    local report_file=$(generate_report)
    
    echo ""
    echo "=========================================="
    log_success "🎉 Enhanced features deployment completed!"
    echo ""
    echo "📊 **Features Deployed**:"
    echo "   • Autoscaling: $ENABLE_AUTOSCALING"
    echo "   • High Availability: $ENABLE_HA"
    echo "   • Cost Monitoring: $ENABLE_COST_MONITORING"
    echo "   • Health Checks: $ENABLE_HEALTH_CHECKS"
    echo ""
    echo "📄 **Report**: $report_file"
    echo ""
    echo "🔗 **Access Information**:"
    echo "   • Rocket.Chat: https://chat.canepro.me"
    echo "   • Grafana: https://grafana.chat.canepro.me"
    echo "   • Health Check: ./scripts/health-check.sh"
    echo ""
    echo "📋 **Next Steps**:"
    echo "   1. Monitor autoscaling behavior"
    echo "   2. Test high availability features"
    echo "   3. Review cost monitoring dashboard"
    echo "   4. Set up health check alerts"
}

# Run main function
main "$@"
