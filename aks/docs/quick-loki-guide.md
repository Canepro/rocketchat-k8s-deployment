# 🚀 Quick Loki Log Access Guide

## 1️⃣ **Getting Started (Copy & Paste These)**

### All Rocket.Chat Logs:
```
{namespace="rocketchat"}
```

### Only Error Logs:
```
{namespace="rocketchat"} |= "error"
```

### Logs from Last Hour:
```
{namespace="rocketchat"} [1h]
```

### Specific Component Logs:
```
{pod=~"rocketchat-rocketchat.*"}
```

## 2️⃣ **What You'll See**
- Real-time logs from all Rocket.Chat components
- WebSocket connection logs (ddp-streamer)
- API request logs
- Database interaction logs
- Error messages and debugging info

## 3️⃣ **Tips**
- Use the time picker (top right) to set time range
- Click "Live" for real-time log streaming
- Click on log lines to expand details
- Use | (pipe) to filter: `{namespace="rocketchat"} |= "login"`

## 4️⃣ Configure Promtail with Kubernetes Pod Discovery

Promtail now uses Kubernetes service discovery to follow pod logs. Key config (already applied in `aks/monitoring/loki-values.yaml`):

```yaml
promtail:
  enabled: true
  config:
    kubernetes_sd_configs:
      - role: pod
    pipeline_stages:
      - cri: {}
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - action: replace
        source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - action: replace
        source_labels: [__meta_kubernetes_pod_container_name]
        target_label: container
```

Validation:

```bash
# Check Promtail pods
kubectl get pods -n monitoring | grep promtail

# Check Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50 | cat

# Verify Loki is receiving logs
kubectl exec -n monitoring loki-0 -- wget -qO- 'http://localhost:3100/loki/api/v1/labels' | head -20
```