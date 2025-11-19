# 🎯 Forwarding Metrics, Logs, and Traces to OKE Central Hub

This guide explains how to configure your current AKS cluster to forward metrics, logs, and traces to your OKE (Oracle Kubernetes Engine) central monitoring hub.

## 📋 Prerequisites

Before starting, ensure you have:

1. **OKE Services Exposed**: Your OKE services need to be accessible from AKS:
   - **Prometheus**: `prometheus-prometheus` service (port 9090)
   - **Loki Gateway**: `loki-gateway` service (port 80/3100)
   - **Tempo**: `tempo` service (port 4317 for gRPC)

   **Important**: These services are ClusterIP by default. You need to expose them first!
   - See `aks/docs/OKE_EXPOSE_SERVICES.md` for instructions
   - Or run: `./aks/scripts/expose-oke-services.sh loadbalancer` on OKE cluster

2. **Network Connectivity**: Ensure your AKS cluster can reach the OKE cluster endpoints (firewall rules, VPN, etc.)

3. **Authentication Credentials** (if required):
   - Prometheus basic auth or bearer token
   - Loki X-Scope-OrgID (default: 1)
   - Tempo authentication (if enabled)

## 🔧 Configuration Steps

### Step 1: Configure Prometheus Remote Write

Prometheus will forward all collected metrics to the OKE central Prometheus.

#### Option A: Using Helm Values (Recommended)

1. **Update the remote write configuration**:

   Edit `aks/config/helm-values/prometheus-oke-remote-write.yaml`:
   ```yaml
   prometheus:
     prometheusSpec:
       remoteWrite:
         - url: "http://<OKE_PROMETHEUS_IP>:9090/api/v1/write"
           # Add authentication if required
           # basicAuth:
           #   username: <username>
           #   password: <password>
   ```

2. **Apply the configuration**:
   ```bash
   helm upgrade monitoring prometheus-community/kube-prometheus-stack \
     -f aks/config/helm-values/values-monitoring.yaml \
     -f aks/config/helm-values/prometheus-oke-remote-write.yaml \
     -n monitoring
   ```

#### Option B: Using PrometheusRemoteWrite CRD

1. **Create authentication secret** (if required):
   ```bash
   kubectl create secret generic prometheus-oke-remote-write \
     --from-literal=username=<username> \
     --from-literal=password=<password> \
     -n monitoring
   ```

2. **Apply the remote write configuration**:
   ```bash
   # Edit aks/monitoring/oke-remote-write-config.yaml with your OKE endpoint
   kubectl apply -f aks/monitoring/oke-remote-write-config.yaml
   ```

#### Verification

```bash
# Check Prometheus remote write status
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/config and verify remote_write section

# Check Prometheus targets
# Navigate to Status → Targets in Prometheus UI
# Look for remote write queue metrics
```

### Step 2: Configure Promtail to Forward Logs

Promtail will forward all collected logs to the OKE Loki gateway.

1. **Get OKE Loki Gateway IP**:
   ```bash
   # On OKE cluster, get the external IP (after exposing via LoadBalancer)
   kubectl get svc loki-gateway -n monitoring
   
   # Or get the external IP directly:
   kubectl get svc loki-gateway -n monitoring \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. **Update Promtail configuration**:

   Edit `aks/monitoring/promtail-oke-forward.yaml`:
   ```yaml
   clients:
     - url: http://<OKE_LOKI_GATEWAY_IP>:3100/loki/api/v1/push
       headers:
         X-Scope-OrgID: "1"  # Update if using different tenant
   ```

3. **Merge with existing Loki values**:

   Create a combined configuration or update your existing `loki-values.yaml`:
   ```bash
   # Option 1: Update existing loki-values.yaml with the clients section from promtail-oke-forward.yaml
   # Option 2: Use Helm values merge
   helm upgrade loki grafana/loki-stack \
     -f aks/monitoring/loki-values.yaml \
     -f aks/monitoring/promtail-oke-forward.yaml \
     -n monitoring
   ```

   Or manually merge the `clients` section in `aks/monitoring/loki-values.yaml`:
   ```yaml
   promtail:
     config:
       clients:
         # Local Loki
         - url: http://loki-stack.loki-stack.svc.cluster.local:3100/loki/api/v1/push
         # OKE Loki Gateway
         - url: http://<OKE_LOKI_GATEWAY_IP>:3100/loki/api/v1/push
           headers:
             X-Scope-OrgID: "1"
   ```

4. **Apply the configuration**:
   ```bash
   helm upgrade loki grafana/loki-stack \
     -f aks/monitoring/loki-values.yaml \
     -n monitoring
   ```

#### Verification

```bash
# Check Promtail pods
kubectl get pods -n monitoring | grep promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=50

# Verify logs in OKE Grafana
# Navigate to Grafana → Explore → Loki
# Query: {cluster="rocket-chat-aks"}
```

### Step 3: Configure OTEL Collector to Forward Traces

The OpenTelemetry Collector will forward all traces to the OKE Tempo instance.

1. **Get OKE Tempo IP**:
   ```bash
   # On OKE cluster, get the external IP (after exposing via LoadBalancer)
   kubectl get svc tempo -n monitoring
   
   # Or get the external IP directly:
   kubectl get svc tempo -n monitoring \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. **Update OTEL Collector configuration**:

   Edit `aks/monitoring/otel-collector-oke-forward.yaml`:
   ```yaml
   exporters:
     otlp/oke:
       endpoint: <OKE_TEMPO_IP>:4317  # Update with OKE Tempo endpoint
   ```

3. **Apply the configuration**:
   ```bash
   kubectl apply -f aks/monitoring/otel-collector-oke-forward.yaml
   
   # Restart OTEL Collector to pick up changes
   kubectl rollout restart deployment/otel-collector -n monitoring
   kubectl rollout status deployment/otel-collector -n monitoring
   ```

#### Verification

```bash
# Check OTEL Collector pods
kubectl get pods -n monitoring | grep otel-collector

# Check OTEL Collector logs
kubectl logs -n monitoring -l app=otel-collector --tail=50

# Verify traces in OKE Grafana
# Navigate to Grafana → Explore → Tempo
# Search for service: rocket-chat
```

## 🔍 Verification and Testing

### 1. Verify Metrics Forwarding

```bash
# Port-forward to OKE Prometheus (if accessible)
kubectl port-forward -n monitoring svc/prometheus-prometheus-prometheus 9090:9090

# Query for cluster-specific metrics
curl "http://localhost:9090/api/v1/query?query=up{cluster=\"rocket-chat-aks\"}"
```

### 2. Verify Logs Forwarding

In OKE Grafana:
1. Navigate to **Explore** → Select **Loki** datasource
2. Run query: `{cluster="rocket-chat-aks"}`
3. You should see logs from your AKS cluster

### 3. Verify Traces Forwarding

In OKE Grafana:
1. Navigate to **Explore** → Select **Tempo** datasource
2. Search for service: `rocket-chat`
3. Filter by cluster: `cluster="rocket-chat-aks"`
4. You should see traces from your AKS cluster

## 📊 Label Configuration

All forwarded data includes cluster identification labels:

- **Metrics**: `cluster=rocket-chat-aks`, `environment=production`, `region=azure`
- **Logs**: `cluster=rocket-chat-aks`, `environment=production`, `region=azure`
- **Traces**: `cluster=rocket-chat-aks`, `region=azure`

You can customize these labels in the respective configuration files.

## 🔐 Security Considerations

### Authentication

1. **Prometheus Remote Write**:
   - Use basic auth or bearer tokens
   - Consider using TLS/HTTPS if supported
   - Store credentials in Kubernetes secrets

2. **Loki**:
   - Use X-Scope-OrgID for multi-tenancy
   - Consider basic auth if enabled in OKE Loki
   - Use TLS for production

3. **Tempo**:
   - Configure TLS if OKE Tempo uses TLS
   - Use bearer tokens if authentication is enabled

### Network Security

- Ensure firewall rules allow traffic from AKS to OKE
- Use VPN or private networking if available
- Consider using Ingress with authentication for public endpoints

## 🐛 Troubleshooting

### Metrics Not Appearing in OKE

1. **Check Prometheus remote write status**:
   ```bash
   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
   # Navigate to Status → Runtime & Build Information → Remote Write
   ```

2. **Check remote write queue**:
   ```bash
   # Query: prometheus_remote_storage_queue_length
   ```

3. **Check network connectivity**:
   ```bash
   # From AKS cluster, test connectivity
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v http://<OKE_PROMETHEUS_IP>:9090/api/v1/write
   ```

### Logs Not Appearing in OKE

1. **Check Promtail logs**:
   ```bash
   kubectl logs -n monitoring -l app=promtail --tail=100 | grep -i error
   ```

2. **Verify Loki gateway connectivity**:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v -H "X-Scope-OrgID: 1" http://<OKE_LOKI_GATEWAY_IP>:3100/ready
   ```

3. **Check Promtail client configuration**:
   ```bash
   kubectl get configmap -n monitoring -o yaml | grep -A 20 clients
   ```

### Traces Not Appearing in OKE

1. **Check OTEL Collector logs**:
   ```bash
   kubectl logs -n monitoring -l app=otel-collector --tail=100 | grep -i error
   ```

2. **Verify Tempo connectivity**:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v http://<OKE_TEMPO_IP>:4317
   ```

3. **Check OTEL Collector configuration**:
   ```bash
   kubectl get configmap otel-collector-config -n monitoring -o yaml
   ```

## 📝 Configuration Files Summary

| File | Purpose | Location |
|------|---------|----------|
| `prometheus-oke-remote-write.yaml` | Prometheus remote write config | `aks/config/helm-values/` |
| `oke-remote-write-config.yaml` | PrometheusRemoteWrite CRD | `aks/monitoring/` |
| `promtail-oke-forward.yaml` | Promtail dual-forwarding config | `aks/monitoring/` |
| `otel-collector-oke-forward.yaml` | OTEL Collector dual-forwarding config | `aks/monitoring/` |

## 🚀 Quick Start Commands

```bash
# 1. Configure Prometheus remote write
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/values-monitoring.yaml \
  -f aks/config/helm-values/prometheus-oke-remote-write.yaml \
  -n monitoring

# 2. Configure Promtail (update loki-values.yaml first)
helm upgrade loki grafana/loki-stack \
  -f aks/monitoring/loki-values.yaml \
  -n monitoring

# 3. Configure OTEL Collector
kubectl apply -f aks/monitoring/otel-collector-oke-forward.yaml
kubectl rollout restart deployment/otel-collector -n monitoring

# 4. Verify all components
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=promtail --tail=20
kubectl logs -n monitoring -l app=otel-collector --tail=20
```

## 📚 Additional Resources

- [Prometheus Remote Write Documentation](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [Loki Multi-Tenancy Guide](https://grafana.com/docs/loki/latest/operations/multi-tenancy/)
- [OpenTelemetry Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)

## ⚠️ Important Notes

1. **Dual Forwarding**: The configurations maintain local storage/access while forwarding to OKE. This allows you to:
   - Keep local dashboards and queries
   - Have redundancy in case of network issues
   - Gradually migrate to OKE

2. **Resource Usage**: Forwarding adds minimal overhead, but monitor:
   - Network bandwidth usage
   - Prometheus/Promtail/OTEL Collector resource consumption

3. **Retention**: Local retention is still configured (7 days for Prometheus). Adjust based on your needs.

4. **Labels**: Ensure consistent label naming across clusters for effective filtering in the central hub.

