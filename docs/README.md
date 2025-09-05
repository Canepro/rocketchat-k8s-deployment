# 🚀 Rocket.Chat Kubernetes Deployment Documentation

**Updated**: September 5, 2025
**Current Status**: ✅ DEPLOYMENT COMPLETE - SSL Certificate Phase

This documentation folder contains comprehensive guides for the Rocket.Chat AKS deployment using official Helm charts, alongside legacy MicroK8s deployment documentation for rollback purposes.

## 📚 Documentation Overview

### Core Documentation
- **[PROJECT_HISTORY.md](PROJECT_HISTORY.md)** - Complete chronological history and decisions
- **[PROJECT_STATUS.md](PROJECT_STATUS.md)** - Current status and readiness checklist
- **[DNS_MIGRATION_GUIDE.md](DNS_MIGRATION_GUIDE.md)** - Step-by-step DNS migration procedure
- **[TROUBLESHOOTING_GUIDE.md](TROUBLESHOOTING_GUIDE.md)** - Comprehensive troubleshooting reference
- **[FUTURE_IMPROVEMENTS.md](FUTURE_IMPROVEMENTS.md)** - Post-deployment enhancement roadmap

### Key Status Points
- ✅ **Repository Reorganization**: Clean separation of legacy and new deployments
- ✅ **Official Documentation Alignment**: Following Rocket.Chat's official deployment guide
- ✅ **Deployment Files Ready**: Official Helm chart configurations prepared
- ✅ **AKS Deployment**: Rocket.Chat and monitoring stack successfully deployed
- ✅ **SSL Certificate**: Rocket.Chat SSL certificate issued and working
- ✅ **Clean URLs**: Grafana configured without /grafana path
- ✅ **Backup Validated**: 6,986 documents safely backed up
- ✅ **Rollback Strategy**: MicroK8s preserved for 3-5 day emergency rollback

## 📁 Current Repository Structure

### Root Directory (Official AKS Deployment Ready)
```
rocketchat-k8s-deployment/
├── 📄 values-official.yaml         # Official Rocket.Chat Helm chart config
├── 📄 values-monitoring.yaml       # Official Grafana monitoring config
├── 📄 clusterissuer.yaml           # SSL certificate configuration
├── 📄 deploy-aks-official.sh       # Official deployment script
├── 📦 mongodb-backup-*.tar.gz      # MongoDB backup (6,986 documents)
├── 📦 app-config-backup-*.tar.gz   # Application configuration backup
├── 📁 aks/                        # AKS migration planning & docs
├── 📁 microk8s/                   # Legacy MicroK8s deployment (rollback)
├── 📁 docs/                       # Current documentation
└── 📁 scripts/                    # Helper scripts for AKS access
```

### Documentation Structure
```
docs/                              # Current project documentation
├── 📄 README.md                  # This documentation overview
├── 📚 PROJECT_HISTORY.md         # Complete chronological history
├── 📊 PROJECT_STATUS.md          # Current status & readiness
└── 🚀 FUTURE_IMPROVEMENTS.md     # Post-deployment enhancements

aks/                               # AKS migration planning
├── 📋 MASTER_PLANNING.md         # Complete migration roadmap
├── 📋 MIGRATION_PLAN.md          # Detailed migration process
├── 🌐 DOMAIN_STRATEGY.md         # DNS and SSL strategy
└── 📄 README.md                  # AKS planning overview

microk8s/                         # Legacy deployment (rollback)
├── 📖 DEPLOYMENT_GUIDE.md        # Current MicroK8s setup
├── 📋 PHASE1_STATUS.md           # Backup completion status
├── 📋 PHASE2_STATUS.md           # AKS migration progress
└── 📄 README.md                  # Rollback instructions
```

### Quick Access Links
- **[📚 Project History](PROJECT_HISTORY.md)** - Complete chronological record
- **[📊 Current Status](PROJECT_STATUS.md)** - Readiness and next steps
- **[🚀 Future Plans](FUTURE_IMPROVEMENTS.md)** - Post-deployment roadmap
- **[AKS Planning](../aks/README.md)** - Official deployment strategy
- **[Rollback Guide](../microk8s/README.md)** - Emergency rollback procedures

## 🔒 Backup Status

**Status**: ✅ **Fully Validated and Ready**
- **MongoDB**: 6,986 documents across all collections (341KB compressed)
- **Application Config**: Complete configuration backup (150KB compressed)
- **File Data**: 26K+ uploaded files and media safely backed up
- **Validation**: 100% successful restore testing completed

```bash
# Verify backup integrity
ls -lh ../*-backup-*.tar.gz

# Check MongoDB backup contents
tar -tzf ../mongodb-backup-20250903_231852.tar.gz | head -10

# Check application config backup
tar -tzf ../app-config-backup-20250903_232521.tar.gz | head -10
```

## 📋 Deployment Prerequisites

**Status**: ✅ **All Prerequisites Met**

### Required Components (Already Configured)
- ✅ **AKS Cluster**: Azure Kubernetes Service running and accessible
- ✅ **kubectl**: Configured for AKS cluster access
- ✅ **Helm v3**: Package manager installed and configured
- ✅ **Domain**: `chat.canepro.me` and `grafana.chat.canepro.me` configured
- ✅ **SSL Certificates**: Let's Encrypt with cert-manager
- ✅ **Official Helm Charts**: Rocket.Chat repository added

### Official Deployment Components
Following [Rocket.Chat Official Documentation](https://docs.rocket.chat/docs/deploy-with-kubernetes):

- ✅ **NGINX Ingress Controller**: Handles external traffic
- ✅ **cert-manager**: Manages SSL certificates
- ✅ **Official Rocket.Chat Chart**: `rocketchat/rocketchat`
- ✅ **Official Monitoring Chart**: `rocketchat/monitoring`

## 🔧 Current Configuration Status

**Status**: ✅ **All Configurations Ready**

### Official Configuration Files (Prepared)
- ✅ **`values-official.yaml`**: Official Rocket.Chat Helm chart configuration
  - Domain: `chat.canepro.me`
  - Microservices: Enabled for scalability
  - MongoDB: Replica set configuration
  - SSL: cert-manager integration

- ✅ **`values-monitoring.yaml`**: Official Grafana monitoring configuration
  - Domain: `grafana.chat.canepro.me`
  - Admin credentials: Configured
  - Prometheus integration: Enabled

- ✅ **`clusterissuer.yaml`**: SSL certificate configuration
  - Provider: Let's Encrypt
  - Email: `mogah.vincent@hotmail.com`
  - Domains: Both Rocket.Chat and Grafana

### Ready for Deployment
All configuration files are prepared and validated according to the official Rocket.Chat documentation. No additional configuration changes are required before deployment.

## 🚀 Official Deployment (Ready to Execute)

### One-Command Official Deployment
   ```bash
# Execute official Rocket.Chat deployment on AKS
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

**What this deploys:**
1. **Official Rocket.Chat Helm Chart** (`rocketchat/rocketchat`)
2. **Official Monitoring Stack** (`rocketchat/monitoring`)
3. **NGINX Ingress Controller** for external access
4. **cert-manager** for SSL certificates
5. **Production-ready configuration** with microservices

### Post-Deployment Steps
1. **Restore Data**: Migrate from MicroK8s backup to AKS MongoDB
2. **Update DNS**: Point domains to AKS ingress IP
3. **Test Functionality**: Verify Rocket.Chat and monitoring work
4. **Monitor Performance**: Check resource usage and costs

### Emergency Rollback (If Needed)
   ```bash
# Access rollback guide
cat ../microk8s/README.md
```
- **Current MicroK8s**: Running at `https://chat.canepro.me`
- **Rollback Window**: 3-5 days after AKS deployment
- **Data Preservation**: All data remains intact

## 🌐 **DNS Migration Strategy**

**Status**: ✅ **Planned and Documented**

### **Current DNS Configuration**
```
BEFORE Migration:
├── chat.canepro.me       → 20.68.53.249 (MicroK8s VM)
└── grafana.chat.canepro.me → 20.68.53.249 (MicroK8s VM)
```

### **Target DNS Configuration**
```
AFTER Migration:
├── chat.canepro.me       → 4.250.169.133 (AKS Ingress)
└── grafana.chat.canepro.me → 4.250.169.133 (AKS Ingress)
```

### **Migration Sequence (DO NOT SKIP STEPS)**

#### **Phase 1: Deploy to AKS**
   ```bash
# Deploy official Rocket.Chat to AKS
./deploy-aks-official.sh

# Verify deployment
kubectl get pods -n rocketchat
kubectl get pods -n monitoring
```

#### **Phase 2: Test AKS Deployment**
   ```bash
# Test Rocket.Chat access (temporary)
curl -I http://4.250.169.133

# Test Grafana access (temporary)
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Access: http://localhost:3000 (admin/GrafanaAdmin2024!)
```

#### **Phase 3: DNS Cutover (ONLY AFTER SUCCESSFUL TESTING)**
   ```bash
# Update BOTH domains to point to AKS ingress IP: 4.250.169.133
# DNS Propagation: 5-10 minutes
   ```

#### **Phase 4: Verify Production Access**
   ```bash
# Test production domains
curl -I https://chat.canepro.me
curl -I https://grafana.chat.canepro.me

# Monitor for 30 minutes
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

### **Emergency Rollback Plan**
   ```bash
# If issues occur within 3-5 days:
# Change DNS back to MicroK8s IP: 20.68.53.249
# Keep MicroK8s VM running as insurance
```

### **DNS Update Checklist**
- [ ] AKS deployment successful and tested
- [ ] Rocket.Chat accessible via AKS IP
- [ ] Grafana accessible via AKS IP
- [ ] SSL certificates working
- [ ] Data migration completed
- [ ] Team notified of maintenance window
- [ ] DNS TTL reduced (if possible)
- [ ] Both domains updated simultaneously
- [ ] DNS propagation verified
- [ ] MicroK8s kept as rollback (3-5 days)

## 📊 Official Monitoring Stack

**Status**: ✅ **Configured and Ready**

### Post-Deployment Access
- **Grafana**: `https://grafana.chat.canepro.me` (after DNS update)
- **Username**: `admin`
- **Password**: `GrafanaAdmin2024!`
- **Rocket.Chat Metrics**: Automatically scraped via Prometheus

### Monitoring Features (Official Stack)
- ✅ **Prometheus**: Metrics collection and alerting
- ✅ **Grafana**: Dashboards and visualization
- ✅ **Alertmanager**: Configurable alerts and notifications
- ✅ **Node Exporter**: System-level metrics
- ✅ **Rocket.Chat Integration**: Application-specific metrics

### Future Enhancements
- **Azure Monitor Integration**: Infrastructure monitoring
- **Loki**: Centralized logging for Rocket.Chat server logs
- **Custom Dashboards**: Business intelligence and KPIs

## 🔍 Post-Deployment Operations

### Useful Commands
```bash
# Check deployment status
kubectl get pods -n rocketchat
kubectl get pods -n monitoring

# View Rocket.Chat logs
kubectl logs -f deployment/rocketchat -n rocketchat

# Check ingress and services
kubectl get ingress -n rocketchat
kubectl get ingress -n monitoring
kubectl get svc -n rocketchat
kubectl get svc -n monitoring

# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes
```

### Troubleshooting Resources
- **Official Documentation**: https://docs.rocket.chat/docs/deploy-with-kubernetes
- **AKS Troubleshooting**: Run `./scripts/aks-shell.sh` for interactive access
- **Rollback Guide**: See `../microk8s/README.md` for emergency procedures

## 📚 Key Resources & Documentation

### Official Documentation
- **[Rocket.Chat Official](https://docs.rocket.chat/docs/deploy-with-kubernetes)** - Official deployment guide
- **[Helm Charts](https://github.com/RocketChat/helm-charts)** - Official chart repository
- **[Azure AKS](https://docs.microsoft.com/en-us/azure/aks/)** - AKS documentation

### Project Documentation
- **[📚 Project History](PROJECT_HISTORY.md)** - Complete chronological record
- **[📊 Project Status](PROJECT_STATUS.md)** - Current readiness checklist
- **[🚀 Future Plans](FUTURE_IMPROVEMENTS.md)** - Post-deployment roadmap

### Deployment-Specific Guides
- **[AKS Planning](../aks/README.md)** - Official deployment strategy
- **[Rollback Guide](../microk8s/README.md)** - Emergency rollback procedures

---

## 🎯 Ready for Official Deployment

**Status**: 🟢 **AKS Deployed - Ready for DNS Migration**

### Next Steps
1. **Wait for SSL**: Grafana certificate should be ready soon
2. **Test Services**: Verify Rocket.Chat and Grafana access
3. **Update DNS**: Point domains to AKS ingress (4.250.169.133)
4. **Restore Data**: Migrate from MicroK8s backup
5. **Monitor Costs**: Stay within £100/month Azure credit

### Emergency Rollback
- **MicroK8s Active**: Running at `https://chat.canepro.me`
- **Rollback Window**: 3-5 days after AKS deployment
- **Data Safe**: All backups validated and ready

---

**Documentation Updated**: September 5, 2025
**Next Review**: September 18, 2025 (2 weeks post-deployment)
**Contact**: mogah.vincent@hotmail.com
