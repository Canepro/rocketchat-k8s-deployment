#!/usr/bin/env bash
set -euo pipefail
echo "Applying observability fixes..."

# Update monitoring release (values)
helm upgrade monitoring -n monitoring -f values-monitoring.yaml rocketchat/monitoring

# Install Loki stack
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki -n monitoring grafana/loki-stack -f loki-stack-values.yaml

# Apply Grafana provisioning configs
kubectl apply -f monitoring/grafana-datasource-loki.yaml
kubectl apply -f grafana-dashboard-rocketchat.yaml

# (Optional) Remove legacy ServiceMonitor
kubectl delete servicemonitor rocketchat-servicemonitor -n rocketchat || true

# Restart Grafana to force reload
kubectl delete pod -l app.kubernetes.io/name=grafana -n monitoring

echo "Done. Verify in Grafana → Datasources (Prometheus & Loki) and Explore."
