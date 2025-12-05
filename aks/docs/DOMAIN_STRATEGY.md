# 🌐 Domain Strategy: Rocket.Chat Migration

## Current Domain Configuration

### Active Domains
- **Rocket.Chat**: `<YOUR_DOMAIN>` ✅
- **Grafana**: `grafana.<YOUR_DOMAIN>` ✅
- **SSL**: Let's Encrypt certificates via cert-manager
- **DNS**: A records pointing to MicroK8s VM

### Current Setup Details
```yaml
# Rocket.Chat Ingress (MicroK8s)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketchat
  namespace: rocketchat
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: public
  tls:
  - hosts:
    - <YOUR_DOMAIN>
    secretName: rocketchat-tls
  rules:
  - host: <YOUR_DOMAIN>
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocketchat
            port:
              number: 80

# Grafana Ingress (MicroK8s)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: public
  tls:
  - hosts:
    - grafana.<YOUR_DOMAIN>
    secretName: grafana-tls
  rules:
  - host: grafana.<YOUR_DOMAIN>
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
```

## Migration Domain Strategy

### Phase 1: Parallel Operation (Zero Downtime)
**Goal**: Keep current domains working during migration

#### DNS Configuration During Migration
```
Current Setup (MicroK8s):
<YOUR_DOMAIN>       → 20.68.53.249 (VM Public IP)
grafana.<YOUR_DOMAIN> → 20.68.53.249 (VM Public IP)

Migration Setup (Parallel):
<YOUR_DOMAIN>       → 20.68.53.249 (VM Public IP) - PRIMARY
grafana.<YOUR_DOMAIN> → 20.68.53.249 (VM Public IP) - PRIMARY
chat-aks.canepro.me  → [AKS Ingress IP] - TESTING ONLY
grafana-aks.canepro.me → [AKS Ingress IP] - TESTING ONLY
```

#### Certificate Strategy
- **Keep current certificates active** on MicroK8s
- **Create new certificates** for AKS testing domains
- **Preserve SSL continuity** during cutover

### Phase 2: DNS Cutover (Instant Switching)
**Goal**: Switch traffic with minimal disruption

#### Cutover DNS Configuration
```
Post-Migration (AKS):
<YOUR_DOMAIN>       → [AKS Ingress IP] - PRIMARY
grafana.<YOUR_DOMAIN> → [AKS Ingress IP] - PRIMARY

Backup (Rollback):
chat-microk8s.canepro.me → 20.68.53.249 - BACKUP
grafana-microk8s.canepro.me → 20.68.53.249 - BACKUP
```

#### SSL Certificate Migration
```yaml
# AKS Certificate Configuration
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: production-cert-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: cert-manager-secret-production
    solvers:
    - http01:
        ingress:
          class: nginx

# AKS Ingress Configuration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketchat
  namespace: rocketchat
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - <YOUR_DOMAIN>
    secretName: rocketchat-tls
  rules:
  - host: <YOUR_DOMAIN>
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocketchat
            port:
              number: 80
```

## Consolidated Grafana Vision

### Your Idea: `<YOUR_GRAFANA_DOMAIN>`
**Unified monitoring domain** that encompasses everything:

#### Subdomain Strategy
```
<YOUR_GRAFANA_DOMAIN>/microk8s → Current MicroK8s metrics (during migration)
<YOUR_GRAFANA_DOMAIN>/aks      → AKS deployment metrics
<YOUR_GRAFANA_DOMAIN>/azure    → Azure infrastructure metrics
<YOUR_GRAFANA_DOMAIN>/unified  → Combined dashboard
```

#### Implementation Approach
```yaml
# NGINX Ingress for Subdomain Routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-unified
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - <YOUR_GRAFANA_DOMAIN>
    secretName: grafana-unified-tls
  rules:
  - host: <YOUR_GRAFANA_DOMAIN>
    http:
      paths:
      - path: /microk8s
        pathType: Prefix
        backend:
          service:
            name: grafana-microk8s
            port:
              number: 3000
      - path: /aks
        pathType: Prefix
        backend:
          service:
            name: grafana-aks
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana-unified
            port:
              number: 3000
```

### Azure Integration
- **Azure Monitor**: Infrastructure metrics
- **Log Analytics**: Centralized logging
- **Application Insights**: Application performance
- **Azure Dashboards**: Infrastructure monitoring

## DNS Management Procedures

### Pre-Migration DNS Setup
```bash
# Verify current DNS configuration
nslookup <YOUR_DOMAIN>
nslookup grafana.<YOUR_DOMAIN>

# Expected output: 20.68.53.249 (your VM IP)

# Create test subdomains for AKS
# chat-aks.canepro.me → AKS ingress IP
# grafana-aks.canepro.me → AKS ingress IP
```

### DNS Cutover Procedure
```bash
# Step 1: Get AKS ingress IP
AKS_INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Step 2: Update DNS records
# Update A records:
# <YOUR_DOMAIN> → $AKS_INGRESS_IP
# grafana.<YOUR_DOMAIN> → $AKS_INGRESS_IP

# Step 3: Wait for DNS propagation (5-10 minutes)
nslookup <YOUR_DOMAIN>  # Should return AKS IP

# Step 4: Verify services
curl -I https://<YOUR_DOMAIN>
curl -I https://grafana.<YOUR_DOMAIN>

# Step 5: Monitor for 30 minutes
kubectl logs -f deployment/nginx-ingress-controller -n ingress-nginx
```

### Rollback DNS Procedure
```bash
# Emergency rollback (< 5 minutes)
# Update DNS records back to VM IP:
# <YOUR_DOMAIN> → 20.68.53.249
# grafana.<YOUR_DOMAIN> → 20.68.53.249

# Verify rollback
curl -I https://<YOUR_DOMAIN>  # Should work on MicroK8s
```

## SSL Certificate Strategy

### Certificate Lifecycle
1. **Current Certificates**: Remain active on MicroK8s
2. **AKS Certificates**: New certificates for test domains
3. **Production Certificates**: Migrated during cutover
4. **Backup Certificates**: Available for rollback

### Certificate Migration Steps
```bash
# 1. Export current certificates from MicroK8s
kubectl get secret rocketchat-tls -n rocketchat -o yaml > rocketchat-tls-backup.yaml
kubectl get secret grafana-tls -n monitoring -o yaml > grafana-tls-backup.yaml

# 2. Create certificates on AKS
kubectl apply -f clusterissuer.yaml  # Same issuer configuration

# 3. Verify certificate creation
kubectl get certificaterequests -A
kubectl get certificates -A

# 4. Test SSL connectivity
openssl s_client -connect <YOUR_DOMAIN>:443 -servername <YOUR_DOMAIN>
```

## Remote Access Integration

### Domain-Based Access
```bash
# Direct domain access (post-migration)
kubectl config set-cluster aks-cluster \
  --server=https://<YOUR_DOMAIN> \
  --insecure-skip-tls-verify=true

# Secure access with certificates
kubectl config set-cluster aks-cluster \
  --server=https://<YOUR_DOMAIN> \
  --certificate-authority=/path/to/ca.crt \
  --embed-certs=true
```

### SSH Tunnel Access
```bash
# Access AKS through SSH tunnel to VM
ssh -L 6443:aks-api-server:6443 user@vm-ip
kubectl config set-cluster aks-tunnel \
  --server=https://localhost:6443
```

## Monitoring & Alerting

### Domain Health Monitoring
```yaml
# Prometheus alert rules for domain monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: domain-health
  namespace: monitoring
spec:
  groups:
  - name: domain.alerts
    rules:
    - alert: DomainUnreachable
      expr: probe_success{job="blackbox"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Domain is unreachable"
        description: "{{ $labels.instance }} is down"
```

### SSL Certificate Monitoring
```yaml
# Certificate expiry monitoring
- alert: SSLCertExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds < time() + 86400 * 30
  for: 24h
  labels:
    severity: warning
  annotations:
    summary: "SSL certificate expiring soon"
    description: "{{ $labels.name }} expires in {{ $value | humanizeDuration }}"
```

## Testing Strategy

### Domain Testing Checklist
- [ ] DNS resolution working
- [ ] SSL certificates valid
- [ ] HTTP to HTTPS redirect working
- [ ] Application accessible
- [ ] Performance acceptable
- [ ] Mobile access working

### Load Testing
```bash
# Test domain performance
ab -n 1000 -c 10 https://<YOUR_DOMAIN>/
hey -n 1000 -c 10 https://grafana.<YOUR_DOMAIN>/

# Monitor response times
kubectl logs -f deployment/nginx-ingress-controller -n ingress-nginx
```

## Cost Optimization

### DNS Costs
- **Azure DNS**: ~$0.50 per million queries
- **Cloudflare**: Free tier available
- **Route 53**: Pay per hosted zone

### SSL Certificate Costs
- **Let's Encrypt**: Free
- **Azure Key Vault**: ~$0.03 per certificate/month
- **Certificate Manager**: Included with AKS

## Future Considerations

### Advanced Domain Features
- **CDN Integration**: Azure CDN for global performance
- **WAF**: Web Application Firewall protection
- **DDoS Protection**: Azure DDoS Protection Standard
- **Custom Domains**: Additional domains for different environments

### Multi-Region Strategy
```
Production: <YOUR_DOMAIN> → East US
DR:        chat-dr.canepro.me → West US
Staging:   chat-staging.canepro.me → East US 2
```

### Automated DNS Management
- **External DNS**: Automatic DNS record management
- **Terraform**: Infrastructure as Code for DNS
- **CI/CD Integration**: Automated domain updates

## Implementation Timeline

### Week 1: Domain Assessment
- [ ] Document current DNS configuration
- [ ] Verify SSL certificate status
- [ ] Test domain performance baselines
- [ ] Plan subdomain strategy

### Week 2: Parallel Setup
- [ ] Create test subdomains for AKS
- [ ] Set up SSL certificates for AKS
- [ ] Configure ingress controllers
- [ ] Test parallel domain access

### Week 3: Migration & Cutover
- [ ] Execute DNS cutover procedures
- [ ] Monitor domain health
- [ ] Update documentation
- [ ] Optimize configurations

---

**Domain Strategy Version**: 1.0
**Last Updated**: Current Date
**Domains Managed**:
- ✅ <YOUR_DOMAIN> (Rocket.Chat)
- ✅ grafana.<YOUR_DOMAIN> (Monitoring)
- ✅ <YOUR_GRAFANA_DOMAIN> (Unified - Future)
**SSL Provider**: Let's Encrypt
**DNS Provider**: [Your DNS Provider]
