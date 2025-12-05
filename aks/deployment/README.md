# 🚀 Deployment Guide

## Prerequisites

Ensure you have:
- Azure CLI installed and configured
- kubectl configured for your AKS cluster
- Helm 3.x installed

## Quick Deployment

### 1. One-Command Deployment

```bash
cd deployment
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

This script will:
- Add Rocket.Chat Helm repository
- Install NGINX Ingress Controller
- Install cert-manager for SSL certificates
- Deploy monitoring stack (Prometheus, Grafana, Loki)
- Deploy Rocket.Chat with MongoDB

### 2. Manual Step-by-Step Deployment

If you prefer manual control:

```bash
# Add Helm repositories
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo update

# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml

# Apply SSL configuration
kubectl apply -f ../config/certificates/clusterissuer.yaml

# Create required secrets (examples)
kubectl -n monitoring apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
type: Opaque
stringData:
  GF_SECURITY_ADMIN_USER: admin
  GF_SECURITY_ADMIN_PASSWORD: "changeMeStrong!"
EOF

# Deploy monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring -f ../config/helm-values/values-monitoring.yaml prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout=10m

# Deploy Rocket.Chat (ServiceMonitor/Grafana/Prometheus disabled in values)
helm install rocketchat -f ../config/helm-values/values-official.yaml rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --wait \
  --timeout=15m

## Optional: Secure Overlay (use after creating MongoDB secret)

```bash
# Example Secret (create beforehand)
kubectl -n rocketchat apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: rocketchat-mongodb-auth
  namespace: rocketchat
type: Opaque
stringData:
  mongo-url: "mongodb://rocketchat:SuperStrongPass!@mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017,mongodb-1.mongodb-headless.rocketchat.svc.cluster.local:27017,mongodb-2.mongodb-headless.rocketchat.svc.cluster.local:27017/rocketchat?replicaSet=rs0&readPreference=primaryPreferred"
  mongo-oplog-url: "mongodb://rocketchat:SuperStrongPass!@mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017/local?replicaSet=rs0&readPreference=primaryPreferred"
EOF

# Apply overlay values that reference the secret
helm upgrade --install rocketchat rocketchat/rocketchat \
  -n rocketchat \
  -f ../config/helm-values/values-production.yaml \
  --wait --timeout=15m
```
```

## Configuration Files

All configuration files are located in the `config/` directory:

- **`config/helm-values/values-official.yaml`** - Main Rocket.Chat configuration
- **`config/helm-values/values-monitoring.yaml`** - Monitoring stack configuration
- **`config/certificates/clusterissuer.yaml`** - SSL certificate issuer
- **`config/mongodb-standalone.yaml`** - Standalone MongoDB deployment (for Bitnami brownout periods)

### ⚠️ Bitnami Image Brownout Notice

**During Bitnami brownout periods (e.g., Sept 17-19, 2025)**, MongoDB images may be unavailable. If you encounter `ImagePullBackOff` errors:

1. Use standalone MongoDB deployment:
   ```bash
   kubectl apply -f ../config/mongodb-standalone.yaml
   ```

2. Update values to disable Bitnami MongoDB and use external MongoDB (see `values-official.yaml`)

3. Run the brownout workaround script:
   ```bash
   ./deploy-mongodb-standalone.sh
   ```

See [Troubleshooting Guide](../docs/TROUBLESHOOTING_GUIDE.md#issue-bitnami-mongodb-brownout---images-unavailable-september-17-19-2025) for detailed resolution steps.

## Monitoring Configuration

The monitoring stack includes:

- **Prometheus** - Metrics collection
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation
- **Alertmanager** - Alert management

### Accessing Monitoring

After deployment:
- **Grafana**: `https://grafana.<YOUR_DOMAIN>`
- **Prometheus**: `kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring`

### Grafana Credentials

- Stored in Secret `grafana-admin` and consumed via `envFromSecret`.
- Default example: admin / changeMeStrong! (change for production)

## Post-Deployment Steps

### 1. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n rocketchat
kubectl get pods -n monitoring

# Check ingress configuration
kubectl get ingress -n rocketchat
kubectl get ingress -n monitoring

# Get external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### 2. SSL Certificate Status

```bash
# Check certificate status
kubectl get certificates -n rocketchat
kubectl get certificates -n monitoring

# Check certificate issuer
kubectl get clusterissuer

### 4. Prometheus Discovery Verification
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 &
# Open http://localhost:9090 → Status → Targets → Ensure PodMonitor targets show for `rocketchat` namespace
```

### 3. DNS Configuration

Update your DNS records to point to the AKS ingress IP:
- `<YOUR_DOMAIN>` → AKS Ingress IP
- `grafana.<YOUR_DOMAIN>` → AKS Ingress IP

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and node capacity
2. **SSL certificates not issuing**: Verify DNS points to correct IP
3. **Services not accessible**: Check ingress configuration and firewall rules

### Useful Commands

```bash
# Check pod logs
kubectl logs -n rocketchat deployment/rocketchat

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check certificate manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Restart deployment
kubectl rollout restart deployment/rocketchat -n rocketchat
```

## Scaling and Updates

### Scaling Rocket.Chat

```bash
# Scale to 3 replicas
kubectl scale deployment rocketchat -n rocketchat --replicas=3

# Check scaling status
kubectl get pods -n rocketchat
```

### Updating Rocket.Chat

```bash
# Update to latest version
helm upgrade rocketchat -f ../config/helm-values/values-official.yaml rocketchat/rocketchat -n rocketchat

# Check update status
kubectl rollout status deployment/rocketchat -n rocketchat
```

## Backup and Recovery

### MongoDB Backup

```bash
# Create MongoDB backup
kubectl exec -n rocketchat deployment/rocketchat-mongodb -- mongodump --out /tmp/backup

# Copy backup from pod
kubectl cp rocketchat/rocketchat-mongodb-0:/tmp/backup ./mongodb-backup-$(date +%Y%m%d_%H%M%S)
```

### Configuration Backup

```bash
# Backup Helm values
cp -r config/ backup-config-$(date +%Y%m%d_%H%M%S)/

# Backup monitoring configuration
kubectl get configmaps -n monitoring -o yaml > monitoring-config-backup.yaml
```

For detailed troubleshooting, see [../docs/TROUBLESHOOTING_GUIDE.md](../docs/TROUBLESHOOTING_GUIDE.md)
