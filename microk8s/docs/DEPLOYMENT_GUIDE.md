# 🚀 Rocket.Chat Deployment Guide for Azure Ubuntu VM

This guide will walk you through deploying Rocket.Chat with monitoring on your Azure Ubuntu VM.

## 📋 **Prerequisites Checklist**

- ✅ Azure Ubuntu VM (B2s: 2 vCPUs, 4GB RAM)
- ✅ Public IP: `20.68.53.249`
- ✅ Domain: `<YOUR_DOMAIN>` (DNS A record configured)
- ✅ Email: `your-email@example.com` (for Let's Encrypt)

## 🔧 **Step 1: Server Setup**

### 1.1 Connect to your Azure VM
```bash
ssh your-username@20.68.53.249
```

### 1.2 Run the Ubuntu setup script
```bash
# Make the script executable
chmod +x setup-ubuntu-server.sh

# Run the setup script
./setup-ubuntu-server.sh
```

### 1.3 Logout and login again
```bash
exit
# SSH back in to apply group changes
ssh your-username@20.68.53.249
```

### 1.4 Verify the setup
```bash
# Check MicroK8s status
microk8s status

# Check kubectl
kubectl get nodes

# Check Docker
docker --version

# Check Helm
helm version
```

## 🚀 **Step 2: Deploy Rocket.Chat**

### 2.1 Run the deployment script
```bash
# Make the script executable
chmod +x deploy-rocketchat.sh

# Run the deployment
./deploy-rocketchat.sh
```

### 2.2 Monitor the deployment
```bash
# Check all pods
kubectl get pods -A

# Check Rocket.Chat pods specifically
kubectl get pods -n rocketchat

# Check monitoring pods
kubectl get pods -n monitoring

# View Rocket.Chat logs
kubectl logs -f deployment/rocketchat -n rocketchat
```

## 🌐 **Step 3: Access Your Applications**

### 3.1 Rocket.Chat
- **URL**: https://<YOUR_DOMAIN>
- **Setup**: Complete the initial setup wizard

### 3.2 Grafana (Monitoring)
```bash
# Port forward to Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```
- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: `GrafanaAdmin2024!`

### 3.3 Prometheus (Metrics)
```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
```
- **URL**: http://localhost:9090

## 📊 **Step 4: Monitoring Setup**

### 4.1 Import Rocket.Chat Dashboard in Grafana
1. Access Grafana at http://localhost:3000
2. Go to Dashboards → Import
3. Import the Rocket.Chat dashboard (ID: 12345)

### 4.2 Set up Alerts
1. In Grafana, go to Alerting → Alert Rules
2. Create alerts for:
   - High CPU usage (>80%)
   - High memory usage (>80%)
   - Rocket.Chat pod down
   - MongoDB connection issues

## 🔍 **Step 5: Verification & Testing**

### 5.1 Check SSL Certificate
```bash
# Check certificate status
kubectl get certificaterequests -n rocketchat
kubectl get certificates -n rocketchat
```

### 5.2 Test Rocket.Chat
1. Visit https://<YOUR_DOMAIN>
2. Complete the setup wizard
3. Create your first user account
4. Test sending messages

### 5.3 Test Monitoring
1. Access Grafana
2. Check if Rocket.Chat metrics are being collected
3. Verify Prometheus is scraping metrics

## 🛠️ **Step 6: Production Hardening**

### 6.1 Change Default Passwords
```bash
# Update MongoDB passwords in values-production.yaml
# Update Grafana password in monitoring-values.yaml
```

### 6.2 Set up Backup
```bash
# Create backup script
cat > backup-rocketchat.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
kubectl get all -n rocketchat -o yaml > backup_rocketchat_$DATE.yaml
kubectl get all -n monitoring -o yaml > backup_monitoring_$DATE.yaml
echo "Backup completed: backup_rocketchat_$DATE.yaml, backup_monitoring_$DATE.yaml"
EOF

chmod +x backup-rocketchat.sh
```

### 6.3 Set up Logging
```bash
# Enable MicroK8s logging
microk8s enable fluentd
```

## 🔧 **Troubleshooting**

### Common Issues

#### 1. Pods not starting
```bash
# Check pod status
kubectl get pods -n rocketchat
kubectl describe pod <pod-name> -n rocketchat

# Check events
kubectl get events -n rocketchat --sort-by='.lastTimestamp'
```

#### 2. Certificate issues
```bash
# Check cert-manager
kubectl get pods -n cert-manager
kubectl describe certificaterequest <name> -n rocketchat
```

#### 3. DNS issues
```bash
# Test DNS resolution
nslookup <YOUR_DOMAIN>
dig <YOUR_DOMAIN>

# Check if domain points to your IP
curl -I http://<YOUR_DOMAIN>
```

#### 4. Resource issues
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n rocketchat
kubectl top pods -n monitoring

# Check disk space
df -h
```

### Useful Commands

```bash
# Check all resources
kubectl get all -A

# View logs
kubectl logs -f deployment/rocketchat -n rocketchat
kubectl logs -f deployment/prometheus-kube-prometheus-prometheus -n monitoring

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A

# Check persistent volumes
kubectl get pv,pvc -A
```

## 🔄 **Maintenance**

### Updating Rocket.Chat
```bash
# Update the image tag in values-production.yaml
# Then run:
helm upgrade rocketchat -f values-production.yaml rocketchat/rocketchat
```

### Scaling
```bash
# Scale Rocket.Chat (if you upgrade your VM)
kubectl scale deployment rocketchat -n rocketchat --replicas=2
```

### Backup and Restore
```bash
# Create backup
./backup-rocketchat.sh

# Restore (if needed)
kubectl apply -f backup_rocketchat_YYYYMMDD_HHMMSS.yaml
```

## 📞 **Support**

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs: `kubectl logs -f deployment/rocketchat -n rocketchat`
3. Check system resources: `htop`
4. Verify network connectivity: `curl -I https://<YOUR_DOMAIN>`

## 🎉 **Congratulations!**

You now have a production-grade Rocket.Chat deployment with:
- ✅ High availability configuration
- ✅ SSL/TLS encryption
- ✅ Comprehensive monitoring
- ✅ Production resource limits
- ✅ Backup procedures

Your Rocket.Chat instance is ready for production use!

## Full Runbook (Azure D4ads_v5 + MicroK8s)

1) Prepare VM networking and DNS
- Open inbound 80/443 in Azure NSG
- A records:
  - <YOUR_DOMAIN> → VM IP
  - grafana.<YOUR_DOMAIN> → VM IP

2) SSH and clone repo
```bash
ssh azureuser@<VM_IP>
sudo apt update && sudo apt install -y git
ssh-keygen -t ed25519 -C "azure-vm" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub   # add to GitHub SSH keys
ssh -T git@github.com
git clone git@github.com:Canepro/rocketchat-k8s-deployment.git ~/rocketchat-k8s-deployment
cd ~/rocketchat-k8s-deployment
```

3) Server setup
```bash
chmod +x setup-ubuntu-server.sh
./setup-ubuntu-server.sh
sudo usermod -aG microk8s $USER
sudo chown -R $USER ~/.kube
newgrp microk8s
microk8s status --wait-ready
kubectl get nodes
```

4) Deploy stack
```bash
chmod +x deploy-rocketchat.sh
./deploy-rocketchat.sh
kubectl get pods -n cert-manager
kubectl get pods -n monitoring
kubectl get pods -n rocketchat
kubectl get ingress -n rocketchat
```

5) Verify DNS and TLS
```bash
dig +short <YOUR_DOMAIN>
kubectl get certificate -n rocketchat
kubectl describe certificaterequest -n rocketchat | sed -n '1,120p'
curl -I https://<YOUR_DOMAIN>
```

6) Enable Grafana via Ingress (subdomain)
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring-values.yaml
kubectl get ingress -n monitoring
# Open https://grafana.<YOUR_DOMAIN> (admin / GrafanaAdmin2024!)
```

7) Upgrade Rocket.Chat (example: 7.9.3)
```bash
# values-production.yaml already set to 7.9.3
helm repo update
helm upgrade rocketchat -n rocketchat -f values-production.yaml rocketchat/rocketchat
kubectl rollout status deploy/rocketchat-rocketchat -n rocketchat
```

## Troubleshooting we hit
- SSH to GitHub failed with sanitized hostname ([email protected]) → fix remote to `git@github.com:...` and add SSH key; verify with `ssh -T git@github.com`.
- MicroK8s permissions: needed `usermod -aG microk8s` and `newgrp microk8s` before `microk8s status` worked.
- Ingress on MicroK8s shows 127.0.0.1: that’s expected; it still listens on the node’s public IP.
- Grafana access without port-forward: added Ingress at `grafana.<YOUR_DOMAIN>` with cert-manager TLS in `monitoring-values.yaml`.
- Cert-manager: confirmed `Certificate` Ready and HTTP→HTTPS redirect worked.

## Ongoing Ops
- Pull config updates:
```bash
cd ~/rocketchat-k8s-deployment && git pull
```
- Upgrade monitoring:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring -f monitoring-values.yaml
```
- Upgrade Rocket.Chat:
```bash
helm upgrade rocketchat -n rocketchat -f values-production.yaml rocketchat/rocketchat
```
- Access:
  - https://<YOUR_DOMAIN>
  - https://grafana.<YOUR_DOMAIN>

## Best practices
- Database: use managed MongoDB for prod or a dedicated VM; ensure replica set and periodic backups.
- Storage: Premium SSD for MongoDB PVs; separate disk from OS; automate snapshots.
- Monitoring: create Alertmanager rules (CPU > 80%, memory > 80%, pod down, Mongo connectivity, cert expiry).
- Security: rotate secrets, restrict admin access, enforce TLS, keep Helm values out of public repos.
- Change management: test upgrades in staging; pin chart version; record change windows.
- Capacity: start 4vCPU/16GiB; review `kubectl top` and adjust requests/limits; scale when sustained >70%.
- Cost controls: VM auto‑shutdown, reservations, and cleanup unused PVCs/images.

## Runbook add-ons
- Backup MongoDB (example cron): mongodump to secure storage; verify restore quarterly.
- Disaster recovery: export Helm values, back up `clusterissuer.yaml` and TLS secrets.
- Log access: `kubectl logs -l app.kubernetes.io/name=rocketchat -n rocketchat` and Grafana/Prometheus UI.
- Certificates: rotate email in `clusterissuer.yaml` when ownership changes.
