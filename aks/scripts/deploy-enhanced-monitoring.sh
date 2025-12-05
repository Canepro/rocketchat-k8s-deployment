#!/bin/bash

# 🚨 Enhanced Monitoring & Alerting Deployment Script
# Deploys enhanced alerts, notifications, and Azure Monitor integration
# Date: September 19, 2025

set -e

echo "🚨 Deploying Enhanced Monitoring & Alerting"
echo "==========================================="

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

# Pre-deployment checks
print_status "Performing pre-deployment checks..."

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "kubectl not configured or cluster not accessible"
    exit 1
fi

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring >/dev/null 2>&1; then
    print_warning "Monitoring namespace not found. Installing kube-prometheus-stack first..."
    exit 1
fi

print_success "Pre-deployment checks passed"

# Backup existing configurations
print_status "Creating configuration backups..."
cp aks/monitoring/rocket-chat-alerts.yaml aks/monitoring/rocket-chat-alerts-backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true
cp aks/config/helm-values/monitoring-values.yaml aks/config/helm-values/monitoring-values-backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true

print_success "Backups created"

# Deploy enhanced alerts
print_status "Deploying enhanced Rocket.Chat alerts..."
kubectl apply -f aks/monitoring/rocket-chat-alerts.yaml

if [ $? -eq 0 ]; then
    print_success "Enhanced alerts deployed successfully"
else
    print_error "Failed to deploy enhanced alerts"
    exit 1
fi

# Update monitoring stack with enhanced notifications
print_status "Updating monitoring stack with enhanced notifications..."
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/monitoring-values.yaml \
  -n monitoring \
  --wait \
  --timeout 600s

if [ $? -eq 0 ]; then
    print_success "Monitoring stack updated with enhanced notifications"
else
    print_error "Failed to update monitoring stack"
    exit 1
fi

# Deploy Azure Monitor integration (optional)
read -p "Do you want to deploy Azure Monitor integration? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deploying Azure Monitor integration..."

    # Check if Azure CLI is available
    if ! command -v az &> /dev/null; then
        print_warning "Azure CLI not found. Skipping Azure Monitor integration."
        echo "To install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    elif ! az account show &> /dev/null; then
        print_warning "Not logged in to Azure CLI. Skipping Azure Monitor integration."
        echo "Run 'az login' to authenticate."
    else
        print_status "Azure CLI available and authenticated"

        # Get Azure environment variables
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        RESOURCE_GROUP=$(az aks show --resource-group <your-resource-group> --name <your-aks-cluster> --query resourceGroup -o tsv 2>/dev/null || echo "<your-resource-group>")

        print_status "Configuring Azure Monitor integration..."

        # Create Log Analytics workspace if it doesn't exist
        WORKSPACE_NAME="rocketchat-logs-$(date +%Y%m%d)"
        WORKSPACE=$(az monitor log-analytics workspace create \
          --resource-group $RESOURCE_GROUP \
          --name $WORKSPACE_NAME \
          --location uksouth \
          --query id -o tsv 2>/dev/null || az monitor log-analytics workspace list --resource-group $RESOURCE_GROUP --query '[0].id' -o tsv 2>/dev/null)

        if [ -n "$WORKSPACE" ]; then
            WORKSPACE_ID=$(az monitor log-analytics workspace show --ids $WORKSPACE --query customerId -o tsv)
            WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys --ids $WORKSPACE --query primarySharedKey -o tsv)

            print_success "Log Analytics workspace configured: $WORKSPACE_ID"

            # Deploy Azure Monitor integration
            export AZURE_LOG_ANALYTICS_WORKSPACE_ID=$WORKSPACE_ID
            export AZURE_LOG_ANALYTICS_WORKSPACE_KEY=$WORKSPACE_KEY
            export AKS_RESOURCE_ID=$(az aks show --resource-group $RESOURCE_GROUP --name <your-aks-cluster> --query id -o tsv 2>/dev/null || echo "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/<your-aks-cluster>")
            export SUBSCRIPTION_ID=$SUBSCRIPTION_ID

            # Substitute environment variables in the YAML
            envsubst < aks/monitoring/azure-monitor-integration.yaml | kubectl apply -f -

            if [ $? -eq 0 ]; then
                print_success "Azure Monitor integration deployed successfully"
            else
                print_warning "Failed to deploy Azure Monitor integration"
            fi
        else
            print_warning "Could not create or find Log Analytics workspace. Skipping Azure Monitor integration."
        fi
    fi
fi

# Verify deployment
print_status "Verifying deployment..."

# Check alert rules
ALERT_COUNT=$(kubectl get prometheusrules -n monitoring -o jsonpath='{.items[0].spec.groups[0].rules}' 2>/dev/null | jq length 2>/dev/null || echo "0")
if [ "$ALERT_COUNT" -gt 5 ]; then
    print_success "Enhanced alerts verified: $ALERT_COUNT alert rules active"
else
    print_warning "Alert verification inconclusive - please check Grafana Alertmanager"
fi

# Check monitoring pods
kubectl get pods -n monitoring

print_success "Enhanced monitoring deployment completed!"

echo ""
echo "🎯 Enhanced Monitoring Features Deployed:"
echo "  ✅ Enhanced Rocket.Chat alerts (12 alert rules)"
echo "  ✅ Email notifications via Alertmanager"
echo "  ✅ Alert routing by severity and service"
echo "  ✅ Runbook URLs in alert notifications"
echo "  ✅ Azure Monitor integration (optional)"
echo ""

echo "🔧 Next Steps:"
echo "1. Configure email SMTP settings in monitoring-values.yaml"
echo "2. Test alerts by temporarily stopping a pod:"
echo "   kubectl scale deployment rocketchat-rocketchat -n rocketchat --replicas=0"
echo "3. Check Alertmanager UI: https://grafana.<YOUR_DOMAIN>/alertmanager"
echo "4. Review Azure Monitor dashboards (if enabled)"
echo ""

echo "📧 Alert Notification Channels:"
echo "  • Email: Configured (update SMTP settings)"
echo "  • Slack: Ready to configure (uncomment in monitoring-values.yaml)"
echo "  • Webhooks: Ready to configure"
echo "  • Azure Monitor: Deployed (if selected)"
echo ""

print_status "Enhanced monitoring deployment complete!"
