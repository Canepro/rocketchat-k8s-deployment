# 🚀 OKE Forwarding Quick Reference

Quick reference guide for forwarding metrics, logs, and traces to OKE central hub.

## 📝 Prerequisites

### Step 1: Expose OKE Services (Required First!)

Your OKE services are ClusterIP by default. Expose them first:

```bash
# On OKE cluster, run the expose script
./aks/scripts/expose-oke-services.sh loadbalancer

# Or manually expose each service:
kubectl patch svc prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc loki-gateway -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc tempo -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IPs, then get them:
kubectl get svc -n monitoring prometheus-prometheus loki-gateway tempo
```

### Step 2: Get External IPs

```bash
# On OKE cluster, get external IPs
kubectl get svc -n monitoring prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get svc -n monitoring loki-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get svc -n monitoring tempo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Note**: If services show `<pending>`, wait a few minutes for the LoadBalancer to provision.

## ⚡ Quick Setup (Automated)

```bash
# Run the setup script
cd aks/scripts
./setup-oke-forwarding.sh <OKE_PROMETHEUS_IP> <OKE_LOKI_GATEWAY_IP> <OKE_TEMPO_IP> [CLUSTER_NAME]

# Example:
./setup-oke-forwarding.sh 10.0.1.100 10.0.1.101 10.0.1.102 rocket-chat-aks
```

## 🔧 Manual Setup

### 1. Prometheus Remote Write

```bash
# Edit: aks/config/helm-values/prometheus-oke-remote-write.yaml
# Replace <OKE_PROMETHEUS_IP> with your OKE Prometheus IP

# Apply:
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/values-monitoring.yaml \
  -f aks/config/helm-values/prometheus-oke-remote-write.yaml \
  -n monitoring
```

### 2. Promtail Log Forwarding

```bash
# Edit: aks/monitoring/loki-values.yaml
# Add OKE Loki gateway to clients section:
clients:
  - url: http://loki-stack.loki-stack.svc.cluster.local:3100/loki/api/v1/push
  - url: http://<OKE_LOKI_GATEWAY_IP>:3100/loki/api/v1/push
    headers:
      X-Scope-OrgID: "1"

# Apply:
helm upgrade loki grafana/loki-stack \
  -f aks/monitoring/loki-values.yaml \
  -n monitoring
```

### 3. OTEL Collector Trace Forwarding

```bash
# Edit: aks/monitoring/otel-collector-oke-forward.yaml
# Replace <OKE_TEMPO_IP> with your OKE Tempo IP

# Apply:
kubectl apply -f aks/monitoring/otel-collector-oke-forward.yaml
kubectl rollout restart deployment/otel-collector -n monitoring
```

## ✅ Verification

### Check Metrics Forwarding

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# In browser: http://localhost:9090/config
# Look for remote_write section

# Query remote write queue
curl "http://localhost:9090/api/v1/query?query=prometheus_remote_storage_queue_length"
```

### Check Logs Forwarding

```bash
# Check Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=50 | grep -i error

# In OKE Grafana: Explore → Loki
# Query: {cluster="rocket-chat-aks"}
```

### Check Traces Forwarding

```bash
# Check OTEL Collector logs
kubectl logs -n monitoring -l app=otel-collector --tail=50 | grep -i error

# In OKE Grafana: Explore → Tempo
# Search: service=rocket-chat, cluster=rocket-chat-aks
```

## 🔍 Troubleshooting

### Metrics Not Forwarding

```bash
# Check Prometheus remote write status
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Navigate to: Status → Runtime & Build Information → Remote Write

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://<OKE_PROMETHEUS_IP>:9090/api/v1/write
```

### Logs Not Forwarding

```bash
# Check Promtail configuration
kubectl get configmap -n monitoring -o yaml | grep -A 20 clients

# Test Loki gateway connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v -H "X-Scope-OrgID: 1" http://<OKE_LOKI_GATEWAY_IP>:3100/ready
```

### Traces Not Forwarding

```bash
# Check OTEL Collector config
kubectl get configmap otel-collector-config -n monitoring -o yaml

# Test Tempo connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://<OKE_TEMPO_IP>:4317
```

## 📊 Label Reference

All forwarded data includes these labels:

- `cluster`: Your cluster identifier (default: `rocket-chat-aks`)
- `environment`: Environment name (default: `production`)
- `region`: Region identifier (default: `azure`)

Use these labels in OKE Grafana to filter data:

- **Metrics**: `up{cluster="rocket-chat-aks"}`
- **Logs**: `{cluster="rocket-chat-aks"}`
- **Traces**: Filter by `cluster="rocket-chat-aks"` in Tempo search

## 📁 Configuration Files

| File | Purpose |
|------|---------|
| `aks/config/helm-values/prometheus-oke-remote-write.yaml` | Prometheus remote write |
| `aks/monitoring/promtail-oke-forward.yaml` | Promtail dual forwarding |
| `aks/monitoring/otel-collector-oke-forward.yaml` | OTEL Collector dual forwarding |
| `aks/monitoring/loki-values.yaml` | Loki/Promtail main config (update manually) |

## 🔐 Security Notes

- **Authentication**: Update configuration files with credentials if OKE requires auth
- **TLS**: Enable TLS in configurations if OKE uses HTTPS
- **Network**: Ensure firewall rules allow traffic from AKS to OKE

## 📚 Full Documentation

See `aks/docs/OKE_CENTRAL_HUB_SETUP.md` for detailed setup instructions.

