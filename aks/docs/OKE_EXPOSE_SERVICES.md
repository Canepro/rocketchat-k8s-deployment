# 🔓 Exposing OKE Services for External Access

Your OKE services are currently ClusterIP (internal only). You need to expose them for your AKS cluster to access them.

## 📋 Current Service Status

From your OKE cluster:
- **Prometheus**: `prometheus-prometheus` (ClusterIP: 10.96.250.87, Port: 9090)
- **Loki Gateway**: `loki-gateway` (ClusterIP: 10.96.215.211, Port: 80)
- **Tempo**: `tempo` (ClusterIP: 10.96.61.183, Port: 4317)

## 🚀 Option 1: Expose via LoadBalancer (Recommended for Production)

This creates external IPs that your AKS cluster can access.

### Expose Prometheus

```bash
# On OKE cluster
kubectl patch svc prometheus-prometheus -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP
kubectl get svc prometheus-prometheus -n monitoring -w

# Get the external IP
kubectl get svc prometheus-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Expose Loki Gateway

```bash
# On OKE cluster
kubectl patch svc loki-gateway -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP
kubectl get svc loki-gateway -n monitoring -w

# Get the external IP
kubectl get svc loki-gateway -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Expose Tempo

```bash
# On OKE cluster
kubectl patch svc tempo -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP
kubectl get svc tempo -n monitoring -w

# Get the external IP
kubectl get svc tempo -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔒 Option 2: Expose via NodePort (Alternative)

If LoadBalancer is not available, use NodePort:

```bash
# Expose Prometheus
kubectl patch svc prometheus-prometheus -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'

# Get NodePort
kubectl get svc prometheus-prometheus -n monitoring

# Get a node IP
kubectl get nodes -o wide

# Access via: <NODE_IP>:<NODE_PORT>
```

## 🌐 Option 3: Use Ingress with Authentication (Most Secure)

Create Ingress resources with authentication:

```bash
# Create Prometheus Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-external
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: prometheus-basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Prometheus Authentication Required'
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus-oke.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-prometheus
            port:
              number: 9090
EOF

# Create basic auth secret
kubectl create secret generic prometheus-basic-auth \
  --from-literal=auth=$(echo -n 'admin:password' | base64) \
  -n monitoring
```

## 🔗 Option 4: Use Internal IPs (If Networks Are Connected)

If your AKS and OKE clusters are on connected networks (VPN, peering, etc.), you can use the internal ClusterIPs directly.

**Note**: This requires network connectivity between clusters.

Update your configuration files with:
- Prometheus: `10.96.250.87:9090`
- Loki Gateway: `10.96.215.211:80`
- Tempo: `10.96.61.183:4317`

## ✅ Verification

After exposing services, verify accessibility:

```bash
# Test Prometheus (replace with your external IP)
curl http://<EXTERNAL_IP>:9090/api/v1/query?query=up

# Test Loki Gateway
curl -H "X-Scope-OrgID: 1" http://<EXTERNAL_IP>:3100/ready

# Test Tempo (gRPC - may need special client)
# Or test HTTP endpoint if available
curl http://<EXTERNAL_IP>:4318
```

## 🔐 Security Recommendations

1. **Use Authentication**: Always enable basic auth or bearer tokens
2. **Use TLS**: Configure HTTPS/TLS for production
3. **Restrict Access**: Use firewall rules to limit access to your AKS cluster IPs only
4. **Monitor Access**: Set up logging and monitoring for external access

## 📝 Next Steps

After exposing services:

1. **Get External IPs**:
   ```bash
   kubectl get svc -n monitoring prometheus-prometheus loki-gateway tempo
   ```

2. **Update Configuration Files**:
   - Replace `<OKE_PROMETHEUS_IP>` in `prometheus-oke-remote-write.yaml`
   - Replace `<OKE_LOKI_GATEWAY_IP>` in `promtail-oke-forward.yaml`
   - Replace `<OKE_TEMPO_IP>` in `otel-collector-oke-forward.yaml`

3. **Apply Configurations**:
   ```bash
   ./aks/scripts/setup-oke-forwarding.sh <PROMETHEUS_IP> <LOKI_IP> <TEMPO_IP>
   ```

