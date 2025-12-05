# 🚀 Template Setup Guide

Complete step-by-step guide for configuring and deploying this RocketChat template on Azure Kubernetes Service.

---

## 📋 Prerequisites Checklist

Before you begin, ensure you have:

- [ ] Azure subscription with contributor access
- [ ] Azure CLI installed and authenticated
- [ ] kubectl installed (version 1.28+)
- [ ] Helm 3.x installed
- [ ] Terraform installed (version 1.0+)
- [ ] Domain name with DNS management access
- [ ] Email account for Let's Encrypt

**Estimated Time**: 2-3 hours for first deployment

---

## 🎯 Quick Start (5 Steps)

### 1. Configure Azure & Terraform

```bash
# Login and set subscription
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Configure Terraform
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Update with your values
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform apply
```

### 3. Update Domain Configuration

```bash
# Replace placeholders in all config files
cd ../..
find aks/ k8s/ -name "*.yaml" -exec sed -i 's/<YOUR_DOMAIN>/chat.example.com/g' {} \;
find aks/ k8s/ -name "*.yaml" -exec sed -i 's/<YOUR_GRAFANA_DOMAIN>/grafana.example.com/g' {} \;
```

### 4. Deploy Application

```bash
# Get cluster credentials
az aks get-credentials --resource-group <YOUR_RG> --name <YOUR_CLUSTER>

# Deploy RocketChat
cd aks/deployment
./deploy-aks-official.sh
```

### 5. Set Up DNS

Point your domains to the load balancer IP:

```bash
# Get IP
kubectl get svc -n ingress-nginx

# Create A records:
# chat.example.com -> <LOAD_BALANCER_IP>
# grafana.example.com -> <LOAD_BALANCER_IP>
```

---

## 📚 Detailed Setup Guide

### Azure Configuration

#### 1. Authenticate

```bash
az login
az account list --output table
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

#### 2. Create Resource Group

```bash
az group create --name rocketchat-prod-rg --location eastus
```

#### 3. Reserve Static IP (Optional)

```bash
az network public-ip create \
  --resource-group rocketchat-prod-rg \
  --name rocketchat-lb-ip \
  --sku Standard \
  --allocation-method Static
```

### Terraform Configuration

Update `infrastructure/terraform/terraform.tfvars`:

```hcl
resource_group_name = "rocketchat-prod-rg"
cluster_name        = "rocketchat-aks"
rocketchat_domain   = "chat.example.com"
grafana_domain      = "grafana.example.com"
environment         = "production"
```

### Domain Setup

Create these DNS A records:

| Record | Value |
|--------|-------|
| chat.example.com | <LOAD_BALANCER_IP> |
| grafana.example.com | <LOAD_BALANCER_IP> |

Verify with: `nslookup chat.example.com`

---

## 🔧 Configuration Files to Update

### Required Updates

1. **infrastructure/terraform/terraform.tfvars**
   - Azure subscription and resource group
   - Cluster name and domain names
   
2. **aks/config/helm-values/values-official.yaml**
   - Domain name in `host:` field
   - Domain in ingress TLS section
   
3. **k8s/base/ingress.yaml**
   - Update `host:` fields

### Optional Updates

1. **MongoDB passwords** (recommended for production)
2. **Resource limits** (based on expected load)
3. **Storage sizes** (based on expected data volume)

---

## 🚀 Deployment Steps

### 1. Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform validate
terraform plan
terraform apply
```

### 2. Configure kubectl

```bash
az aks get-credentials \
  --resource-group rocketchat-prod-rg \
  --name rocketchat-aks

kubectl get nodes  # Verify connection
```

### 3. Deploy Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait
```

### 4. Deploy Cert-Manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait

# Create ClusterIssuer
kubectl apply -f aks/config/certificates/clusterissuer.yaml
```

### 5. Deploy RocketChat

```bash
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo update

helm upgrade --install rocketchat rocketchat/rocketchat \
  -f aks/config/helm-values/values-official.yaml \
  -n rocketchat \
  --create-namespace \
  --wait
```

### 6. Deploy Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/monitoring-values.yaml \
  -n monitoring \
  --create-namespace \
  --wait
```

---

## ✅ Verification

### Check Deployment Status

```bash
# All pods should be running
kubectl get pods -A

# Check RocketChat
kubectl get pods -n rocketchat
kubectl logs -f deployment/rocketchat -n rocketchat

# Check certificates
kubectl get certificates -A

# Test connectivity
curl -I https://chat.example.com
curl -I https://grafana.example.com
```

### Access Services

- **RocketChat**: https://chat.example.com
- **Grafana**: https://grafana.example.com (admin/prom-operator)

---

## 🔍 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n rocketchat
kubectl get events -n rocketchat --sort-by='.lastTimestamp'
```

### Certificate Issues

```bash
kubectl logs -n cert-manager deployment/cert-manager
kubectl describe certificate -n rocketchat
```

### DNS Not Resolving

```bash
nslookup chat.example.com
kubectl get ingress -A
kubectl get svc -n ingress-nginx
```

---

## 📖 Next Steps

After successful deployment:

1. ✅ Change default passwords (MongoDB, Grafana)
2. ✅ Configure monitoring alerts
3. ✅ Set up backups
4. ✅ Review security settings
5. ✅ Test disaster recovery

---

## 🆘 Support

- [Main README](README.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md)
- [Terraform Setup](infrastructure/terraform/TERRAFORM_SETUP.md)
- [Examples](examples/helm-values/README.md)

---

**🎉 Deployment complete!** Access RocketChat at your configured domain.

*Last Updated: December 2025*
