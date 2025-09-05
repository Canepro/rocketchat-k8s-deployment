# 🔧 Rocket.Chat AKS Deployment Troubleshooting Guide

**Created**: September 4, 2025
**Last Updated**: September 5, 2025
**Purpose**: Comprehensive troubleshooting guide for Rocket.Chat deployment on Azure Kubernetes Service
**Scope**: Official Helm chart deployment with enhanced monitoring
**Status**: Living document - updated as issues are encountered and resolved
**Current Status**: SSL Certificate issues resolved - AKS deployment complete

---

## 📋 **Guide Overview**

This troubleshooting guide covers common issues encountered during Rocket.Chat deployment on AKS using official Helm charts. Each issue includes:

- **🔍 Symptoms** - How to identify the problem
- **🔍 Diagnosis** - How to investigate root cause
- **🔧 Solutions** - Step-by-step resolution steps
- **🛡️ Prevention** - How to avoid the issue in future

### **Quick Reference**
- [Deployment Issues](#deployment-issues)
- [AKS Cluster Issues](#aks-cluster-issues)
- [Helm Chart Problems](#helm-chart-problems)
- [Network & Ingress Issues](#network--ingress-issues)
- [SSL Certificate Problems](#ssl-certificate-problems)
- [Database Connection Issues](#database-connection-issues)
- [Application Startup Problems](#application-startup-problems)
- [Monitoring Stack Issues](#monitoring-stack-issues)
- [DNS Migration Issues](#dns-migration-issues)
- [Performance Problems](#performance-problems)
- [Cost-Related Issues](#cost-related-issues)

---

## 🚀 **Deployment Issues**

### **Issue 1.1: Helm Deployment Fails**

**Symptoms:**
- `helm install` command fails
- Error messages about resource conflicts
- Chart installation timeout

**Diagnosis:**
```bash
# Check Helm status
helm list --all-namespaces

# Check cluster resources
kubectl get all --all-namespaces

# Check Helm release status
helm status rocketchat -n rocketchat
```

**Solutions:**

**Option A: Clean Previous Installation**
```bash
# Delete previous release
helm uninstall rocketchat -n rocketchat

# Clean up resources
kubectl delete namespace rocketchat --ignore-not-found=true

# Wait for cleanup
sleep 60

# Retry deployment
./deploy-aks-official.sh
```

**Option B: Force Reinstall**
```bash
# Force reinstall
helm install rocketchat rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --values values-official.yaml \
  --wait \
  --timeout=15m \
  --debug
```

**Prevention:**
- Always clean up previous deployments before reinstalling
- Use `--wait` and `--timeout` flags for better error handling
- Check cluster resources before deployment

---

## ☸️ **AKS Cluster Issues**

### **Issue 2.1: kubectl Connection Fails**

**Symptoms:**
- `kubectl get nodes` returns connection errors
- Authentication failures
- Context not found errors

**Diagnosis:**
```bash
# Check kubeconfig
kubectl config current-context

# Test cluster connection
kubectl cluster-info

# Check Azure authentication
az account show
```

**Solutions:**

**Option A: Refresh kubeconfig**
```bash
# Get new kubeconfig from Azure
az aks get-credentials --resource-group <resource-group> --name <cluster-name> --overwrite-existing

# Set correct context
kubectl config use-context <aks-context-name>
```

**Option B: Check Network Connectivity**
```bash
# Test API server connectivity
curl -k https://<aks-api-server>:443/api/v1/

# Check firewall rules
az network nsg rule list --resource-group <rg> --nsg-name <nsg>
```

**Prevention:**
- Regularly refresh kubeconfig (expires every 24-48 hours)
- Store kubeconfig securely, never in version control
- Use Azure CLI authentication instead of static credentials

### **Issue 2.2: Insufficient Cluster Resources**

**Symptoms:**
- Pods stuck in `Pending` state
- `Insufficient cpu/memory` errors
- Node scaling failures

**Diagnosis:**
```bash
# Check node status
kubectl get nodes
kubectl describe nodes

# Check pod events
kubectl get events -n rocketchat
kubectl describe pod <pod-name> -n rocketchat

# Check resource quotas
kubectl get resourcequotas -n rocketchat
```

**Solutions:**

**Option A: Scale Cluster**
```bash
# Scale node pool
az aks scale --resource-group <rg> --name <cluster> --node-count 3

# Or use cluster autoscaler
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

**Option B: Reduce Resource Requests**
```yaml
# In values-official.yaml, reduce requests:
resources:
  requests:
    cpu: 200m      # Reduced from 500m
    memory: 512Mi  # Reduced from 1Gi
  limits:
    cpu: 800m      # Reduced from 1000m
    memory: 1.5Gi  # Reduced from 2Gi
```

**Prevention:**
- Monitor resource usage regularly
- Set appropriate resource requests/limits
- Use cluster autoscaling for variable workloads

---

## 🛠️ **Helm Chart Problems**

### **Issue 3.1: Chart Version Conflicts**

**Symptoms:**
- `chart version not found` errors
- Dependency resolution failures
- Template rendering errors

**Diagnosis:**
```bash
# Check available chart versions
helm search repo rocketchat/rocketchat --versions

# Check current Helm repos
helm repo list
helm repo update

# Validate chart dependencies
helm dependency list
```

**Solutions:**

**Option A: Update Chart Version**
```bash
# Specify exact version
helm install rocketchat rocketchat/rocketchat \
  --version 1.0.0 \
  --namespace rocketchat \
  --values values-official.yaml
```

**Option B: Update Dependencies**
```bash
# Update helm repositories
helm repo update

# Build dependencies
helm dependency build
```

**Prevention:**
- Keep Helm repositories updated
- Pin chart versions for production deployments
- Test chart upgrades in staging environment first

### **Issue 3.2: Template Rendering Errors**

**Symptoms:**
- YAML parsing errors
- Template syntax errors
- Value interpolation failures

**Diagnosis:**
```bash
# Debug template rendering
helm template rocketchat rocketchat/rocketchat --values values-official.yaml

# Check for syntax errors in values file
helm lint values-official.yaml

# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('values-official.yaml'))"
```

**Solutions:**

**Option A: Fix Values File**
```yaml
# Common fixes in values-official.yaml:
# Fix indentation
host: "chat.canepro.me"

# Fix boolean values
microservices:
  enabled: true  # Not "True"

# Fix resource values
resources:
  requests:
    cpu: "500m"  # Use quotes for milli-units
```

**Option B: Use Debug Mode**
```bash
# Install with debug output
helm install rocketchat rocketchat/rocketchat \
  --values values-official.yaml \
  --debug \
  --dry-run
```

**Prevention:**
- Use YAML validators
- Test values files with `helm lint`
- Use `--dry-run` for validation before actual deployment

---

## 🌐 **Network & Ingress Issues**

### **Issue 4.1: Ingress Not Accessible**

**Symptoms:**
- 404 errors when accessing domain
- Ingress shows no backend services
- SSL certificate issues

**Diagnosis:**
```bash
# Check ingress status
kubectl get ingress -n rocketchat
kubectl describe ingress rocketchat-ingress -n rocketchat

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test service connectivity
kubectl get svc -n rocketchat
curl http://<cluster-ip>:3000
```

**Solutions:**

**Option A: Fix Ingress Configuration**
```yaml
# Check values-official.yaml ingress section:
ingress:
  enabled: true
  ingressClassName: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
  tls:
    - secretName: rocketchat-tls
      hosts:
        - chat.canepro.me
```

**Option B: Check Ingress Controller**
```bash
# Verify ingress controller is running
kubectl get svc -n ingress-nginx

# Check for LoadBalancer IP
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Prevention:**
- Verify ingress controller is properly installed
- Use correct ingress class name
- Test ingress configuration with temporary host

### **Issue 4.2: External IP Not Assigned**

**Symptoms:**
- LoadBalancer service stuck in `Pending`
- No external IP assigned to ingress

**Diagnosis:**
```bash
# Check service status
kubectl get svc -n ingress-nginx
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Check Azure load balancer
az network lb list --resource-group <rg>
```

**Solutions:**

**Option A: Check Azure Resource Limits**
```bash
# Check public IP quota
az network public-ip list --resource-group <rg>

# Check load balancer limits
az network lb list --resource-group <rg>
```

**Option B: Recreate Service**
```bash
# Delete and recreate ingress controller
kubectl delete svc ingress-nginx-controller -n ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

**Prevention:**
- Monitor Azure resource quotas
- Use static public IPs for production
- Plan for load balancer limits in large deployments

---

## 🔒 **SSL Certificate Problems**

### **Issue 5.1: Certificate Not Issued**

**Symptoms:**
- HTTP instead of HTTPS
- Certificate shows as `Not Ready`
- Let's Encrypt challenges failing

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificates -n rocketchat
kubectl describe certificate rocketchat-tls -n rocketchat

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check challenge status
kubectl get certificaterequests -n rocketchat
kubectl describe certificaterequest <name> -n rocketchat
```

**Solutions:**

**Option A: Fix DNS Configuration**
```bash
# Verify DNS points to correct IP
nslookup chat.canepro.me
# Should return AKS ingress IP: 4.250.169.133

# Check domain ownership
curl -I http://chat.canepro.me/.well-known/acme-challenge/test
```

**Option B: Check ClusterIssuer**
```yaml
# Verify clusterissuer.yaml is correct:
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: production-cert-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: mogah.vincent@hotmail.com  # Your email
    privateKeySecretRef:
      name: cert-manager-secret-production
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Option C: Recreate Certificate**
```bash
# Delete and recreate certificate
kubectl delete certificate rocketchat-tls -n rocketchat
kubectl apply -f values-official.yaml  # Re-applies certificate
```

**Prevention:**
- Ensure DNS is properly configured before deployment
- Use staging Let's Encrypt for testing
- Monitor certificate expiry dates
- Keep contact email current

### **Issue 5.2: Certificate Expired**

**Symptoms:**
- Browser shows certificate expired
- HTTPS connections fail
- Mixed content warnings

**Diagnosis:**
```bash
# Check certificate expiry
kubectl get certificates -n rocketchat
kubectl describe certificate rocketchat-tls -n rocketchat

# Check renewal status
kubectl get certificaterequests -n rocketchat
```

**Solutions:**

**Option A: Force Renewal**
```bash
# Delete certificate to force renewal
kubectl delete certificate rocketchat-tls -n rocketchat
kubectl delete secret rocketchat-tls -n rocketchat

# Redeploy to recreate
helm upgrade rocketchat rocketchat/rocketchat -n rocketchat -f values-official.yaml
```

**Option B: Check Rate Limits**
```bash
# Let's Encrypt has rate limits - check if exceeded
# Wait 1 hour for rate limit reset
kubectl get certificaterequests -n rocketchat
```

**Prevention:**
- Set up certificate monitoring alerts
- Use staging environment for testing
- Plan certificate renewals before expiry
- Keep backup certificates ready

---

## 🗄️ **Database Connection Issues**

### **Issue 6.1: MongoDB Connection Failed**

**Symptoms:**
- Rocket.Chat pods crash with MongoDB errors
- `MongoNetworkError` or `MongoTimeoutError`
- Application logs show connection failures

**Diagnosis:**
```bash
# Check MongoDB pods
kubectl get pods -n rocketchat | grep mongodb
kubectl logs -n rocketchat <mongodb-pod-name>

# Test MongoDB connectivity
kubectl exec -n rocketchat <mongodb-pod> -- mongo --eval "db.stats()"

# Check MongoDB service
kubectl get svc -n rocketchat | grep mongodb
```

**Solutions:**

**Option A: Check MongoDB Configuration**
```yaml
# Verify values-official.yaml MongoDB section:
mongodb:
  enabled: true
  auth:
    passwords:
      - "rocketchat"  # Must match app config
    rootPassword: "rocketchatroot"
  architecture: "replicaset"
  replicaCount: 3
```

**Option B: Test Internal Connectivity**
```bash
# Test from Rocket.Chat pod
kubectl exec -n rocketchat deployment/rocketchat -- mongo --host mongodb-0.mongodb-headless --eval "db.stats()"

# Check MongoDB replica set status
kubectl exec -n rocketchat <mongodb-pod> -- mongo --eval "rs.status()"
```

**Option C: Restore from Backup**
```bash
# If database is corrupted, restore from backup
kubectl exec -n rocketchat <mongodb-pod> -- mongorestore /path/to/backup/dump
```

**Prevention:**
- Use MongoDB replica sets for high availability
- Monitor MongoDB connection pools
- Implement proper resource limits
- Regular backup testing

### **Issue 6.2: MongoDB Replica Set Issues**

**Symptoms:**
- Replica set not initialized
- Primary election failures
- Replication lag

**Diagnosis:**
```bash
# Check replica set status
kubectl exec -n rocketchat mongodb-0 -- mongo --eval "rs.status()"

# Check MongoDB logs
kubectl logs -n rocketchat mongodb-0

# Verify PVCs are bound
kubectl get pvc -n rocketchat
```

**Solutions:**

**Option A: Initialize Replica Set**
```bash
# Connect to MongoDB and initialize
kubectl exec -n rocketchat mongodb-0 -- mongo --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    {_id: 0, host: 'mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017'},
    {_id: 1, host: 'mongodb-1.mongodb-headless.rocketchat.svc.cluster.local:27017'},
    {_id: 2, host: 'mongodb-2.mongodb-headless.rocketchat.svc.cluster.local:27017'}
  ]
})
"
```

**Option B: Fix PVC Issues**
```bash
# Check PVC status
kubectl get pvc -n rocketchat
kubectl describe pvc <pvc-name> -n rocketchat

# If PVC stuck, delete and recreate
kubectl delete pvc <pvc-name> -n rocketchat
kubectl apply -f values-official.yaml
```

**Prevention:**
- Ensure sufficient storage capacity
- Monitor replica set health
- Use persistent storage for MongoDB
- Plan for replica set maintenance

---

## 🚀 **Application Startup Problems**

### **Issue 7.1: Rocket.Chat Pod Crashes**

**Symptoms:**
- Pods in `CrashLoopBackOff` state
- Container restart loops
- Application startup failures

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n rocketchat
kubectl describe pod <rocketchat-pod> -n rocketchat

# View application logs
kubectl logs -n rocketchat <rocketchat-pod> --previous
kubectl logs -f -n rocketchat <rocketchat-pod>

# Check resource usage
kubectl top pods -n rocketchat
```

**Solutions:**

**Option A: Check Resource Limits**
```yaml
# Adjust resources in values-official.yaml:
resources:
  requests:
    cpu: 300m      # Increase if needed
    memory: 768Mi  # Increase if needed
  limits:
    cpu: 1000m
    memory: 2Gi
```

**Option B: Fix Environment Variables**
```yaml
# Verify environment configuration:
extraEnv:
  - name: NODE_ENV
    value: "production"
  - name: ROOT_URL
    value: "https://chat.canepro.me"
  - name: MONGO_URL
    value: "mongodb://..."
```

**Option C: Check Dependencies**
```bash
# Verify MongoDB is ready
kubectl get pods -n rocketchat | grep mongodb

# Check network connectivity
kubectl exec -n rocketchat <rocketchat-pod> -- ping mongodb-0.mongodb-headless
```

**Prevention:**
- Set appropriate resource limits
- Use liveness/readiness probes
- Monitor application logs regularly
- Implement proper health checks

### **Issue 7.2: Application Performance Issues**

**Symptoms:**
- Slow response times
- High memory usage
- CPU throttling

**Diagnosis:**
```bash
# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes

# Check application metrics
kubectl exec -n rocketchat <rocketchat-pod> -- curl http://localhost:3000/metrics

# Review pod events
kubectl get events -n rocketchat --sort-by=.metadata.creationTimestamp
```

**Solutions:**

**Option A: Optimize Resources**
```yaml
# Adjust resource allocation:
replicaCount: 2  # Increase replicas for load distribution

resources:
  requests:
    cpu: 400m
    memory: 1Gi
  limits:
    cpu: 800m
    memory: 1.5Gi
```

**Option B: Enable Microservices**
```yaml
# Scale microservices in values-official.yaml:
microservices:
  enabled: true
  ddpStreamer:
    replicas: 3  # Scale based on concurrent users
```

**Prevention:**
- Implement horizontal pod autoscaling
- Use performance monitoring tools
- Optimize database queries
- Implement caching strategies

---

## 📊 **Monitoring Stack Issues**

### **Issue 8.1: Grafana Not Accessible**

**Symptoms:**
- Grafana returns 404 or connection errors
- Port-forward doesn't work
- Dashboard not loading

**Diagnosis:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana
kubectl logs -n monitoring <grafana-pod>

# Test service connectivity
kubectl get svc -n monitoring
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

**Solutions:**

**Option A: Check Grafana Configuration**
```yaml
# Verify values-monitoring.yaml:
grafana:
  adminPassword: "GrafanaAdmin2024!"
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    hosts:
      - grafana.chat.canepro.me
```

**Option B: Fix Service Issues**
```bash
# Check service endpoints
kubectl get endpoints -n monitoring prometheus-grafana

# Recreate Grafana deployment
kubectl delete pod <grafana-pod> -n monitoring
```

**Prevention:**
- Verify ingress configuration
- Use correct service types
- Monitor Grafana logs regularly
- Test port-forwarding before DNS changes

### **Issue 8.2: Prometheus Metrics Collection Fails**

**Symptoms:**
- No metrics in Grafana
- Prometheus targets down
- Scraping errors

**Diagnosis:**
```bash
# Check Prometheus status
kubectl get pods -n monitoring | grep prometheus
kubectl logs -n monitoring <prometheus-pod>

# Check service discovery
kubectl get servicemonitors -n monitoring
kubectl get servicemonitors -n rocketchat
```

**Solutions:**

**Option A: Fix ServiceMonitor**
```yaml
# Verify monitoring configuration in values-official.yaml:
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    path: "/metrics"
    port: "http"
```

**Option B: Check Prometheus Configuration**
```bash
# Verify Prometheus can reach targets
kubectl exec -n monitoring <prometheus-pod> -- curl http://rocketchat.rocketchat.svc.cluster.local:3000/metrics
```

**Prevention:**
- Ensure ServiceMonitor annotations are correct
- Test metrics endpoints manually
- Use proper network policies
- Monitor scraping success rates

---

## 🌐 **DNS Migration Issues**

### **Issue 9.1: DNS Propagation Delays**

**Symptoms:**
- Domain still resolves to old IP
- Mixed results from different DNS servers
- Intermittent connectivity

**Diagnosis:**
```bash
# Check DNS propagation globally
nslookup chat.canepro.me 8.8.8.8      # Google DNS
nslookup chat.canepro.me 1.1.1.1      # Cloudflare DNS
nslookup chat.canepro.me 208.67.222.222  # OpenDNS

# Check DNS cache
dig chat.canepro.me @8.8.8.8
```

**Solutions:**

**Option A: Force DNS Cache Flush**
```bash
# Windows DNS flush
ipconfig /flushdns

# Linux DNS flush
sudo systemctl restart systemd-resolved
sudo resolvectl flush-caches
```

**Option B: Reduce TTL Before Migration**
```bash
# Set low TTL 24 hours before migration
# DNS Record Configuration:
# Type: A
# Name: chat
# Value: 4.250.169.133
# TTL: 300 (5 minutes during migration)
```

**Prevention:**
- Plan DNS changes during low-traffic periods
- Reduce TTL 24-48 hours before migration
- Test with multiple DNS resolvers
- Have rollback plan ready

### **Issue 9.2: DNS Migration Rollback**

**Symptoms:**
- Issues after DNS migration
- Need to rollback to MicroK8s
- Emergency rollback required

**Solutions:**

**Immediate Rollback (2 minutes):**
```bash
# Update DNS records back to MicroK8s
# chat.canepro.me → 20.68.53.249
# grafana.chat.canepro.me → 20.68.53.249

# Verify rollback
nslookup chat.canepro.me
# Should return: 20.68.53.249

curl -I https://chat.canepro.me
# Should return: HTTP/2 200
```

**Investigation Steps:**
```bash
# Check AKS deployment status
kubectl get pods -n rocketchat
kubectl logs -f deployment/rocketchat -n rocketchat

# Compare with MicroK8s
# Access MicroK8s at: https://chat.canepro.me
```

**Prevention:**
- Test AKS deployment thoroughly before DNS cutover
- Keep MicroK8s running as backup for 3-5 days
- Have DNS rollback procedure documented
- Monitor application health post-migration

---

## ⚡ **Performance Problems**

### **Issue 10.1: High Resource Usage**

**Symptoms:**
- CPU/memory usage >80%
- Pod restarts due to OOM
- Slow response times

**Diagnosis:**
```bash
# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes

# Check pod resource limits
kubectl get pods -n rocketchat -o jsonpath='{.items[*].spec.containers[*].resources}'

# Review application metrics
kubectl exec -n rocketchat <rocketchat-pod> -- curl http://localhost:3000/metrics
```

**Solutions:**

**Option A: Scale Resources**
```yaml
# Increase resource limits in values-official.yaml:
resources:
  limits:
    cpu: 1500m     # Increased from 1000m
    memory: 3Gi    # Increased from 2Gi
```

**Option B: Scale Horizontally**
```yaml
# Increase replica count:
replicaCount: 3   # Increased from 2

# Scale microservices:
microservices:
  ddpStreamer:
    replicas: 4   # Scale based on concurrent users
```

**Prevention:**
- Implement horizontal pod autoscaling
- Set up resource monitoring alerts
- Use performance profiling tools
- Plan capacity based on expected load

### **Issue 10.2: Network Latency Issues**

**Symptoms:**
- Slow page loads
- WebSocket connection issues
- High latency in user interactions

**Diagnosis:**
```bash
# Test network connectivity
kubectl run test-pod --image=busybox --rm -i --restart=Never -- wget -O- http://rocketchat.rocketchat.svc.cluster.local:3000

# Check ingress controller performance
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Monitor network policies
kubectl get networkpolicies -n rocketchat
```

**Solutions:**

**Option A: Optimize Ingress Configuration**
```yaml
# Improve ingress performance:
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

**Option B: Scale Ingress Controller**
```bash
# Scale ingress controller replicas
kubectl scale deployment ingress-nginx-controller -n ingress-nginx --replicas=2
```

**Prevention:**
- Use CDN for static assets
- Implement connection pooling
- Monitor network latency
- Use appropriate ingress annotations

---

## 💰 **Cost-Related Issues**

### **Issue 11.1: Unexpected Azure Costs**

**Symptoms:**
- Higher than expected Azure bills
- Resource over-provisioning
- Unused resources running

**Diagnosis:**
```bash
# Check current resource usage
kubectl get pods -n rocketchat -o jsonpath='{.items[*].status.containerStatuses[*].resources}'

# Monitor Azure costs
az costmanagement query --type ActualCost --dataset-granularity Daily

# Check for unused resources
kubectl get pvc -n rocketchat  # Check for unused PVCs
kubectl get svc -n rocketchat  # Check for unused services
```

**Solutions:**

**Option A: Optimize Resource Allocation**
```yaml
# Reduce resource requests in values-official.yaml:
resources:
  requests:
    cpu: 200m      # Reduced from 500m
    memory: 512Mi  # Reduced from 1Gi
```

**Option B: Implement Cost Controls**
```bash
# Set up Azure budgets and alerts
az consumption budget create \
  --name rocket-chat-budget \
  --amount 150 \
  --time-grain Monthly \
  --start-date 2025-09-01

# Enable Azure Advisor recommendations
az advisor recommendation list --category Cost
```

**Option C: Clean Up Unused Resources**
```bash
# Remove unused PVCs
kubectl delete pvc <unused-pvc> -n rocketchat

# Scale down when not in use
kubectl scale deployment rocketchat -n rocketchat --replicas=1
```

**Prevention:**
- Set up cost monitoring and alerts
- Use Azure Cost Management regularly
- Implement resource quotas
- Schedule auto-shutdown for non-production hours

---

## 📝 **Issue Reporting Template**

When encountering a new issue, use this template:

### **Issue Summary**
**Date:** YYYY-MM-DD
**Severity:** Critical/High/Medium/Low
**Component:** Rocket.Chat/MongoDB/Monitoring/Ingress/etc.

### **Symptoms**
- Describe what you're observing
- Include error messages
- Note affected functionality

### **Environment**
- AKS version: `kubectl version`
- Helm version: `helm version`
- Rocket.Chat version: Check in values-official.yaml
- Cluster size: Number of nodes

### **Troubleshooting Steps Taken**
- Commands run
- Logs checked
- Configuration verified

### **Resolution**
- Solution implemented
- Files modified
- Commands that resolved the issue

### **Prevention/Follow-up**
- How to prevent this issue
- Monitoring to add
- Documentation updates needed

---

## 🔗 **Useful Resources**

### **Official Documentation**
- [Rocket.Chat Kubernetes Deploy](https://docs.rocket.chat/docs/deploy-with-kubernetes)
- [Helm Charts Repository](https://github.com/RocketChat/helm-charts)
- [AKS Troubleshooting](https://docs.microsoft.com/en-us/azure/aks/troubleshoot)

### **Community Support**
- [Rocket.Chat Forums](https://forums.rocket.chat/)
- [Kubernetes Slack](https://kubernetes.slack.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/rocket.chat)

### **Monitoring Tools**
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)

---

## 📝 **Documented Issues from Current Deployment**

### **Issue: Helm Segmentation Fault (September 4, 2025)**

**Symptoms:**
- `helm version` returns "Segmentation fault"
- `helm repo add` fails with segfault
- Any Helm command crashes immediately

**Root Cause:**
- Corrupted Helm binary installation
- WSL/Windows integration issues
- Version conflicts or missing dependencies

**Resolution Applied:**
```bash
# Remove old Helm installation
sudo rm /usr/local/bin/helm

# Install fresh Helm using official script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version  # Should show v3.18.6
```

**Prevention:**
- Use official Helm installation scripts
- Avoid manual binary downloads
- Regularly check Helm version compatibility

---

### **Issue: Kubernetes Cluster Unreachable (September 4, 2025)**

**Symptoms:**
- `helm install` fails with "Kubernetes cluster unreachable: Get http://localhost:8080/version"
- kubectl works but Helm cannot connect to cluster
- Error shows wrong API server endpoint (localhost:8080 instead of AKS)

**Root Cause:**
- Helm using different kubeconfig than kubectl
- KUBECONFIG environment variable not set
- WSL/Windows kubeconfig path mismatch

**Resolution Applied:**
```bash
# Set KUBECONFIG explicitly
export KUBECONFIG=/mnt/c/Users/i/.kube/config

# Verify kubectl works
kubectl config current-context  # Should show canepro_aks
kubectl cluster-info           # Should connect to AKS

# Test Helm connection
helm list --all-namespaces      # Should work now
```

**Prevention:**
- Always set KUBECONFIG environment variable explicitly
- Use `kubectl config view --minify` to verify correct context
- Ensure consistent kubeconfig paths between kubectl and Helm

---

### **Issue: Missing CRDs for Monitoring Stack (September 4, 2025)**

**Symptoms:**
- `helm install monitoring` fails with "resource mapping not found"
- Errors about missing `monitoring.coreos.com/v1` CRDs
- Grafana CRDs from `grafana.integreatly.org/v1beta1` not found

**Root Cause:**
- Rocket.Chat monitoring chart requires Prometheus Operator CRDs
- kube-prometheus-stack CRDs not installed
- Chart assumes CRDs are pre-installed

**Resolution Applied:**
- Identified CRD requirements from error messages
- Attempted multiple CRD installation methods
- Decided to deploy Rocket.Chat first, add monitoring later

**Alternative Solutions:**
```bash
# Option 1: Install Prometheus Operator CRDs manually
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/

# Option 2: Use Helm to install CRDs
helm install prometheus-operator prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set installCRDs=true

# Option 3: Deploy Rocket.Chat first, monitoring second
helm install rocketchat rocketchat/rocketchat --namespace rocketchat --create-namespace
# Then add monitoring later
```

**Prevention:**
- Always check CRD requirements before chart installation
- Use `--set installCRDs=true` when available
- Deploy core applications before complex monitoring stacks
- Test with `--dry-run` first to identify missing dependencies

---

### **Issue: Chart Repository Connection Issues (September 4, 2025)**

**Symptoms:**
- `helm repo add` works but subsequent commands fail
- Repository becomes unavailable after initial add
- `helm search repo` shows empty results

**Root Cause:**
- Network connectivity issues to GitHub
- Repository cache corruption
- DNS resolution problems in WSL environment

**Resolution Applied:**
- Repository was successfully added and updated
- Chart downloads worked after KUBECONFIG fix
- Connection stabilized after cluster connectivity resolved

**Prevention:**
- Verify network connectivity before Helm operations
- Use `helm repo update` after adding repositories
- Clear Helm cache if repository issues persist: `helm repo remove <name> && helm repo add <name> <url>`

---

### **Issue: Deployment Script Environment Issues (September 4, 2025)**

**Symptoms:**
- Bash scripts fail with path issues
- Environment variables not propagated correctly
- Commands work individually but fail in scripts

**Root Cause:**
- WSL environment variable handling
- Script execution context differences
- Path resolution issues between Windows and WSL

**Resolution Applied:**
- Set KUBECONFIG explicitly in commands
- Use full paths in scripts
- Test commands individually before script execution

**Prevention:**
- Always use explicit environment variables in scripts
- Test commands in interactive shell before scripting
- Use absolute paths for critical operations

---

### **Issue: Resource Quota and Limit Issues (Ongoing)**

**Symptoms:**
- Pods fail with insufficient CPU/memory errors
- Resource quota exceeded messages
- Horizontal scaling failures

**Root Cause:**
- Default AKS resource limits
- Application resource requests too high
- No resource quotas configured

**Prevention Strategies:**
```yaml
# In values-official.yaml, optimize resources:
resources:
  requests:
    cpu: 200m      # Reduced from 500m
    memory: 512Mi  # Reduced from 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes
```

---

### **Issue: SSL Certificate Challenges with Cloudflare (September 4, 2025)**

**Symptoms:**
- Certificate status: `False` (not ready)
- CertificateRequest status: `Waiting on certificate issuance... "pending"`
- Browser shows: `net::ERR_CERT_AUTHORITY_INVALID`
- Let's Encrypt unable to validate domain ownership

**Root Cause:**
- Cloudflare's proxy/CDN interferes with HTTP-01 ACME challenges
- Cloudflare security features block challenge requests
- Domain needs DNS-only mode during certificate issuance

**Resolution Applied:**
```bash
# Cloudflare Configuration Required:
# 1. Set DNS record to "DNS only" (not proxied)
# 2. Disable Cloudflare security features temporarily
# 3. Wait for certificate issuance (5-10 minutes)
# 4. Re-enable proxy and security features
```

**Cloudflare DNS Settings:**
```
Type: A
Name: chat.canepro.me
Value: 4.250.169.133
Proxy Status: DNS only (grey cloud)
TTL: Auto
```

**After Certificate Issues:**
```
Proxy Status: Proxied (orange cloud)
SSL: Full (strict)
Always Use HTTPS: On
```

**Prevention:**
- Temporarily disable Cloudflare proxy during certificate issuance
- Use DNS-only mode for the domain during initial setup
- Monitor certificate expiry and re-issue process
- Keep backup certificates ready

---

### **Issue: Grafana 404 Not Found Error (September 4, 2025)**

**Symptoms:**
- `https://grafana.chat.canepro.me` returns "404 Not Found nginx error"
- Error appears only in incognito browser mode
- Port forwarding to Grafana pod fails or doesn't connect
- Grafana service exists and is running but not accessible via domain

**Diagnosis Steps Taken:**
```bash
# Check ingress configuration
kubectl get ingress monitoring-ingress -n monitoring -o yaml | grep -A 5 "paths:"
# Shows: path: /grafana, backend service: grafana-service

# Check Grafana pod environment variables
kubectl describe pod grafana-deployment-774dff4b6c-rrsdd -n monitoring
# Shows:
# GF_SERVER_SERVE_FROM_SUB_PATH: true
# GF_SERVER_ROOT_URL: https://grafana.chat.canepro.me/grafana/

# Check ingress path configuration
kubectl get ingress monitoring-ingress -n monitoring -o yaml | grep -A 20 "paths:"
# Shows: path: /grafana, pathType: Prefix

# Attempt port forwarding (multiple attempts)
kubectl port-forward svc/grafana-service -n monitoring 3001:3000 --address 0.0.0.0
curl -I http://localhost:3001/grafana  # Connection refused
curl -I http://4.250.169.133:3001/grafana  # Connection timeout
```

**Current Configuration:**
```yaml
# Ingress configuration (values-monitoring.yaml)
ingress:
  enabled: true
  ingressClassName: "nginx"
  tls: true
  grafana:
    enabled: true
    host: "grafana.chat.canepro.me"
    path: "/grafana"

# Grafana deployment environment
GF_SERVER_SERVE_FROM_SUB_PATH: true
GF_SERVER_ROOT_URL: https://grafana.chat.canepro.me/grafana/
POD_IP: (v1:status.podIP)
```

**Root Cause Analysis:**
- Ingress is correctly configured with path `/grafana`
- Grafana is configured to serve from subpath `/grafana`
- Grafana pod is running and healthy
- Port forwarding attempts are failing, indicating service connectivity issues
- The 404 error suggests the request is reaching nginx but not being routed correctly

**Potential Issues:**
1. **Service Configuration**: `grafana-service` might not be properly configured
2. **Port Mapping**: Service port mapping might be incorrect
3. **Network Policies**: Network policies might be blocking traffic
4. **Endpoint Issues**: Service endpoints might not be properly registered
5. **Browser Cache**: Incognito mode behavior suggests cache-related issues

**Next Steps to Investigate:**
```bash
# Check service endpoints
kubectl get endpoints -n monitoring grafana-service

# Check service detailed configuration
kubectl describe svc grafana-service -n monitoring

# Check network policies
kubectl get networkpolicies -n monitoring

# Test direct pod access
kubectl exec -n monitoring grafana-deployment-774dff4b6c-rrsdd -- curl -I http://localhost:3000

# Check Grafana logs for errors
kubectl logs -n monitoring grafana-deployment-774dff4b6c-rrsdd --tail=50
```

**Latest Findings (September 5, 2025):**
- Service endpoints are properly registered: `10.244.0.72:3000`
- Ingress configuration is correct with path `/grafana`
- Port forwarding attempts are failing, suggesting network connectivity issues
- Both incognito and regular browsers show different behaviors, indicating potential caching or certificate-related issues

**Next Steps:**
```bash
# Test direct pod connectivity
kubectl exec -n monitoring grafana-deployment-774dff4b6c-rrsdd -- curl -I http://localhost:3000

# Check for network policies blocking traffic
kubectl get networkpolicies -n monitoring

# Verify ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50 | grep grafana
```

**Status:** Service endpoints confirmed working - investigating ingress routing and SSL certificate issues

**SSL Certificate Issues - RESOLVED (September 5, 2025):**
- **✅ SUCCESS**: Rocket.Chat SSL certificate issued successfully
- **Order Status**: `valid` (112m)
- **Certificate Status**: `True` (ready)
- **Rocket.Chat Access**: ✅ HTTPS working with valid SSL certificate
- **Grafana Status**: Certificate created, TLS configuration added to ingress
- **Next Steps**: Test Grafana access and perform DNS migration

### **Additional SSL Certificate Resolution Notes:**

**Issue: Grafana Certificate Still Pending**
- **Symptom**: Grafana certificate shows `False` status 20+ minutes after creation
- **Root Cause**: Normal behavior for newly created certificates - Let's Encrypt needs time to issue
- **Resolution**: Wait 5-10 minutes for certificate to be issued
- **Prevention**: Monitor certificate status with `kubectl get certificates -n monitoring -w`

**Issue: Clean URL Configuration**
- **Symptom**: Grafana accessible at `https://grafana.chat.canepro.me/grafana` (unwanted path)
- **Root Cause**: Ingress configured with `/grafana` path instead of root `/`
- **Resolution**: Updated ingress path and restarted Grafana deployment
- **Result**: Now accessible at clean URL `https://grafana.chat.canepro.me`
- **Prevention**: Plan URL structure during initial configuration

---

## 🎯 **Deployment Best Practices Learned**

### **1. Environment Setup**
- Always set `KUBECONFIG` explicitly
- Verify cluster connectivity before Helm operations
- Use official installation methods for tools

### **2. Chart Installation Order**
- Install CRDs before charts that require them
- Deploy core applications before monitoring
- Use `--dry-run` to validate configurations

### **3. Troubleshooting Approach**
- Start with basic connectivity tests
- Check kubeconfig consistency
- Verify resource availability
- Use `--debug` flag for detailed error information

### **4. Documentation Importance**
- Document every issue encountered and resolution
- Update troubleshooting guide with new findings
- Maintain deployment logs for future reference

---

**Document Version:** 1.1
**Last Updated:** September 4, 2025
**Next Review:** September 18, 2025 (post-deployment)
**Owner:** Vincent Mogah
**Contact:** mogah.vincent@hotmail.com

---

*This troubleshooting guide now includes real-world issues encountered during the September 2025 AKS deployment. Continue updating with new issues and solutions.*
