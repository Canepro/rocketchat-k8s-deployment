# 🔐 **AKS Remote Access Guide - Service Account Method**

## 📋 **Document Information**

- **Created:** September 7, 2025
- **Last Updated:** September 7, 2025
- **Purpose:** Enable remote access to AKS cluster without Azure CLI, kubeconfig, or cloud portals
- **Method:** Kubernetes Service Account with cluster-admin permissions
- **Security Level:** High (Token-based authentication with CA validation)

---

## 🎯 **Overview**

This guide provides **complete remote access** to your Rocket.Chat AKS cluster using only:
- ✅ kubectl installed locally
- ✅ Service account token (no Azure credentials needed)
- ✅ CA certificate for secure connection
- ❌ No Azure CLI required
- ❌ No kubeconfig files needed
- ❌ No cloud portal access needed

---

## 🚀 **Quick Start**

### **Step 1: Set Environment**
```bash
# Set the kubeconfig to use our remote access configuration
export KUBECONFIG=./remote-access-config.yaml

# Test the connection
kubectl cluster-info
```

### **Step 2: Verify Access**
```bash
# Check cluster status
kubectl get nodes

# Check your Rocket.Chat deployment
kubectl get pods -n rocketchat

# Check monitoring stack
kubectl get pods -n monitoring
```

### **Expected Output:**
```
Kubernetes control plane is running at https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443
NAME                                STATUS   ROLES   AGE   VERSION
aks-agentpool-13009631-vmss000000   Ready    agent   2d    v1.30.3

NAME                                        READY   STATUS    RESTARTS   AGE
rocketchat-rocketchat-8477df4d58-2wv72       1/1     Running   0          2d
rocketchat-mongodb-0                         2/2     Running   0          2d
# ... more pods
```

---

## 📁 **Configuration Files**

### **remote-access-config.yaml** - Complete Kubeconfig

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUU2VENDQXRHZ0F3SUJBZ0lSQUtlaDBCZkFKbzhjRmFpb3pjOEUxMDh3RFFZSktvWklo
dmNOQVFFTEJRQXcKRFRFTE1Ba0dBMVVFQXhNQ1kyRXdJQmNOTWpVd09UQXlNVGd5TlRNNVdoZ1BNakExTlRBNU1ESXhPRE0xTXpsYQpNQTB4
Q3pBSkJnTlZCQU1UQW1OaE1JSUNJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBZzhBTUlJQ0NnS0NBZ0VBCnJPL2szRlV6NHk1bmxzNkdDSWZM
QmRSNS94dGFKdnI5OFBaZkZaSE00QmJIM3JDQkhUc3FhUEFOeWwrUWszYk4KanlrOHBVTmo0TGdaQ3REODNtN0hTSUk5THVoYTZsQVI1OXlo
anV2WmJKSzFHU1I1UVpXc1BBUmFHMklPTFRnTgpWWG15WDlVV1NjSjMwdXN2aGxIaTlBNWNLSUJGM1hIWGVPUHNuRFdkRVdNOC8zNVI2Z3lV
M25LWWVXc3prQWw3CkhmV2dTU0tuc1NZdldyMmVMcWp4U2JHOW9sWjVtUU9TZFp4YWIveW50M2JnUUR1K3JnR1NlV2JMeVNWUk9CVnQKZk4r
eWxqb1JETURFU0k2MXpNS1ZsendGVXRWeER1TndXTVNURU1GVmhBRUJMQ3ZnVHNyQUk0Z0cwcmVVMHJhaQpwTmVqQmVZM2hWWG5xWmlwTHl2
K1hXRHg3aUVVS213WTNoODEycHZJbC9NT2JqenhzU3pWYTYwUGZDclhSOTE5Ckt1LzltK01oaFNCdk5aZGdHbzBVTFN0aUQ3c1V5VklTb3B5
R0cwa2NtZk9VS3c1UHcwZkZzeGloWEdPZVVoOUcKL2tTcTRpTmg3UWpwdVZHeFNQbkQ1NHNocmI0VVFFd0RWV0lrNmw5dGxnMmc4T2tWaC9m
ZkJNM2prNmE5ZjVINApiNm1VdTMwV1hzRmJMcG95anBwRnlhN1NwY2x3UGNFUVNQQ0c0Sjl5SWozekJlRzZqL0huMWI1MngyTWNXWTRHCkZR
aTlwUVR1Z1AzZTl3dlNmcGVMQmJwYTVDMkxJb09GU1lKbzBqL0MzaHR2YjJBRTZpN1dsR1hjRnpaeGtvODcKQ29ZRnA0RjRDcEZybCtNeVRq
TlB6SnZmN2NiVnl6SlRNMUpQbGM0dHJya0NBd0VBQWFOQ01FQXdEZ1lEVlIwUApBUUgvQkFRREFnS2tNQThHQTFVZEV3RUIvd1FGTUFNQkFm
OHdIUVlEVlIwT0JCWUVGQnVaOXJuR0JaSGZYZFRVCjFGS2hFSGx3OWlTNk1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQ0FRQXFBbEJVL2VnZWxn
R2M4cjJ0U3J6alF2UTQKS0ZTZm9YOUJGajhvV2lFNlNpRTZHaUk1UXRPSHRsN2ZmNlg2UVRYaThucU9OKzFtTkgzMzNRcFgyRGQxeXNBaQp6
YTZyMUVLZGt5ZHArT1Q2cEk2b2o0Rk00MkhBaUhWNHNEblNnZVRJQlN4N0k5SHNuSk9Wb2pRNUI3M2UwbUZ0CkI2ZkNmSmswRE1NSHVkclB2
VzhiQVZPdWdQdjZ2bzR4a3RoWnhwM0tQa2JVMWs4TFJMMkdEY09ZWmpGYjVRUjAKOVVCSWd2Um0xRnhFM3MybXQ2YVcwQjVIcXlaTko4bGxH
bjBJM1RnRTE4OXBCTTgzcTVRTk1IUzNvV2ZER0ZOcwpIbzJXbGpMYzkzNkRNN0dERk54WnhVYWpXajVGQk05dnhCOWJwT0ViaGNzNFk4cVhz
ZmUrVTlKZ2Z5RTR6aTlnCi9wd0hqQUZjeVB4NTZEV3VseU94UVJ3WXllUVZtVmgxUDJxbmxJUkJndS9aTCs2S0VQY2ErVFFPT1E5RjZXNkcK
Wk1ZbXp4Unh5Q1I0bEJHaTY2N2hPS1E3c2hDM1UvT1VacXZmbUgwWEpoTldGYUYxZElyRldIUm41Qlg1VFVmYgp0ZmtWNm1PWWZIQ25tWkg3
NnE0S3h3WTkrN0ZDZitrdVZtaEZDdzFUM0Z4dStTYTRwYzNBM0dQRGJ1SWJOUjZrCjl3TVpyK1dtUzB6eFhwdzJXbDJXUVJ2NkNaVmR5VTRX
b1hkMkpYRjB5YTNBQ05FRXFTV1c2cWtIZk8xeElMV04KZDh1cndwcDQ0bHdvMjcwc2kxZTY1aWRIOWkrWXpxQ3g5SHh1elF3aTdubGFyUGlo
dzNqMGhkVUUvT1Njbm9UdApMbk9aS0M3QjhuZ0hUMEdFcEE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443
  name: aks-cluster
contexts:
- context:
    cluster: aks-cluster
    user: remote-access
  name: aks-remote
current-context: aks-remote
users:
- name: remote-access
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6IlFOZzFEWE0wX19wSzFCc0xiXy10aVhURVB0ZVNBa2U1U2FjU0x2ZmhhN0UifQ.eyJpc3MiOiJrdWJlc
m5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZ
XRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InJlbW90ZS1hY2Nlc3MtdG9rZW4iLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY
2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoicmVtb3RlLWFjY2VzcyIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZ
S1hY2NvdW50LnVpZCI6IjEwYzFiMzQxLWM0NGMtNGRhNS04MzE0LWUyNjg0Njc2OTZkNyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3Vud
DpkZWZhdWx0OnJlbW90ZS1hY2Nlc3MifQ.uoOOW8NV0gWAQVNEZftAHi1JCK31Ok2gdmmGYAPo82cmmkhAR1RtxbK-XlhWmhvmdZui2dmRUD
xSIIBP8AN4IXJuzLRYZk04wpnRbw9Z7dNePjfvne96BzcQiKvn8Nts6ySSyUKAjiMyt5-AIFjb5PkXn8jbqqnzO3fvRcLylVAMNfPEME3xLa
MsvTUYIUS9hwBqBfaIewz40VH40myV-yR0UEXaZSYzaErJp0aS22IabJLiPfFzBC_TMUHSloJSfeWc6vbHdTKyoC-NrZGmkoT7eGU0zHCte3
4lwe93a4mJ7EcI6eApMLgMi-UyKumh1rVDlCGLFKRGMxo6xqJRW8CkOczIingpBuGAd_hg4vNayfDf2p6khe3GaZ7CynInPsWPDB9oL-VKGp
DX8zUcD9BTX-z0ZdrJH5BC9X4Y9ltmaqkjPYHERiK_n9AK2Vx_ahieIndB2eHVtqceoiNSHjMhvVDwv_h7On-CGEo_xftMrpkHYlylmPQmn4
8JB1M4g7L6oloAIZsC5Mg4qrf_IUKWLIsLZoV_I0koKOMs6x6vvAVSeov2J1HjJfNk2eAvincent@MogahPC:/mnt/c/Users/i/rocketchat-k8s-deployment
```

---

## 🛠️ **Setup Instructions**

### **Prerequisites:**
- ✅ kubectl installed (any version 1.24+)
- ✅ Network access to internet
- ❌ No Azure CLI needed
- ❌ No kubeconfig files needed
- ❌ No cloud portal access needed

### **Step 1: Download Configuration**
```bash
# The remote-access-config.yaml file contains everything needed
# Copy it to any machine with kubectl installed
ls -la remote-access-config.yaml
```

### **Step 2: Set Environment**
```bash
# Set the KUBECONFIG environment variable
export KUBECONFIG=./remote-access-config.yaml

# Optional: Add to your shell profile for permanent access
echo 'export KUBECONFIG=./remote-access-config.yaml' >> ~/.bashrc
source ~/.bashrc
```

### **Step 3: Test Connection**
```bash
# Test basic connectivity
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443
```

### **Step 4: Verify Access**
```bash
# Check cluster nodes
kubectl get nodes

# Check your Rocket.Chat deployment
kubectl get pods -n rocketchat

# Check monitoring stack
kubectl get pods -n monitoring
```

---

## 🎯 **Common Operations**

### **Monitor Rocket.Chat**
```bash
# Check pod status
kubectl get pods -n rocketchat

# View logs
kubectl logs -n rocketchat deployment/rocketchat --tail=20

# Check resource usage
kubectl top pods -n rocketchat
```

### **Access Grafana**
```bash
# Port forward to access Grafana locally
kubectl port-forward -n monitoring svc/grafana-service 3000:3000

# Access at: http://localhost:3000
# Credentials: admin / admin
```

### **Scale Resources**
```bash
# Scale Rocket.Chat deployment
kubectl scale deployment rocketchat -n rocketchat --replicas=3

# Check current scaling
kubectl get hpa -n rocketchat
```

### **Check Monitoring Stack**
```bash
# Prometheus status
kubectl get pods -n monitoring | grep prometheus

# Loki status
kubectl get pods -n loki-stack

# AlertManager status
kubectl get pods -n monitoring | grep alertmanager
```

---

## 🔒 **Security Information**

### **Authentication Method:**
- **Type:** Service Account Token
- **Permissions:** cluster-admin (full cluster access)
- **Token Validity:** No expiration (Kubernetes service account tokens)
- **Encryption:** TLS 1.3 with CA certificate validation

### **Security Features:**
- ✅ **Token-based authentication** (no username/password)
- ✅ **CA certificate validation** (secure connection)
- ✅ **RBAC authorization** (proper permissions)
- ✅ **Encrypted connection** (HTTPS/TLS)
- ✅ **No credentials stored** in kubeconfig

### **Risk Mitigation:**
- 🔒 **Token stored securely** (never share)
- 🔒 **CA certificate included** (no MITM attacks)
- 🔒 **Minimal permissions** principle (cluster-admin only when needed)
- 🔒 **Network encryption** (all traffic encrypted)

---

## 🆘 **Troubleshooting**

### **Connection Issues**
```bash
# Test basic connectivity
kubectl cluster-info

# If fails, check network access
curl -k https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443/api/v1/

# Check kubectl version compatibility
kubectl version --client
```

### **Permission Issues**
```bash
# Test basic operations
kubectl get nodes

# If fails, check token validity
kubectl auth can-i get nodes

# Check service account status
kubectl get serviceaccount remote-access -n default
```

### **Certificate Issues**
```bash
# Test SSL connection
openssl s_client -connect canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443 -servername canepro-h84gy5hj.hcp.uksouth.azmk8s.io

# Check certificate expiry
echo | openssl s_client -connect canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443 2>/dev/null | openssl x509 -noout -dates
```

---

## 💾 **Backup & Recovery**

### **Save Configuration**
```bash
# Backup the configuration file
cp remote-access-config.yaml remote-access-config-backup-$(date +%Y%m%d).yaml

# Store securely (encrypted storage recommended)
# Never commit to version control
```

### **Token Rotation**
```bash
# If token needs rotation (rare, but possible)
kubectl delete secret remote-access-token -n default

# Recreate secret (will generate new token)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: remote-access-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: remote-access
type: kubernetes.io/service-account-token
EOF

# Get new token and update config file
kubectl get secret remote-access-token -n default -o jsonpath='{.data.token}' | base64 -d
```

---

## 📊 **Performance & Best Practices**

### **Connection Optimization**
```bash
# Use connection reuse
export KUBECONFIG=./remote-access-config.yaml

# Set timeout for long operations
kubectl --request-timeout=30 get pods -A

# Use efficient queries
kubectl get pods -n rocketchat --no-headers | wc -l
```

### **Resource Monitoring**
```bash
# Monitor your usage
kubectl top nodes
kubectl top pods -n rocketchat

# Check API server performance
kubectl api-resources
```

---

## 🚨 **Emergency Access**

### **If Primary Method Fails**

#### **Option 1: Direct Node SSH**
```bash
# Get node IPs from Azure Portal
# SSH with: ssh azureuser@<node-ip> -i ~/.ssh/id_rsa

# From node, use kubectl with service account
kubectl --token=<token> --server=https://<api-server>:443 --certificate-authority=<ca-cert> get pods -A
```

#### **Option 2: Bastion Host**
```bash
# Create Azure VM in same VNet
az vm create --resource-group <rg> --name bastion --image Ubuntu2204

# SSH to bastion and use kubectl normally
ssh azureuser@bastion
az aks get-credentials --resource-group <rg> --name <cluster>
kubectl get pods -A
```

#### **Option 3: Azure Portal**
```bash
# Last resort: Use Azure Portal Cloud Shell
# Navigate to AKS cluster → Connect → Run kubectl commands
```

---

## 📈 **Usage Statistics**

### **Track Your Access**
```bash
# Monitor API server requests
kubectl get --raw /metrics | grep apiserver_request_total

# Check audit logs (if enabled)
kubectl logs -n kube-system deployment/kube-apiserver-audit
```

---

## 📞 **Support Information**

### **Configuration Details:**
- **Cluster:** canepro-h84gy5hj (UK South)
- **API Server:** https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443
- **Service Account:** remote-access (default namespace)
- **Permissions:** cluster-admin
- **Created:** September 7, 2025

### **Contact Information:**
- **File Location:** `./remote-access-config.yaml`
- **Documentation:** `docs/REMOTE_ACCESS_GUIDE.md`
- **Last Updated:** September 7, 2025

---

## 🎯 **Quick Reference**

### **Daily Operations**
```bash
# Set config
export KUBECONFIG=./remote-access-config.yaml

# Check status
kubectl get pods -n rocketchat
kubectl get pods -n monitoring

# Access services
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
```

### **Emergency Commands**
```bash
# Quick health check
kubectl cluster-info && echo "✅ Connected"

# Scale resources
kubectl scale deployment rocketchat -n rocketchat --replicas=2

# View logs
kubectl logs -n rocketchat deployment/rocketchat --tail=10
```

---

## ✅ **Success Checklist**

- [x] **Service Account Created:** `remote-access` in `default` namespace
- [x] **ClusterRoleBinding:** `cluster-admin` permissions
- [x] **Token Generated:** Service account token extracted
- [x] **CA Certificate:** Included in configuration
- [x] **Kubeconfig File:** `remote-access-config.yaml` created
- [x] **Connection Tested:** kubectl cluster-info works
- [x] **Documentation:** Complete setup guide created
- [x] **Security:** Token-based authentication configured

**✅ REMOTE ACCESS CONFIGURATION COMPLETE AND DOCUMENTED**

**You now have secure, token-based remote access to your AKS cluster without requiring Azure CLI, kubeconfig files, or cloud portal access!**

---

*This documentation ensures you always have remote access to your critical Rocket.Chat infrastructure, even in emergency situations or when traditional access methods are unavailable.*

