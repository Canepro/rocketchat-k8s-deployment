#!/bin/bash

# Deploy Distributed Tracing Stack for Rocket.Chat
# This script deploys Tempo, OpenTelemetry Collector, and integrates with existing Grafana

set -e

echo "🚀 Deploying Distributed Tracing Stack for Rocket.Chat..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ helm is not installed or not in PATH"
    exit 1
fi

# Ensure we're in the right namespace
kubectl config set-context --current --namespace=monitoring

echo "📦 Deploying Tempo (Distributed Tracing Backend)..."

# Deploy Tempo using the values file
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Tempo
helm install tempo grafana/tempo \
  -f aks/monitoring/tempo-values.yaml \
  --namespace monitoring \
  --create-namespace \
  --wait

echo "✅ Tempo deployed successfully"

echo "📊 Deploying OpenTelemetry Collector..."

# Apply OpenTelemetry Collector
kubectl apply -f aks/monitoring/opentelemetry-collector.yaml

echo "✅ OpenTelemetry Collector deployed successfully"

echo "🔗 Configuring Grafana Tempo Data Source..."

# Apply Tempo datasource configuration
kubectl apply -f aks/monitoring/grafana-tempo-datasource.yaml

echo "✅ Grafana Tempo datasource configured"

echo "📈 Deploying Tracing Dashboard..."

# Apply tracing dashboard
kubectl apply -f aks/monitoring/grafana-tracing-dashboard.yaml

echo "✅ Tracing dashboard deployed"

echo "🔧 Configuring Rocket.Chat Tracing Instrumentation..."

# Apply Rocket.Chat tracing configuration
kubectl apply -f aks/monitoring/rocketchat-tracing-instrumentation.yaml

echo "✅ Rocket.Chat tracing instrumentation configured"

echo "🎯 Verifying Deployment..."

# Wait for pods to be ready
echo "⏳ Waiting for Tempo to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tempo -n monitoring --timeout=300s

echo "⏳ Waiting for OpenTelemetry Collector to be ready..."
kubectl wait --for=condition=ready pod -l app=otel-collector -n monitoring --timeout=300s

echo "🔍 Checking deployment status..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo
kubectl get pods -n monitoring -l app=otel-collector

echo "📋 Deployment Summary:"
echo "✅ Tempo: Distributed tracing backend"
echo "✅ OpenTelemetry Collector: Trace collection and forwarding"
echo "✅ Grafana Integration: Tempo datasource configured"
echo "✅ Tracing Dashboard: Comprehensive tracing visualization"
echo "✅ Rocket.Chat Instrumentation: OpenTelemetry tracing enabled"

echo ""
echo "🎉 Distributed Tracing Stack Deployed Successfully!"
echo ""
echo "📊 Access your tracing dashboard at:"
echo "   https://grafana.canepro.me/d/rocket-chat-tracing"
echo ""
echo "🔍 Key Features:"
echo "   • Request tracing across Rocket.Chat services"
echo "   • Performance bottleneck identification"
echo "   • Error correlation and debugging"
echo "   • End-to-end request visibility"
echo "   • Integration with existing metrics and logs"
echo ""
echo "🚀 Your observability stack is now complete:"
echo "   • Metrics: Prometheus"
echo "   • Logs: Loki"
echo "   • Traces: Tempo"
echo "   • Visualization: Grafana"
