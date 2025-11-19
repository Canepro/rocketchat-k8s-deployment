# 🎯 OKE Central Hub Setup - Summary

Quick summary of what you need to do to forward metrics, logs, and traces to your OKE cluster.

## ✅ Current Status

From your OKE cluster, you found:
- ✅ **Prometheus**: `prometheus-prometheus` (ClusterIP: 10.96.250.87:9090)
- ✅ **Loki Gateway**: `loki-gateway` (ClusterIP: 10.96.215.211:80)
- ✅ **Tempo**: `tempo` (ClusterIP: 10.96.61.183:4317)

**⚠️ Important**: These are ClusterIP services (internal only). You need to expose them first!

## 🚀 Quick Start (3 Steps)

### Step 1: Expose OKE Services

On your **OKE cluster**, expose the services:

```bash
# Option A: Use the script (recommended)
./aks/scripts/expose-oke-services.sh loadbalancer

# Option B: Manual exposure
kubectl patch svc prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc loki-gateway -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc tempo -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IPs (may take 1-2 minutes)
kubectl get svc -n monitoring prometheus-prometheus loki-gateway tempo -w
```

### Step 2: Get External IPs

Once LoadBalancers are provisioned, get the external IPs:

```bash
# On OKE cluster
PROMETHEUS_IP=$(kubectl get svc prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
LOKI_IP=$(kubectl get svc loki-gateway -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TEMPO_IP=$(kubectl get svc tempo -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Prometheus: $PROMETHEUS_IP"
echo "Loki: $LOKI_IP"
echo "Tempo: $TEMPO_IP"
```

### Step 3: Configure AKS Cluster

On your **AKS cluster**, run the setup script:

```bash
# From AKS cluster
cd aks/scripts
./setup-oke-forwarding.sh $PROMETHEUS_IP $LOKI_IP $TEMPO_IP rocket-chat-aks
```

Or configure manually (see `aks/docs/OKE_CENTRAL_HUB_SETUP.md`).

## 📋 What Gets Configured

1. **Prometheus Remote Write**: Forwards all metrics to OKE Prometheus
2. **Promtail Dual Forwarding**: Sends logs to both local Loki and OKE Loki
3. **OTEL Collector Dual Forwarding**: Sends traces to both local Tempo and OKE Tempo

## ✅ Verification

After setup, verify in OKE Grafana:

- **Metrics**: Explore → Prometheus → Query: `up{cluster="rocket-chat-aks"}`
- **Logs**: Explore → Loki → Query: `{cluster="rocket-chat-aks"}`
- **Traces**: Explore → Tempo → Search: `service=rocket-chat, cluster=rocket-chat-aks`

## 📚 Documentation

- **Full Setup Guide**: `aks/docs/OKE_CENTRAL_HUB_SETUP.md`
- **Expose Services Guide**: `aks/docs/OKE_EXPOSE_SERVICES.md`
- **Quick Reference**: `aks/docs/OKE_FORWARDING_QUICK_REFERENCE.md`

## 🔧 Troubleshooting

### Services Show `<pending>` External IP

- Wait 2-5 minutes for LoadBalancer provisioning
- Check OKE cluster has LoadBalancer support
- Verify firewall/security group rules

### Cannot Connect from AKS

- Verify firewall rules allow traffic from AKS to OKE
- Check network connectivity: `curl http://<OKE_IP>:9090`
- Verify LoadBalancer external IPs are correct

### No Data in OKE Grafana

- Check Prometheus remote write status
- Verify Promtail/OTEL Collector logs for errors
- Ensure cluster labels match in queries

## 🎯 Next Steps After Setup

1. **Verify Data Flow**: Check OKE Grafana for incoming data
2. **Configure Dashboards**: Create dashboards filtering by `cluster="rocket-chat-aks"`
3. **Set Up Alerts**: Configure alerts in OKE Prometheus
4. **Monitor Performance**: Watch for network latency or queue buildup

