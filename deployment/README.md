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

# Deploy monitoring stack
helm install monitoring -f ../config/helm-values/values-monitoring.yaml rocketchat/monitoring \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout=10m

# Deploy Rocket.Chat
helm install rocketchat -f ../config/helm-values/values-official.yaml rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --wait \
  --timeout=15m
```

## Configuration Files

All configuration files are located in the `config/` directory:

- **`config/helm-values/values-official.yaml`** - Main Rocket.Chat configuration
- **`config/helm-values/values-monitoring.yaml`** - Monitoring stack configuration
- **`config/certificates/clusterissuer.yaml`** - SSL certificate issuer

## Monitoring Configuration

The monitoring stack includes:

- **Prometheus** - Metrics collection
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation
- **Alertmanager** - Alert management

### Accessing Monitoring

After deployment:
- **Grafana**: `https://grafana.chat.canepro.me`
- **Prometheus**: `kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring`

### Default Credentials

- **Grafana**: admin / admin

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
```

### 3. DNS Configuration

Update your DNS records to point to the AKS ingress IP:
- `chat.canepro.me` → AKS Ingress IP
- `grafana.chat.canepro.me` → AKS Ingress IP

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
