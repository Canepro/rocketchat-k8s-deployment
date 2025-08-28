# Rocket.Chat Kubernetes Deployment with Monitoring

This repository contains the configuration files and deployment script for deploying Rocket.Chat on Kubernetes with comprehensive monitoring using Prometheus and Grafana.

## 🚀 Features

- **Rocket.Chat**: Version 7.9.3 with high availability
- **MongoDB**: Replica set configuration for data persistence
- **Monitoring**: Prometheus and Grafana for metrics and dashboards
- **SSL/TLS**: Automatic certificate management with Let's Encrypt
- **Ingress**: Nginx ingress controller for external access
- **High Availability**: Multiple replicas with pod disruption budgets

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Kubernetes Cluster**: A running Kubernetes cluster (v1.20+)
2. **kubectl**: Kubernetes command-line tool
3. **Helm**: Helm v3 package manager
4. **Domain Name**: A domain name pointing to your cluster's external IP
5. **Storage Class**: A default storage class for persistent volumes

### Installing Prerequisites

#### kubectl
```bash
# For Windows (using Chocolatey)
choco install kubernetes-cli

# For macOS (using Homebrew)
brew install kubectl

# For Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### Helm
```bash
# For Windows (using Chocolatey)
choco install kubernetes-helm

# For macOS (using Homebrew)
brew install helm

# For Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 🔧 Configuration

### 1. Update Domain Configuration

Edit `values.yaml` and replace the placeholder domain:
```yaml
host: "chat.canepro.me"  # Your Rocket.Chat domain
```

### 2. Update Email Address

Edit `clusterissuer.yaml` and replace the email address:
```yaml
email: admin@canepro.me  # Replace with your actual email
```

### 3. Customize Passwords (Recommended)

For production use, change the default passwords in `values.yaml`:
```yaml
mongodb:
  auth:
    passwords:
      - "your-secure-password"  # Change this
    rootPassword: "your-secure-root-password"  # Change this

grafana:
  adminPassword: "your-secure-grafana-password"  # Change this
```

## 🚀 Deployment

### For Azure Ubuntu VM (Your Setup)

1. **First, set up your Ubuntu server**:
   ```bash
   chmod +x setup-ubuntu-server.sh
   ./setup-ubuntu-server.sh
   ```

2. **Logout and login again to apply group changes**

3. **Deploy Rocket.Chat**:
   ```bash
   chmod +x deploy-rocketchat.sh
   ./deploy-rocketchat.sh
   ```

### Quick Deployment (Other Environments)

1. **Make the script executable**:
   ```bash
   chmod +x deploy-rocketchat.sh
   ```

2. **Run the deployment script**:
   ```bash
   ./deploy-rocketchat.sh
   ```

### Manual Deployment

If you prefer to deploy manually, follow these steps:

1. **Install Ingress-Nginx Controller**:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

2. **Install cert-manager**:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
   ```

3. **Apply ClusterIssuer**:
   ```bash
   kubectl apply -f clusterissuer.yaml
   ```

4. **Add Helm repositories**:
   ```bash
   helm repo add rocketchat https://rocketchat.github.io/helm-charts
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   ```

5. **Install Prometheus Stack**:
   ```bash
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace \
     --set grafana.adminPassword=admin123
   ```

6. **Deploy Rocket.Chat**:
   ```bash
   helm install rocketchat -f values.yaml rocketchat/rocketchat \
     --namespace rocketchat \
     --create-namespace
   ```

## 📊 Monitoring

### Accessing Grafana

Grafana is exposed via Ingress:
- URL: https://grafana.chat.canepro.me
- Username: `admin`
- Password: `GrafanaAdmin2024!` (or the value set in `monitoring-values.yaml`)

### Rocket.Chat Metrics

Rocket.Chat exposes metrics on the `/metrics` endpoint, which are automatically scraped by Prometheus. Key metrics include:

- **Application metrics**: User sessions, message counts, API calls
- **System metrics**: CPU, memory, disk usage
- **Database metrics**: MongoDB connection status and performance

## 🔍 Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   kubectl get pods -n rocketchat
   kubectl describe pod <pod-name> -n rocketchat
   ```

2. **Certificate issues**:
   ```bash
   kubectl get certificaterequests -n rocketchat
   kubectl describe certificaterequest <name> -n rocketchat
   ```

3. **MongoDB connection issues**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=rocketchat -n rocketchat | grep "Mongo"
   ```

4. **Ingress not working**:
   ```bash
   kubectl get ingress -n rocketchat
   kubectl describe ingress <name> -n rocketchat
   ```

### Useful Commands

```bash
# Check all resources
kubectl get all -n rocketchat
kubectl get all -n monitoring

# View logs
kubectl logs -f deployment/rocketchat -n rocketchat

# Check persistent volumes
kubectl get pv,pvc -n rocketchat

# Check services
kubectl get svc -n rocketchat
kubectl get svc -n monitoring

# Check ingress
kubectl get ingress -n rocketchat
```

## 🔄 Updating Rocket.Chat

To update to a newer version:

1. **Update the image tag in `values-production.yaml`**:
   ```yaml
   image:
     tag: "7.9.3"  # Target version
   ```

2. **Upgrade the deployment**:
   ```bash
   helm upgrade rocketchat -n rocketchat -f values-production.yaml rocketchat/rocketchat
   ```

## 🗑️ Uninstalling

To completely remove the deployment:

```bash
# Remove Rocket.Chat
helm uninstall rocketchat -n rocketchat

# Remove Prometheus Stack
helm uninstall prometheus -n monitoring

# Remove namespaces
kubectl delete namespace rocketchat
kubectl delete namespace monitoring

# Remove ClusterIssuer
kubectl delete -f clusterissuer.yaml
```

## 📚 Additional Resources

- [Rocket.Chat Official Documentation](https://docs.rocket.chat/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## Quick Ops

### Pull latest config on VM and upgrade
```bash
cd ~/rocketchat-k8s-deployment
git pull
helm repo update
# Upgrade monitoring (Grafana via Ingress at grafana.chat.canepro.me)
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring-values.yaml
# Upgrade Rocket.Chat to 7.9.3
helm upgrade rocketchat -n rocketchat -f values-production.yaml rocketchat/rocketchat
```

### Access endpoints
- Rocket.Chat: https://chat.canepro.me
- Grafana: https://grafana.chat.canepro.me (user: `admin`, pass in `monitoring-values.yaml`)

### Notes
- MicroK8s ingress class is `public`; cert-manager `ClusterIssuer` uses `public` as well.
- MongoDB runs as a single-member replicaset for demo on a single VM.

### References
- Deploy with Kubernetes: https://docs.rocket.chat/docs/deploy-with-kubernetes
- Helm chart: https://github.com/RocketChat/helm-charts/tree/master/rocketchat

## Best practices (quick reference)
- External MongoDB for production (Atlas/Cosmos) or separate VM with backups; enable replica set and Oplog.
- Storage: use dedicated Premium SSD for MongoDB PVs; schedule snapshots.
- Backups: regular mongodump/restore or volume snapshots; document RPO/RTO.
- Monitoring: enable alerts in Grafana/Alertmanager (CPU, memory, pod down, Mongo lag, cert expiry).
- Security: rotate admin creds, restrict admin IPs if applicable, keep TLS enabled via cert-manager.
- Upgrades: change image tag in values and `helm upgrade`; test in staging first.
- Retention: tune Prometheus retention (monitoring-values.yaml) to balance disk usage and history.
- Cost: use VM auto‑shutdown, reservations/Savings Plan, and scale up only when needed.
