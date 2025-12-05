#!/bin/bash

# Fix Loki Volume API and Dashboard Issues
# This script fixes the Loki volume API 404 error and dashboard panel issues

set -e

echo "🔧 Fixing Loki Volume API and Dashboard Issues..."

# Set namespace variables
LOKI_NAMESPACE="loki-stack"
MONITORING_NAMESPACE="monitoring"

echo "📋 Current issues being fixed:"
echo "  1. Loki volume API 404 error - enabling volume feature"
echo "  2. Rocket.Chat Pod Restarts panel showing wrong data"
echo "  3. Adding proper Total Users vs Active Users panel"

# Check if we're connected to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Not connected to Kubernetes cluster"
    echo "   Please run: az aks get-credentials --resource-group <resource-group> --name <cluster-name>"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Apply Loki configuration with volume enabled
echo "🔧 Updating Loki configuration with volume enabled..."
helm upgrade loki-stack grafana/loki-stack \
  --namespace $LOKI_NAMESPACE \
  --values ../../aks/monitoring/loki-values.yaml \
  --wait --timeout=300s

# Wait for Loki to restart
echo "⏳ Waiting for Loki to restart with new configuration..."
kubectl rollout status deployment/loki -n $LOKI_NAMESPACE --timeout=300s

# Apply the fixed dashboard
echo "📊 Applying fixed Rocket.Chat dashboard..."
kubectl apply -f ../../aks/monitoring/rocket-chat-dashboard-configmap.yaml -n $MONITORING_NAMESPACE

# Restart Grafana to pick up the new dashboard
echo "🔄 Restarting Grafana to load updated dashboard..."
kubectl rollout restart deployment/grafana -n $MONITORING_NAMESPACE

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl rollout status deployment/grafana -n $MONITORING_NAMESPACE --timeout=300s

echo "✅ All fixes applied successfully!"
echo ""
echo "📋 Summary of changes:"
echo "  ✅ Loki volume API enabled (fixes 404 error)"
echo "  ✅ Rocket.Chat Pod Restarts panel now shows actual pod restart metrics"
echo "  ✅ Added Total Users vs Active Users panel"
echo ""
echo "🌐 Access your updated dashboard at: https://grafana.<YOUR_DOMAIN>"
echo ""
echo "🔍 To verify the fixes:"
echo "  1. Check Loki logs: kubectl logs -n $LOKI_NAMESPACE deployment/loki"
echo "  2. Check Grafana logs: kubectl logs -n $MONITORING_NAMESPACE deployment/grafana"
echo "  3. Visit the dashboard and verify the panels show correct data"
