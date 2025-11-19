# OKE Central Hub Forwarding - Current Status

**Last Updated:** November 19, 2025

## Summary

AKS cluster is successfully forwarding **all observability data** (metrics, logs, traces) to OKE central monitoring hub at `https://observability.canepro.me`. All three telemetry pipelines are operational and verified.

---

## ✅ Components Status

### 1. Metrics (Prometheus Remote Write)
**Status:** ✅ **WORKING**

- **AKS Prometheus** → **OKE Prometheus**
- **Endpoint:** `https://observability.canepro.me/prometheus/api/v1/write`
- **Authentication:** Basic Auth (stored in Secret `oke-observability-auth`)
- **Configuration:** `aks/config/helm-values/prometheus-oke-remote-write.yaml`
- **Verification:** Metrics visible in OKE Grafana

### 2. Logs (Promtail → Loki)
**Status:** ✅ **WORKING**

- **AKS Promtail** → **OKE Loki**
- **Endpoint:** `https://observability.canepro.me/loki/loki/api/v1/push`
- **Authentication:** Basic Auth + `X-Scope-OrgID: "1"` header
- **Configuration:** `aks/monitoring/loki-values.yaml`
- **Verification:** Logs visible in OKE Grafana Loki datasource
- **Note:** `cluster` label not applied (Helm chart limitation), but logs are flowing successfully. Filter by `pod`, `namespace`, `container` labels instead.

### 3. Traces (OTEL Collector → Tempo)
**Status:** ✅ **WORKING**

- **AKS OTEL Collector** → **OKE Tempo**
- **Endpoint:** `https://observability.canepro.me/tempo/v1/traces`
- **Protocol:** OTLP/HTTP
- **Authentication:** Basic Auth
- **Configuration:** `aks/monitoring/otel-collector-oke-forward.yaml`
- **Verification:** Traces successfully ingested via OTLP HTTP endpoint
- **Note:** Ingress configured to route to port 4318 (OTLP HTTP receiver). Grafana datasource uses port 3200 (Tempo query API)

---

## 🔑 Credentials

**Username:** `observability-user`  
**Password:** `50JjX+diU6YmAZPl`

Stored in AKS Secret: `oke-observability-auth` (namespace: `monitoring`)

---

## 📁 Key Configuration Files

### AKS Cluster
- `aks/config/helm-values/prometheus-oke-remote-write.yaml` - Prometheus remote write config
- `aks/monitoring/oke-auth-secret.yaml` - Authentication secret
- `aks/monitoring/loki-values.yaml` - Loki/Promtail configuration
- `aks/monitoring/otel-collector-oke-forward.yaml` - OTEL Collector configuration
- `aks/scripts/setup-oke-forwarding.sh` - Setup automation script

### OKE Cluster
- Ingress: `https://observability.canepro.me`
- Namespace: `monitoring`
- Services: `prometheus-prometheus`, `loki-gateway`, `tempo`

---

## 🔍 Verification Commands

### Check Prometheus Remote Write (AKS)
```bash
kubectl config use-context aks-uksouth
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus --tail=20
```

### Check Promtail Logs (AKS)
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=30
```

### Check OTEL Collector Logs (AKS)
```bash
kubectl logs -n monitoring -l app=otel-collector --tail=30
```

### Check Tempo Logs (OKE)
```bash
kubectl config use-context oci-ashburn
kubectl logs -n monitoring tempo-0 --tail=50
```

### Verify in OKE Grafana
1. Navigate to `https://observability.canepro.me`
2. Login with credentials
3. Go to **Explore**
4. **Metrics (Prometheus):** Query for AKS metrics
5. **Logs (Loki):** Query `{pod=~".*"}` or `{namespace="rocketchat"}`
6. **Traces (Tempo):** Check for traces from AKS

---

## 🐛 Known Issues

### Issue 1: Cluster Label Not Applied to Logs
- **Problem:** `{cluster="rocket-chat-aks"}` query doesn't work
- **Cause:** `loki-stack` Helm chart doesn't properly render `pipeline_stages.static_labels`
- **Workaround:** Use other labels like `{namespace="rocketchat"}` or `{pod=~"rocketchat.*"}`
- **Impact:** Low - logs are flowing, just need different query patterns

### Issue 2: Tempo Returns 503 ✅ RESOLVED
- **Problem:** OTEL Collector getting HTTP 503 from OKE Tempo
- **Root Cause:** Ingress was routing to port 3100 (non-existent) instead of port 4318 (OTLP HTTP receiver)
- **Solution:** Updated Ingress to route `/tempo/*` paths to port 4318
- **Status:** Resolved on 2025-11-19
- **Additional Fix:** Grafana datasource corrected to use port 3200 (Tempo query API) instead of 3100

---

## 📝 Notes

- Metrics forwarding confirmed working on 2025-11-19
- Logs forwarding confirmed working on 2025-11-19
- Traces forwarding confirmed working on 2025-11-19 (after Ingress port fix)
- Namespace `monitoring` on AKS had to be recreated due to stuck termination
- Prometheus remote write receiver had to be enabled on OKE: `kubectl patch prometheus prometheus-prometheus -n monitoring --type='merge' -p '{"spec":{"enableRemoteWriteReceiver":true}}'`
- Tempo Ingress port corrected from 3100 to 4318: `kubectl patch ingress observability-services -n monitoring --type='json' -p='[{"op": "replace", "path": "/spec/rules/0/http/paths/2/backend/service/port/number", "value": 4318}]'`
- Tempo port reference: 3200 (query API for Grafana), 4318 (OTLP HTTP ingestion), 4317 (OTLP gRPC ingestion)

