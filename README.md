# 🚀 Rocket.Chat Kubernetes Deployment

**📁 Repository reorganized with separate MicroK8s and AKS deployments**

## Current Status: 🟢 MIGRATION COMPLETE - Production Active on AKS

**✅ Full production migration successful:**
- **Rocket.Chat**: `https://chat.canepro.me` (AKS - SSL ✅)
- **Grafana**: `https://grafana.chat.canepro.me` (AKS - SSL ✅)
- **Monitoring**: Full Prometheus stack running on AKS
- **Backup**: 6,986 documents safely backed up and validated
- **Migration**: DNS successfully migrated from MicroK8s to AKS

**🔧 Recent Achievements:**
- Complete migration from MicroK8s to AKS using official Helm charts
- SSL certificates working for both services
- DNS migration completed successfully
- Production testing validated

## Quick Start

### 1. Choose Your Deployment Path

#### Option A: Official Rocket.Chat Helm Chart (Recommended)
```bash
# Deploy using official Helm chart
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

#### Option B: AKS Interactive Access
```bash
# Test your AKS connection
kubectl get nodes

# Use the interactive shell
./scripts/aks-shell.sh
```

### 2. Review Documentation Structure

#### 📖 Current Documentation
- **[Project Overview](docs/)** - Current status and repository structure
- **[🔧 Troubleshooting](docs/TROUBLESHOOTING_GUIDE.md)** - Comprehensive issue resolution
- **[🌐 DNS Migration](docs/DNS_MIGRATION_GUIDE.md)** - Step-by-step DNS procedure
- **[Future Improvements](docs/FUTURE_IMPROVEMENTS.md)** - Enhancement roadmap

#### 📁 Deployment-Specific Documentation
- **[AKS Deployment Guide](aks/)** - Official Helm chart migration planning
- **[MicroK8s Rollback Guide](microk8s/)** - Legacy deployment (currently active)

### 3. Key Files for Official Deployment
- **`values-official.yaml`** - Official Rocket.Chat Helm chart configuration
- **`values-monitoring.yaml`** - Grafana monitoring configuration
- **`deploy-aks-official.sh`** - Official deployment script
- **`clusterissuer.yaml`** - SSL certificate configuration

## Project Structure

```
rocketchat-k8s-deployment/
├── 📁 aks/                       # AKS migration planning & docs
├── 📁 microk8s/                  # Legacy MicroK8s deployment (rollback)
├── 📁 docs/                      # Current project documentation
├── 📁 scripts/                   # Helper scripts for AKS access
├── 📄 values-official.yaml       # Official Rocket.Chat Helm chart config
├── 📄 values-monitoring.yaml     # Grafana monitoring configuration
├── 📄 clusterissuer.yaml         # SSL certificate configuration
├── 📄 deploy-aks-official.sh     # Official deployment script
├── 📦 mongodb-backup-*.tar.gz    # MongoDB backup (6,986 documents)
└── 📦 app-config-backup-*.tar.gz # Application config backup
```

## Current Status: 🟡 Planning Phase - Official Helm Chart Migration

**✅ Repository Reorganization Complete** - September 4, 2025

### What We Accomplished:
- **📁 Repository Reorganized**: Separate folders for MicroK8s (rollback) and AKS (new)
- **📋 Official Documentation Reviewed**: Aligned with Rocket.Chat official Helm chart
- **🔧 Official Deployment Files Created**: `values-official.yaml`, `values-monitoring.yaml`, `deploy-aks-official.sh`
- **📚 Documentation Structure Updated**: Clear separation of concerns
- **🔒 Full Backup Preserved**: MongoDB (6,986 documents) + Application Config + File Data
- **🛠️ AKS Access Maintained**: Local machine can control Azure AKS cluster remotely

### Current Deployment Status:
- **🟢 MicroK8s (Legacy)**: Running and operational at `https://chat.canepro.me`
- **🟢 AKS (New)**: ✅ **DEPLOYED** - Rocket.Chat and monitoring stack running
- **🟡 SSL Certificates**: Rocket.Chat ✅ READY, Grafana 🔄 ISSUING
- **🔄 Migration Strategy**: Zero-downtime with rollback capability

## 🎯 Our Final Plan: Official Rocket.Chat Helm Chart Deployment

### Phase 1: Prerequisites ✅
- ✅ **Official Documentation**: Reviewed and aligned with Rocket.Chat official docs
- ✅ **Repository Structure**: Clean separation of MicroK8s (rollback) and AKS (new)
- ✅ **Backup Data**: 6,986 documents preserved for migration
- ✅ **AKS Access**: Local machine can control AKS cluster
- ✅ **Domain Setup**: `chat.canepro.me` and `grafana.chat.canepro.me` configured

### Phase 2: Official Deployment (Ready to Execute)
```bash
# One-command deployment using official Helm chart
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

**What this deploys:**
- ✅ **Official Rocket.Chat Helm Chart** from `rocketchat/rocketchat`
- ✅ **Official Monitoring Stack** from `rocketchat/monitoring`
- ✅ **NGINX Ingress Controller** (if not present)
- ✅ **cert-manager** for SSL certificates
- ✅ **Microservices Architecture** for scalability
- ✅ **Production-ready Configuration**

### Phase 3: Data Migration
- **Source**: MicroK8s MongoDB (6,986 documents)
- **Target**: AKS MongoDB replica set
- **Method**: Restore from backup files
- **Downtime**: Minimal (~10-15 minutes)

### Phase 4: DNS Cutover
- **Current**: `chat.canepro.me` → `20.68.53.249` (MicroK8s VM)
- **Target**: `chat.canepro.me` → `[AKS Ingress IP]` (after deployment)
- **Rollback**: Keep MicroK8s VM for 3-5 days

### Phase 5: Enhanced Monitoring (Optional)
- **Azure Monitor Integration** for infrastructure metrics
- **Loki** for centralized logging (Rocket.Chat server logs in Grafana)
- **APM Capabilities** through Azure Monitor
- **Custom Dashboards** and alerts

## 🚀 Current Access Information

### ✅ **AKS Deployment Status:**
- **Rocket.Chat**: `https://chat.canepro.me` ✅ **SSL READY**
- **Grafana**: `https://grafana.chat.canepro.me` 🔄 **SSL ISSUING**

### 🔐 **Login Credentials:**
- **Grafana**: Username: `admin` | Password: `GrafanaAdmin2024!`
- **Rocket.Chat**: Use your existing credentials from MicroK8s deployment

### 📊 **Current Infrastructure:**
- **AKS Cluster**: 3 nodes running
- **Rocket.Chat**: Full microservices architecture deployed
- **MongoDB**: 3-replica set with 50Gi persistent storage
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Ingress**: NGINX with SSL termination

## 🚀 Ready for DNS Migration?

When you're ready to proceed:

1. **Wait for Grafana SSL**: Certificate should be ready soon
2. **Test both services**: Verify Rocket.Chat and Grafana work perfectly
3. **Update DNS**: Point BOTH domains to AKS ingress IP (4.250.169.133)
4. **Restore data**: Follow data migration instructions
5. **Monitor costs**: Stay within £100/month Azure credit

## 🌐 **DNS Migration Strategy**

### **Current Setup (Before Migration):**
```
chat.canepro.me       → 20.68.53.249 (MicroK8s VM)
grafana.chat.canepro.me → 20.68.53.249 (MicroK8s VM)
```

### **Current Setup (Migration Complete):**
```
chat.canepro.me       → 4.250.169.133 (AKS Ingress - PRODUCTION)
grafana.chat.canepro.me → 4.250.169.133 (AKS Ingress - PRODUCTION)
```

### **✅ MIGRATION SUCCESSFUL**
**DNS migration completed successfully on September 5, 2025**

1. **✅ AKS Deployed**: Rocket.Chat and monitoring stack running
2. **✅ SSL Ready**: Both certificates working perfectly
3. **✅ DNS Migrated**: Both domains updated to AKS
4. **✅ Testing Complete**: All functionality validated
5. **✅ Production Active**: AKS is now the live environment
6. **✅ Rollback Ready**: MicroK8s preserved for 3-5 days

### **SSL Certificate Note:**
- If you see certificate errors, check Cloudflare proxy settings
- May need to temporarily set DNS to "DNS only" mode
- Certificate issuance can take 5-10 minutes after DNS changes

### **Emergency Rollback:**
- If issues occur, change DNS back to `20.68.53.249`
- MicroK8s VM stays running for insurance

## 📊 Cost Estimate (Within Your £100/month Azure Credit)

- **AKS Cluster**: ~£50-70/month (3 nodes, standard tier)
- **Premium SSD Storage**: ~£10-15/month (50Gi MongoDB + 30Gi uploads)
- **Azure Monitor**: ~£5-10/month (enhanced monitoring)
- **Total**: ~£65-95/month ✅ (Well within your credit)

## 🛟 Safety Measures

- **Zero Downtime**: Keep MicroK8s running during migration
- **Rollback Ready**: MicroK8s VM preserved for 3-5 days
- **Data Backup**: Full backup validated and ready
- **Domain Continuity**: Same domains throughout migration
- **Cost Control**: Efficient resource allocation

---

**Ready for deployment?** Run `./deploy-aks-official.sh` when you're ready to proceed!

*For detailed documentation, see the [docs/](docs/) folder*
