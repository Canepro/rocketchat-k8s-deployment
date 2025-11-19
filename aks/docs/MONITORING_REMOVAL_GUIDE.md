# 🗑️ Monitoring Stack Removal Guide

This guide explains how to remove the monitoring stack (Grafana, Prometheus, Loki, Tempo) from the AKS cluster to reduce costs, while keeping monitoring available on the OKE cluster.

## 📋 Overview

The monitoring stack in AKS includes:
- **Grafana** (grafana.canepro.me) - Visualization dashboards
- **Prometheus** - Metrics collection
- **Alertmanager** - Alert management
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **OpenTelemetry Collector** - Trace collection

## ⚠️ Prerequisites

1. **Switch to AKS cluster context:**
   ```bash
   kubectl config use-context aks-uksouth
   ```

2. **Verify you're on the correct cluster:**
   ```bash
   kubectl config current-context
   # Should show: aks-uksouth
   ```

3. **Ensure OKE cluster has monitoring set up** (you mentioned you want to use OKE for Grafana)

## 🚀 Quick Removal

### Automated Removal Script

```bash
cd aks/scripts
./remove-monitoring-stack.sh
```

The script will:
1. ✅ Verify you're on the AKS cluster
2. ✅ List current monitoring resources
3. ✅ Remove Grafana ingress (disconnect grafana.canepro.me)
4. ✅ Uninstall Helm releases (monitoring, loki-stack, tempo)
5. ✅ Remove OpenTelemetry Collector
6. ✅ Clean up ServiceMonitors, PrometheusRules, ConfigMaps
7. ✅ Optionally remove PersistentVolumeClaims (data deletion)
8. ✅ Optionally remove monitoring namespace

### Manual Removal Steps

If you prefer manual control:

#### 1. Remove Grafana Ingress
```bash
kubectl delete ingress grafana-new-domain -n monitoring
```

#### 2. Uninstall Helm Releases
```bash
# Check what's installed
helm list -n monitoring

# Uninstall monitoring stack
helm uninstall monitoring -n monitoring

# Uninstall Loki (if exists)
helm uninstall loki-stack -n monitoring

# Uninstall Tempo (if exists)
helm uninstall tempo -n monitoring
```

#### 3. Remove OpenTelemetry Collector
```bash
kubectl delete deployment otel-collector -n monitoring
```

#### 4. Remove Additional Resources
```bash
# ServiceMonitors
kubectl delete servicemonitor -n monitoring --all
kubectl delete servicemonitor -n rocketchat --all

# PrometheusRules
kubectl delete prometheusrule -n monitoring --all

# Services
kubectl delete svc -n monitoring -l app.kubernetes.io/part-of=kube-prometheus-stack
```

#### 5. Remove PersistentVolumeClaims (Optional - Deletes Data)
```bash
# List PVCs first
kubectl get pvc -n monitoring

# Delete all PVCs (PERMANENT - deletes monitoring data)
kubectl delete pvc -n monitoring --all
```

#### 6. Remove Namespace (Optional)
```bash
# Only if namespace is empty
kubectl delete namespace monitoring
```

## ✅ Verification

After removal, verify:

```bash
# Check pods
kubectl get pods -n monitoring

# Check Helm releases
helm list -n monitoring

# Check ingress
kubectl get ingress -n monitoring

# Check services
kubectl get svc -n monitoring
```

All should be empty or show "No resources found".

## 🔄 What Gets Removed

### Removed Components:
- ✅ Grafana deployment and service
- ✅ Prometheus deployment and service
- ✅ Alertmanager deployment and service
- ✅ Loki deployment and service
- ✅ Tempo deployment and service
- ✅ OpenTelemetry Collector
- ✅ Grafana ingress (grafana.canepro.me)
- ✅ All ServiceMonitors
- ✅ All PrometheusRules
- ✅ Monitoring ConfigMaps and Secrets

### Preserved Components:
- ✅ Rocket.Chat application (unchanged)
- ✅ MongoDB (unchanged)
- ✅ NGINX Ingress Controller (unchanged)
- ✅ cert-manager (unchanged)

## 💰 Cost Impact

Removing the monitoring stack will reduce:
- **Compute costs**: ~3-5 pods removed (Grafana, Prometheus, Alertmanager, Loki, Tempo, OTEL)
- **Storage costs**: PVCs for Grafana, Prometheus, Loki, Tempo (if deleted)
- **Network costs**: Reduced ingress traffic

**Estimated savings**: 20-30% of cluster costs (depending on resource allocation)

## 📝 Post-Removal Steps

1. **Update DNS** (if needed):
   - Point `grafana.canepro.me` to OKE cluster ingress IP
   - Or use a different domain for OKE Grafana

2. **Switch to OKE cluster**:
   ```bash
   kubectl config use-context <oke-context>
   ```

3. **Verify OKE monitoring**:
   - Access Grafana on OKE cluster
   - Verify dashboards and data sources

4. **Monitor cost reduction**:
   - Check Azure portal for cost changes
   - Verify AKS node resource usage decreased

## 🛟 Rollback

If you need to restore monitoring on AKS:

```bash
cd aks/deployment
./deploy-aks-official.sh
```

Or manually:
```bash
helm install monitoring -f ../config/helm-values/values-monitoring.yaml \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

## ⚠️ Important Notes

1. **Data Loss**: If you delete PVCs, all historical monitoring data (metrics, logs, traces) will be permanently lost
2. **Rocket.Chat**: The Rocket.Chat application will continue to work normally
3. **No Monitoring**: After removal, you won't have monitoring for Rocket.Chat in AKS (use OKE instead)
4. **Backup**: Consider backing up important Grafana dashboards before removal

## 🔍 Troubleshooting

### Script fails with "context not found"
```bash
# Switch to AKS context first
kubectl config use-context aks-uksouth
```

### Helm release not found
- This is normal if the release was already removed
- The script will continue with other resources

### Namespace stuck in "Terminating"
```bash
# Force delete (use with caution)
kubectl delete namespace monitoring --force --grace-period=0
```

### PVCs won't delete
- Ensure pods using the PVCs are deleted first
- Check for finalizers: `kubectl get pvc -n monitoring -o yaml`

## 📚 Related Documentation

- [AKS Setup Guide](AKS_SETUP_GUIDE.md)
- [Monitoring Setup Guide](../../docs/MONITORING_SETUP_GUIDE.md)
- [Cost Optimization Guide](../../docs/COST_OPTIMIZATION_GUIDE.md)

---

**Last Updated**: 2025-01-XX

