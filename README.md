# 🚀 Rocket.Chat Kubernetes Deployment

**📁 Repository reorganized with clean structure and enhanced monitoring**

## Current Status: 🟢 PRODUCTION ACTIVE - Enhanced Monitoring Complete! ✅

**✅ Phase 1 Complete - Production Migration Successful:**
- **Rocket.Chat**: `https://chat.canepro.me` (AKS - SSL ✅)
- **Grafana**: `https://grafana.chat.canepro.me` (AKS - SSL ✅)
- **Monitoring**: Full Prometheus stack running on AKS
- **Backup**: 6,986 documents safely backed up and validated
- **Migration**: DNS successfully migrated from MicroK8s to AKS

**✅ Phase 2 Complete - Enhanced Monitoring Setup:**
- **Custom Dashboards**: Rocket.Chat production monitoring dashboard active ✅
- **Metrics Collection**: PodMonitor fixed, ServiceMonitor conflicts resolved ✅
- **Log Storage**: Loki persistence enabled (50Gi storage) ✅
- **Centralized Logging**: Promtail → Loki → Grafana pipeline working ✅
- **Observability**: Full application monitoring and logging operational ✅

**✅ Phase 3 Complete - Repository Cleanup:**
- **Clean Structure**: Files organized into logical directories ✅
- **Removed Scripts**: Unnecessary automation scripts cleaned up ✅
- **Updated Paths**: All configurations updated for new structure ✅
- **Documentation**: Comprehensive guides and troubleshooting ✅

## Quick Start

## 🎯 Quick Deployment

### AKS Deployment (Production)

```bash
cd aks/deployment
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

### ⚠️ If MongoDB images fail to pull (Bitnami brownout)

Bitnami temporarily browned out MongoDB images (Sept 17–19, 2025). If you see ImagePullBackOff for MongoDB:

1) Deploy the standalone MongoDB (official image) and initialize the replica set
```bash
kubectl apply -f aks/config/mongodb-standalone.yaml
```

2) Install/upgrade Rocket.Chat with `aks/config/helm-values/values-official.yaml` (Mongo subchart disabled; external MongoDB URLs provided)

3) Optional helper script
```bash
chmod +x aks/scripts/deploy-mongodb-standalone.sh
aks/scripts/deploy-mongodb-standalone.sh
```

See the troubleshooting entry for details and verification steps:
docs/TROUBLESHOOTING_GUIDE.md#issue-bitnami-mongodb-brownout---images-unavailable-september-17-19-2025

### MicroK8s Deployment (Legacy/Rollback)

See `microk8s/docs/` for MicroK8s deployment instructions.

### Configuration Files

Files are organized by environment:
- **AKS**: `aks/config/`, `aks/monitoring/`, `aks/scripts/`
- **MicroK8s**: `microk8s/config/`, `microk8s/monitoring/`, `microk8s/scripts/`

### 2. Access Your Services

- **Rocket.Chat**: `https://chat.canepro.me`
- **Grafana**: `https://grafana.chat.canepro.me`
  - Username: `admin`
  - Password: `prom-operator`

### 3. Check Logs with Loki

In Grafana, go to **Explore** and use these LogQL queries:
```logql
{namespace="rocketchat"}                    # All Rocket.Chat logs
{app="mongodb"} |= "ERROR"                  # MongoDB errors only
{container="rocketchat"} | json             # Structured log view
```

## Repository Structure

```
📁 aks/                       # Azure Kubernetes Service (Production)
├── 📁 config/                # AKS configuration files
│   ├── certificates/         # SSL certificate configs
│   └── helm-values/          # Helm chart values
├── 📁 deployment/            # AKS deployment scripts
├── 📁 monitoring/            # AKS monitoring configs
├── 📁 scripts/               # AKS utility scripts
└── 📁 docs/                  # AKS documentation

📁 microk8s/                  # MicroK8s (Legacy/Rollback)
├── 📁 config/                # MicroK8s configurations
├── 📁 monitoring/            # MicroK8s monitoring
├── 📁 scripts/               # MicroK8s scripts
└── 📁 docs/                  # MicroK8s documentation

📁 docs/                      # Common documentation
├── TROUBLESHOOTING_GUIDE.md  # General troubleshooting
├── PROJECT_STATUS.md         # Overall project status
└── [other guides]            # Shared documentation
```

*See [STRUCTURE.md](STRUCTURE.md) for complete directory details*

## Current Infrastructure

**✅ AKS Production Environment:**
- **Cluster**: 3-node AKS cluster running in Azure
- **Rocket.Chat**: Microservices architecture with MongoDB replica set
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Storage**: 50Gi persistent storage for MongoDB and uploads
- **SSL**: Automated certificate management via cert-manager
- **Ingress**: NGINX Ingress Controller with LoadBalancer

**🔐 Login Credentials:**
- **Grafana**: Username: `admin` | Password: `prom-operator`
- **Rocket.Chat**: Use your existing credentials from backup

**📊 Monitoring Features:**
- **Metrics**: Real-time application and infrastructure metrics
- **Logs**: Centralized logging with Loki and LogQL queries
- **Dashboards**: Custom Rocket.Chat monitoring dashboards
- **Alerts**: Automated alerting for critical issues
- **Observability**: Complete application performance monitoring

## 🚀 Cost Optimization

**Monthly Azure Costs (Within £100 credit):**
- **AKS Cluster**: ~£50-70/month (3 standard nodes)
- **Storage**: ~£10-15/month (Premium SSD)
- **Networking**: ~£5-10/month (Load balancers)
- **Total**: ~£65-95/month ✅

## 📖 Documentation

- **[📁 Repository Structure](STRUCTURE.md)** - Complete directory layout
- **[🔧 Troubleshooting](docs/TROUBLESHOOTING_GUIDE.md)** - Issue resolution
- **[📊 Loki Queries](docs/loki-query-guide.md)** - Log analysis examples
- **[📈 Project Status](docs/PROJECT_STATUS.md)** - Current deployment status
- **[🔄 Migration Guide](docs/DNS_MIGRATION_GUIDE.md)** - DNS migration procedures

## �️ Maintenance & Updates

**Regular Tasks:**
- Monitor Azure costs in portal
- Check certificate renewals (automatic)
- Review Grafana dashboards for alerts
- Backup MongoDB data periodically

**Updating Rocket.Chat:**
```bash
cd deployment
helm upgrade rocketchat -f ../config/helm-values/values-official.yaml rocketchat/rocketchat -n rocketchat
```

**Scaling Resources:**
```bash
kubectl scale deployment rocketchat -n rocketchat --replicas=3
```

## 🚨 Emergency Procedures

**Rollback Capability:**
- MicroK8s VM preserved at `20.68.53.249` for emergency rollback
- Change DNS back to MicroK8s IP if issues occur
- Full data backup available for restoration

**Support Resources:**
- Azure Support Portal for infrastructure issues
- Rocket.Chat official documentation
- Kubernetes troubleshooting guides in `docs/`

---

**🎯 Next Steps:**
1. **Monitor Performance** - Use Grafana dashboards
2. **Review Logs** - Check Loki for any application issues  
3. **Cost Management** - Monitor Azure spend monthly
4. **Data Backup** - Schedule regular MongoDB backups

*For detailed setup and troubleshooting, see the [docs/](docs/) directory*

## 🔐 **Remote Access**
**Emergency remote access without Azure CLI or cloud portals:**
- 📖 **[Remote Access Guide](docs/REMOTE_ACCESS_GUIDE.md)** - Service account token method
- 📁 **Config File:** `remote-access-config.yaml` (ready to use)
- ✅ **No additional setup required** - copy and use immediately