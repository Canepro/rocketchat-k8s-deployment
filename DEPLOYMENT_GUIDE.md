# 🚀 Rocket.Chat AKS Deployment Guide

**Last Updated**: October 30, 2025  
**Status**: Production Ready ✅

## Quick Start

This guide provides step-by-step instructions for deploying the complete Rocket.Chat infrastructure on Azure Kubernetes Service.

---

## Prerequisites

- **Azure Subscription** with AKS permissions
- **kubectl** (v1.25+) configured
- **Helm** (v3.x) installed
- **Domain name** with DNS management
- **Azure CLI** (az) logged in

---

## 1. Deploy Base Infrastructure

### Deploy Rocket.Chat Application

```bash
cd aks/deployment
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

This deploys:
- Rocket.Chat application pods
- MongoDB replica set
- Ingress with SSL/TLS
- Microservices (DDP Streamer, Presence, etc.)

---

## 2. Deploy Monitoring Stack

### Install Prometheus & Grafana

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f aks/config/helm-values/monitoring-values.yaml \
  --create-namespace \
  --wait \
  --timeout 10m0s
```

### Deploy ServiceMonitors

```bash
kubectl apply -f aks/monitoring/rocketchat-servicemonitors.yaml
kubectl apply -f aks/monitoring/mongodb-servicemonitor.yaml
```

### Deploy Dashboards

```bash
# Comprehensive Rocket.Chat Dashboard
kubectl apply -f aks/monitoring/rocket-chat-dashboard-comprehensive-configmap.yaml

# Alert Rules
kubectl apply -f aks/monitoring/rocket-chat-alerts.yaml
```

---

## 3. Deploy Logging Stack

### Install Loki

```bash
helm upgrade --install loki-stack grafana/loki-stack \
  -f aks/monitoring/loki-values.yaml \
  -n loki-stack \
  --create-namespace \
  --wait
```

### Configure Loki Datasource

```bash
kubectl apply -f aks/monitoring/grafana-datasource-loki.yaml
kubectl rollout restart deployment monitoring-grafana -n monitoring
```

---

## 4. Deploy Distributed Tracing

### Deploy Tracing Stack

```bash
cd aks/scripts
chmod +x deploy-tracing-stack.sh
./deploy-tracing-stack.sh
```

This deploys:
- Grafana Tempo (trace storage)
- OpenTelemetry Collector (trace collection)
- Tempo Datasource for Grafana
- Rocket.Chat OpenTelemetry instrumentation
- Tracing Dashboard

### Verify Tracing

```bash
# Check Tempo
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Check OpenTelemetry Collector
kubectl get pods -n monitoring -l app=otel-collector

# Check Rocket.Chat instrumentation
kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat | grep OpenTelemetry
```

---

## 5. Access Services

### Get Service URLs

```bash
# Rocket.Chat
echo "https://chat.canepro.me"

# Grafana
echo "https://grafana.canepro.me"

# Or port-forward
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | `admin` | `prom-operator` |
| Rocket.Chat | Set during first login | - |

---

## 6. Verify Deployment

### Run Health Check

```bash
./scripts/health-check.sh
```

### Check Metrics

```bash
# Check if metrics are being collected
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Visit http://localhost:9090 and query:
# rocketchat_users_active
# rocketchat_messages_total
```

### Check Logs

```bash
# Via Grafana
# Go to Explore → Select "Loki" → Query: {namespace="rocketchat"}
```

### Check Traces

```bash
# Via Grafana
# Go to Explore → Select "Tempo" → Search traces with: {}
# Or visit: https://grafana.canepro.me/d/rocket-chat-tracing
```

---

## 7. Optional: Enhanced Features

### Deploy Auto-scaling

```bash
kubectl apply -f aks/monitoring/autoscaling-config.yaml
```

### Deploy High Availability

```bash
kubectl apply -f aks/monitoring/high-availability-config.yaml
```

### Deploy Cost Monitoring

```bash
kubectl apply -f aks/monitoring/azure-cost-monitoring.yaml
```

---

## Troubleshooting

### Pods Not Starting

```bash
kubectl get pods -n rocketchat
kubectl describe pod <pod-name> -n rocketchat
kubectl logs <pod-name> -n rocketchat
```

### Metrics Not Showing

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n rocketchat

# Check Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

### Logs Not Appearing

```bash
# Check Loki
kubectl get pods -n loki-stack

# Check Promtail
kubectl logs -n loki-stack -l app=promtail
```

### Traces Not Showing

```bash
# Check OpenTelemetry Collector
kubectl logs -n monitoring -l app=otel-collector --tail=50

# Check Tempo
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo --tail=50

# Check Rocket.Chat instrumentation
kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat | grep OpenTelemetry
```

---

## Documentation Links

- **[Main README](README.md)** - Overview and features
- **[Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md)** - Comprehensive issue resolution
- **[Monitoring Setup](docs/MONITORING_SETUP_GUIDE.md)** - Detailed monitoring configuration
- **[Distributed Tracing Guide](aks/docs/DISTRIBUTED_TRACING_GUIDE.md)** - Complete tracing setup
- **[Tracing Investigation](aks/docs/TRACING_INVESTIGATION_SUMMARY.md)** - Tracing fixes and resolution
- **[Cost Optimization](docs/COST_OPTIMIZATION_GUIDE.md)** - Resource optimization strategies
- **[AKS Setup](aks/docs/AKS_SETUP_GUIDE.md)** - Azure Kubernetes Service setup

---

## Next Steps

1. **Configure DNS**: Point your domain to the ingress IP
2. **Set up alerts**: Configure email/Slack notifications
3. **Enable backups**: Set up automated backup jobs
4. **Review costs**: Monitor Azure spending
5. **Scale as needed**: Adjust replicas and resources

---

## Support

For issues:
1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md)
2. Review Grafana dashboards for system health
3. Check logs in Loki
4. Review traces in Tempo

---

**🎉 Deployment Complete!**

Your Rocket.Chat instance is now running with:
- ✅ Complete observability (Metrics + Logs + Traces)
- ✅ Automated alerting
- ✅ Production-ready monitoring
- ✅ Cost optimization
- ✅ High availability

Access your services:
- 💬 **Chat**: https://chat.canepro.me
- 📊 **Monitoring**: https://grafana.canepro.me
- 🔍 **Traces**: https://grafana.canepro.me/d/rocket-chat-tracing

