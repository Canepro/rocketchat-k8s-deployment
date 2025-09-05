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
2. **✅ Monitoring Stack**: `rocketchat/monitoring` deployed
3. **✅ Rocket.Chat**: `rocketchat/rocketchat` with official chart deployed
4. **✅ Prerequisites**: NGINX ingress, cert-manager configured
5. **🟡 SSL Certificates**: Rocket.Chat ✅ READY, Grafana 🔄 ISSUING

**Configuration Files Ready:**
- `../values-official.yaml` - Official Rocket.Chat configuration
- `../values-monitoring.yaml` - Official Grafana monitoring
- `../clusterissuer.yaml` - SSL certificate configuration

### Phase 3: DNS Migration & Cutover

#### **Current DNS Configuration:**
```
BEFORE Migration:
├── chat.canepro.me       → 20.68.53.249 (MicroK8s VM)
└── grafana.chat.canepro.me → 20.68.53.249 (MicroK8s VM)
```

#### **Target DNS Configuration:**
```
AFTER Migration:
├── chat.canepro.me       → 4.250.169.133 (AKS Ingress)
└── grafana.chat.canepro.me → 4.250.169.133 (AKS Ingress)
```

#### **Migration Steps:**
1. **Test AKS Deployment First:**
   ```bash
   # Test Rocket.Chat
   curl -I http://4.250.169.133

   # Test Grafana (temporary access)
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   # Access: http://localhost:3000
   ```

2. **Update DNS Records:**
   - Change BOTH domains to point to `4.250.169.133`
   - DNS propagation takes 5-10 minutes

3. **Verify Production Access:**
   ```bash
   curl -I https://chat.canepro.me
   curl -I https://grafana.chat.canepro.me
   ```

### Phase 4: Enhanced Observability (Optional)
- Azure Monitor integration
- Loki for centralized logging
- APM capabilities
- Custom dashboards

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

**Last Updated**: September 5, 2025
**Status**: 🟢 AKS Deployed - Ready for DNS Migration
