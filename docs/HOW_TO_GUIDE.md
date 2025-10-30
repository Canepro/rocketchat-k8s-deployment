# 🔧 How-To Guide: Common Operations & Recent Fixes

**Last Updated:** October 30, 2025  
**Purpose:** Quick reference for common operations and recently encountered issues

---

## 📋 Table of Contents

- [Cost Optimization](#cost-optimization)
- [MongoDB Replica Set Management](#mongodb-replica-set-management)
- [Authentication Scenarios](#authentication-scenarios)
- [Quick Troubleshooting](#quick-troubleshooting)

---

## 💰 Cost Optimization

### **Quick Cost Reduction**

Use the automated script:
```bash
./scripts/cost-optimization.sh
```

### **Manual Cost Optimization**

**Reduce MongoDB replicas:**
```bash
# Scale down MongoDB (automatically fixes replica set)
kubectl scale statefulset mongodb --replicas=1 -n rocketchat

# Fix replica set if needed
./scripts/fix-mongodb-replica-set.sh
```

**Reduce NATS replicas:**
```bash
kubectl scale statefulset rocketchat-nats --replicas=1 -n rocketchat
```

**Reduce DDP Streamer replicas:**
```bash
kubectl scale deployment rocketchat-ddp-streamer --replicas=1 -n rocketchat
```

**Expected Savings:** ~50-60% reduction in compute costs

### **Verify Resource Usage**

```bash
# Check current resource usage
kubectl top pods -n rocketchat

# Check replica counts
kubectl get statefulsets,deployments -n rocketchat -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{": "}{.spec.replicas}{" replicas\n"}{end}'
```

---

## 🔄 MongoDB Replica Set Management

### **Issue: ReplicaSetNoPrimary After Scaling Down**

**Symptoms:**
- `ReplicaSetNoPrimary` errors in Rocket.Chat logs
- `getaddrinfo ENOTFOUND mongodb-1` errors
- Pods crashing with MongoDB connection errors

**Cause:** MongoDB replica set still references removed members (mongodb-1, mongodb-2) after scaling down.

**Quick Fix:**
```bash
# Method 1: Use automated script
./scripts/fix-mongodb-replica-set.sh

# Method 2: Manual fix
kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "
cfg = rs.conf();
cfg.members = [{_id: 0, host: 'mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017', priority: 2}];
cfg.version = cfg.version + 1;
rs.reconfig(cfg, {force: true});
"

# Restart Rocket.Chat pods
kubectl rollout restart deployment/rocketchat-stream-hub -n rocketchat
kubectl rollout restart deployment/rocketchat-rocketchat -n rocketchat
```

**Verification:**
```bash
# Check replica set status
kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr))"

# Should show: mongodb-0: PRIMARY
```

### **Prevention**

When scaling down MongoDB, use the cost optimization script which handles replica set reconfiguration automatically:
```bash
./scripts/cost-optimization.sh
```

---

## 🔐 Authentication Scenarios

### **Scenario 1: Already Have kubectl Access** ✅

If you have kubeconfig configured on your personal machine:

```bash
# Deploy directly (no Azure auth needed)
kubectl apply -k k8s/base/

# Manage all Kubernetes resources
kubectl get pods -n rocketchat
kubectl logs -n rocketchat deployment/rocketchat-rocketchat
```

**No Azure authentication needed** for Kubernetes operations!

### **Scenario 2: Working from Work Machine**

```bash
# Login with Azure account
az login

# Use Terraform (uses authenticated session)
cd infrastructure/terraform
terraform apply
```

### **Scenario 3: Working from Personal Machine**

**Create Service Principal (from work machine):**
```bash
az ad sp create-for-rbac --name "rocketchat-automation" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>
```

**Use on Personal Machine:**
```bash
# Login with service principal
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>

# Use Terraform
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_TENANT_ID="<tenant-id>"
terraform apply
```

**See:** `docs/DEPLOYMENT_AUTHENTICATION_GUIDE.md` for complete details

---

## 🚨 Quick Troubleshooting

### **Pods Not Starting**

```bash
# Check pod status
kubectl get pods -n rocketchat

# Check pod events
kubectl describe pod <pod-name> -n rocketchat

# Check logs
kubectl logs <pod-name> -n rocketchat --tail=50
```

### **MongoDB Connection Issues**

```bash
# Check MongoDB replica set
kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "rs.status()"

# Check MongoDB logs
kubectl logs mongodb-0 -n rocketchat --tail=50

# Test MongoDB connectivity
kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "db.adminCommand('ping')"
```

### **Rocket.Chat Not Accessible**

```bash
# Check ingress
kubectl get ingress -n rocketchat

# Check services
kubectl get svc -n rocketchat

# Check pod status
kubectl get pods -n rocketchat | grep rocketchat-rocketchat

# Port forward for testing
kubectl port-forward svc/rocketchat-rocketchat 3000:80 -n rocketchat
```

### **Monitoring Not Working**

```bash
# Check Prometheus
kubectl get pods -n monitoring | grep prometheus

# Check Grafana
kubectl get pods -n monitoring | grep grafana

# Port forward to access
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

---

## 📚 Related Documentation

- **Deployment Guide:** `docs/DEPLOYMENT_AUTHENTICATION_GUIDE.md`
- **Cost Optimization:** `docs/COST_OPTIMIZATION_GUIDE.md`
- **Complete Troubleshooting:** `docs/TROUBLESHOOTING_GUIDE.md`
- **Service Principal Review:** `REPOSITORY_REVIEW_AZURE_SERVICE_PRINCIPAL.md`

---

**Last Updated:** October 30, 2025

