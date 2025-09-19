# 🚀 AKS Rocket.Chat Deployment (New)

This folder contains the AKS migration planning and documentation. This is our target deployment using the official Rocket.Chat Helm chart with enhanced observability.

## 📁 Contents

### Migration Planning
- `AKS_SETUP_GUIDE.md` - AKS cluster setup and access
- `MASTER_PLANNING.md` - Complete migration roadmap
- `MIGRATION_PLAN.md` - Detailed 15-step migration process
- `DOMAIN_STRATEGY.md` - DNS and SSL migration planning

## 🎯 Current Plan

### Phase 1: Prerequisites ✅
- ✅ Domain: `chat.canepro.me` and `grafana.chat.canepro.me`
- ✅ AKS cluster: Ready for deployment
- ✅ Helm v3: Available
- ✅ Backup: 6,986 documents + all configurations

### Phase 2: Official Helm Chart Deployment ✅ COMPLETED
Based on [Rocket.Chat Official Documentation](https://docs.rocket.chat/docs/deploy-with-kubernetes):

**One-Command Deployment:**
```bash
chmod +x ../deploy-aks-official.sh
../deploy-aks-official.sh
```

**What was deployed:**
1. **✅ Official Helm Repository**: Added and updated
2. **✅ Monitoring Stack**: `kube-prometheus-stack` deployed
3. **✅ Rocket.Chat**: `rocketchat/rocketchat` with official chart deployed
4. **✅ Prerequisites**: NGINX ingress, cert-manager configured
5. **🟢 SSL Certificates**: Rocket.Chat ✅ READY, Grafana ✅ READY

**Configuration Files Ready:**
- `../values-official.yaml` - Official Rocket.Chat configuration
- `../values-monitoring.yaml` - Official Grafana monitoring (uses Secret for admin)
- `../clusterissuer.yaml` - SSL certificate configuration (production + staging)

### Important Post-Deploy Adjustments
- Prometheus updated to discover `monitoring` and `rocketchat` namespaces.
- Promtail switched to Kubernetes pod discovery.
- Disabled duplicate ServiceMonitor/Grafana/Prometheus in Rocket.Chat chart values.

### Phase 3: DNS Migration & Cutover

#### **Current DNS Configuration (Migration Complete):**
```
PRODUCTION ACTIVE (AKS):
├── chat.canepro.me       → 4.250.169.133 (AKS Ingress)
└── grafana.chat.canepro.me → 4.250.169.133 (AKS Ingress)
```

#### **Rollback DNS Configuration (Available for 3-5 days):**
```
LEGACY MicroK8s (Emergency Rollback):
├── chat.canepro.me       → 20.68.53.249 (MicroK8s VM)
└── grafana.chat.canepro.me → 20.68.53.249 (MicroK8s VM)
```

#### **Production Verification (Migration Complete):**
1. **Verify Production Access:**
   ```bash
   # Test Rocket.Chat
   curl -I https://chat.canepro.me

   # Test Grafana
   curl -I https://grafana.chat.canepro.me

   # Check SSL certificates
   curl -v https://chat.canepro.me 2>&1 | grep -E "(subject:|issuer:)"
   curl -v https://grafana.chat.canepro.me 2>&1 | grep -E "(subject:|issuer:)"
   ```

2. **Verify Kubernetes Services:**
   ```bash
   # Check all pods running
   kubectl get pods -n rocketchat
   kubectl get pods -n monitoring

   # Check ingress resources
   kubectl get ingress -n rocketchat
   kubectl get ingress -n monitoring

   # Check SSL certificates
   kubectl get certificates -n rocketchat
   kubectl get certificates -n monitoring
   ```

### Phase 4: Enhanced Observability ✅ COMPLETE
- ✅ **Prometheus Metrics**: Real-time application and infrastructure metrics
- ✅ **Loki Logging**: Centralized logging with LogQL queries
- ✅ **Custom Dashboards**: Rocket.Chat production monitoring dashboard
- ✅ **SSL Certificates**: Automated certificate management for both services
- ✅ **Full Observability**: Complete monitoring stack operational

### Recent Issues Resolved (September 19, 2025) ✅
- ✅ **PVC Deadlock**: Fixed Rocket.Chat pods stuck in Pending due to terminating PVC
- ✅ **Enterprise License**: Resolved Rocket.Chat EE license causing DDP streamer crashes
- ✅ **Grafana 404**: Created missing ingress for Grafana external access
- ✅ **Grafana Authentication**: Fixed 401 errors by resetting admin password
- ✅ **MongoDB Connections**: Resolved environment variable conflicts
- ✅ **Comprehensive Documentation**: Updated TROUBLESHOOTING_GUIDE.md with all solutions

## 🔄 Migration Strategy

- **Zero Downtime**: Keep MicroK8s as backup during migration
- **Data Preservation**: Restore all existing data
- **Domain Continuity**: Same domains throughout migration
- **Rollback Ready**: MicroK8s VM kept for 3-5 days

## 📊 Success Criteria

- ✅ Rocket.Chat accessible at `https://chat.canepro.me`
- ✅ Grafana accessible at `https://grafana.chat.canepro.me`
- ✅ All user data migrated successfully
- ✅ Enhanced monitoring active
- ✅ Cost-effective within £100/month Azure credit

---

**Last Updated**: September 19, 2025
**Status**: 🟢 PRODUCTION ACTIVE - Migration Complete, All Issues Resolved
