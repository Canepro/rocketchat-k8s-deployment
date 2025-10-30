# 🚀 Deployment Guide: Authentication Options

**Date:** October 30, 2025  
**Purpose:** Deploy Rocket.Chat AKS deployment using different authentication methods

## 🔐 Authentication Scenarios

### **Scenario 1: Already Have kubectl Access** ✅ (Simplest)
- ✅ You already have kubeconfig configured on your personal machine
- ✅ You can manage Kubernetes resources directly with kubectl
- ✅ No Azure authentication needed for Kubernetes operations
- ⚠️ Azure authentication only needed for Terraform (if deploying infrastructure)

### **Scenario 2: Working from Work Machine**
- ✅ Use `az login` for interactive authentication
- ✅ Terraform uses your authenticated session
- ✅ No service principal needed

### **Scenario 3: Working from Personal Machine** (Service Principal Recommended)
- ⚠️ Tenant login restricted to work machine
- ✅ Use Service Principal for automation
- ✅ Allows Terraform, scripts, and pipelines from personal machine

### **Scenario 4: CI/CD Pipelines**
- ✅ Use Service Principal or Managed Identity
- ✅ Allows automated deployments without manual intervention

---

## 📋 Quick Reference

### ✅ **What Works Without Service Principals**

- ✅ Core Rocket.Chat application
- ✅ MongoDB deployment
- ✅ Ingress and SSL certificates
- ✅ Prometheus/Grafana monitoring
- ✅ Terraform (with user authentication)
- ✅ Manual kubectl operations

### ⚠️ **What Requires Alternatives**

- ⚠️ Azure DevOps Pipelines → Use Managed Identity
- ⚠️ Azure Cost Monitoring → Skip or use Managed Identity
- ⚠️ Automated lifecycle management → Use manual scripts

---

## 🚀 Step-by-Step Deployment

### **If You Already Have kubectl Access** ✅ (Fastest Path)

If you already have a kubeconfig configured on your personal machine:

```bash
# Verify kubectl access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Deploy Rocket.Chat directly (no Azure authentication needed!)
kubectl create namespace rocketchat
kubectl create namespace monitoring

# Create secrets
kubectl create secret generic mongodb-auth \
  --from-literal=username=admin \
  --from-literal=password=your-secure-password \
  --namespace rocketchat

kubectl create secret generic rocketchat-mongodb-auth \
  --from-literal=mongo-url="mongodb://admin:your-secure-password@mongodb:27017/rocketchat?replicaSet=rs0" \
  --from-literal=mongo-oplog-url="mongodb://admin:your-secure-password@mongodb:27017/local?replicaSet=rs0" \
  --namespace rocketchat

# Deploy Rocket.Chat and MongoDB
kubectl apply -k k8s/base/

# Deploy monitoring
kubectl apply -f aks/monitoring/prometheus-static-no-sa.yaml
kubectl apply -f aks/monitoring/grafana-no-sa.yaml

# Verify deployment
kubectl get pods -n rocketchat
kubectl get pods -n monitoring
```

**Azure Authentication Only Needed For:**
- ⚠️ Terraform (if creating/modifying Azure infrastructure)
- ⚠️ Azure CLI commands (if managing Azure resources)
- ⚠️ Azure Pipelines (if using CI/CD)

**Kubernetes Operations Don't Need Azure Auth:**
- ✅ Deploying applications (`kubectl apply`)
- ✅ Managing pods, services, deployments
- ✅ Viewing logs (`kubectl logs`)
- ✅ Executing commands in pods (`kubectl exec`)
- ✅ Port forwarding (`kubectl port-forward`)

---

### **Step 1: Authenticate to Azure** (Only if needed for Terraform/Azure CLI)

**Option A: Interactive Login (Work Machine)**
```bash
# Login with your Azure account (user authentication)
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Verify authentication
az account show
```

**Option B: Service Principal (Personal Machine)**
```bash
# Login with service principal (allows automation from personal machine)
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Verify authentication
az account show
```

**Creating a Service Principal:**
```bash
# Run this from your work machine where you have Azure access
az ad sp create-for-rbac --name "rocketchat-automation" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>

# Save the output (client_id, client_secret, tenant_id)
# Use these credentials on your personal machine
```

### **Step 2: Deploy Core Application**

```bash
# Create namespaces
kubectl create namespace rocketchat
kubectl create namespace monitoring

# Create secrets
kubectl create secret generic mongodb-auth \
  --from-literal=username=admin \
  --from-literal=password=your-secure-password \
  --namespace rocketchat

kubectl create secret generic rocketchat-mongodb-auth \
  --from-literal=mongo-url="mongodb://admin:your-secure-password@mongodb:27017/rocketchat?replicaSet=rs0" \
  --from-literal=mongo-oplog-url="mongodb://admin:your-secure-password@mongodb:27017/local?replicaSet=rs0" \
  --namespace rocketchat

# Deploy Rocket.Chat and MongoDB
kubectl apply -k k8s/base/

# Verify deployment
kubectl get pods -n rocketchat
```

### **Step 3: Deploy Monitoring** (No Service Principals Needed)

```bash
# Deploy static Prometheus (no service accounts)
kubectl apply -f aks/monitoring/prometheus-static-no-sa.yaml

# Deploy Grafana (no service accounts)
kubectl apply -f aks/monitoring/grafana-no-sa.yaml

# Create Grafana admin secret
kubectl create secret generic grafana-admin \
  --from-literal=username=admin \
  --from-literal=password=your-grafana-password \
  --namespace monitoring

# Verify monitoring stack
kubectl get pods -n monitoring
```

### **Step 4: Deploy Infrastructure** (Only if creating/modifying Azure resources)

**Option A: Using User Authentication (Work Machine)**
```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Initialize Terraform (uses your authenticated Azure session)
terraform init

# Review plan
terraform plan

# Apply infrastructure
terraform apply
```

**Option B: Using Service Principal (Personal Machine)**
```bash
# Set environment variables for Terraform
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"

# Navigate to Terraform directory
cd infrastructure/terraform

# Initialize Terraform (uses service principal)
terraform init

# Review plan
terraform plan

# Apply infrastructure
terraform apply
```

**Note:** Service principal allows Terraform to run from your personal machine when tenant access is restricted to your work machine.

### **Step 5: Deploy Enhanced Features**

```bash
# Deploy enhanced features WITHOUT cost monitoring
ENABLE_COST_MONITORING=false \
ENABLE_AUTOSCALING=true \
ENABLE_HA=true \
ENABLE_HEALTH_CHECKS=true \
./aks/scripts/deploy-enhanced-features.sh
```

### **Step 6: Azure Cost Monitoring** (Optional - requires Azure authentication)

```bash
# DO NOT apply this file (requires service principal):
# kubectl apply -f aks/monitoring/azure-cost-monitoring.yaml

# Instead, monitor costs via Azure Portal:
# https://portal.azure.com → Cost Management + Billing
```

---

## 🔄 Azure DevOps Pipelines

### **Option A: Use Managed Identity Pipeline**

If your Azure DevOps agent supports Managed Identity:

```yaml
# Use lifecycle-management-mi.yml instead of lifecycle-management.yml
# This file uses: az login --identity
```

**Setup:**
1. Configure Azure DevOps agent with Managed Identity
2. Assign required permissions to Managed Identity
3. Use `lifecycle-management-mi.yml` pipeline

### **Option B: Use Manual Scripts**

If Managed Identity is not available:

```bash
# Manual backup
./scripts/backup/mongodb-backup.sh

# Manual teardown
./scripts/lifecycle/teardown-cluster.sh

# Manual recreation
./scripts/lifecycle/recreate-cluster.sh
```

---

## 🔐 Authentication Methods

### **1. User Authentication** ✅ (Recommended)

**For:** Terraform, Azure CLI, kubectl

```bash
# Login interactively
az login

# Login with device code (for headless environments)
az login --use-device-code

# Login with service principal (if available)
az login --service-principal \
  --username <app-id> \
  --password <password> \
  --tenant <tenant-id>
```

### **2. Managed Identity** ✅ (If Available)

**For:** Azure Pipelines, Azure resources

```bash
# Login with Managed Identity
az login --identity

# Verify identity
az account show
```

**Requirements:**
- Azure VM or Pipeline Agent with Managed Identity enabled
- Appropriate RBAC permissions assigned

### **3. Skip Authentication-Dependent Features** ✅

**For:** Azure Cost Monitoring

```bash
# Skip cost monitoring deployment
# Monitor costs manually via Azure Portal
```

---

## 📊 What Requires Azure Authentication vs kubectl Access

| Operation | Requires Azure Auth? | Requires kubectl? | Notes |
|-----------|---------------------|-------------------|-------|
| **Deploy Rocket.Chat** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **Deploy MongoDB** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **Deploy Monitoring** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **Manage Pods** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **View Logs** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **Port Forward** | ❌ No | ✅ Yes | kubectl access is sufficient |
| **Terraform (create cluster)** | ✅ Yes | ❌ No | Need Azure auth to create infrastructure |
| **Terraform (modify resources)** | ✅ Yes | ❌ No | Need Azure auth to modify Azure resources |
| **Azure CLI (az aks...)** | ✅ Yes | ❌ No | Need Azure auth for Azure resource management |
| **Azure Cost Monitoring** | ✅ Yes | ✅ Yes | Needs Azure auth to access cost APIs |
| **Azure Pipelines** | ✅ Yes | ✅ Yes | Needs Azure auth for CI/CD |

**Key Insight:** If you already have kubectl access configured, you can do **most day-to-day operations** without Azure authentication!

---

## 🛠️ Troubleshooting

### **Terraform Authentication Issues**

**Problem:** Terraform can't authenticate to Azure

**Solution:**
```bash
# Verify Azure login
az account show

# Re-authenticate if needed
az login

# Try Terraform again
terraform plan
```

### **Azure CLI Command Failures**

**Problem:** Azure CLI commands fail with authentication errors

**Solution:**
```bash
# Check current account
az account show

# List available subscriptions
az account list

# Set correct subscription
az account set --subscription "<subscription-id>"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

### **Pipeline Authentication Failures**

**Problem:** Azure DevOps pipeline can't authenticate

**Solution:**
1. **Use Managed Identity version:**
   ```yaml
   # Use lifecycle-management-mi.yml
   az login --identity
   ```

2. **Or configure service connection:**
   - Azure DevOps → Project Settings → Service Connections
   - Create new service connection
   - Use Managed Identity or User Authentication

### **Cost Monitoring Not Working**

**Problem:** Azure cost monitoring dashboard shows no data

**Solution:**
```bash
# Skip cost monitoring (simplest solution)
# Don't apply: aks/monitoring/azure-cost-monitoring.yaml

# Monitor costs via Azure Portal instead
# https://portal.azure.com → Cost Management + Billing
```

---

## 📚 Additional Resources

### **Related Documentation**

- `REPOSITORY_REVIEW_AZURE_SERVICE_PRINCIPAL.md` - Complete service principal analysis
- `docs/ENHANCED_FEATURES_GUIDE.md` - Enhanced features documentation
- `docs/TROUBLESHOOTING_GUIDE.md` - General troubleshooting

### **Azure Documentation**

- [Azure CLI Authentication](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli)
- [Managed Identity for Azure Resources](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Terraform Azure Provider Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] Rocket.Chat pods running (`kubectl get pods -n rocketchat`)
- [ ] MongoDB pods running (`kubectl get pods -n rocketchat | grep mongodb`)
- [ ] Prometheus accessible (`kubectl port-forward svc/prometheus-static 9090:9090 -n monitoring`)
- [ ] Grafana accessible (`kubectl port-forward svc/grafana 3000:3000 -n monitoring`)
- [ ] Terraform can manage infrastructure (`terraform plan` works)
- [ ] No service principal credentials required for core operations
- [ ] Azure authentication working (`az account show`)

---

## 🎯 Summary

**If You Already Have kubectl Access:**
- ✅ Deploy Rocket.Chat directly with kubectl (no Azure auth needed)
- ✅ Deploy MongoDB directly with kubectl (no Azure auth needed)
- ✅ Deploy monitoring stack directly with kubectl (no Azure auth needed)
- ✅ Manage all Kubernetes resources without Azure authentication
- ⚠️ Azure authentication only needed for Terraform/Azure CLI operations

**Authentication Options:**

**Working from Work Machine:**
- ✅ Use user authentication (`az login`) for Terraform/Azure CLI
- ✅ kubectl works if kubeconfig is configured

**Working from Personal Machine:**
- ✅ kubectl works if kubeconfig is configured (no Azure auth needed!)
- ✅ Use service principal for Terraform/Azure CLI if needed
- ✅ Allows Terraform, scripts, and pipelines from personal machine
- ✅ Bypasses need for work machine access for Kubernetes operations

**Recommended approach:**
1. **Kubernetes Operations:** Use kubectl directly (no Azure auth needed if kubeconfig is configured)
2. **Infrastructure/Terraform:** Use service principal if needed, or skip if cluster already exists
3. **CI/CD Pipelines:** Use service principal or Managed Identity
4. **Cost Monitoring:** Requires Azure authentication (optional feature)

**Key Takeaway:** If you have kubectl access, you can manage most of the deployment without Azure service principals!

