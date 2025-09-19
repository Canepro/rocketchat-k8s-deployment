# � Documentation

Welcome to the comprehensive documentation for the Rocket.Chat Kubernetes deployment on Azure AKS.

## � Documentation Index

### 🚀 Getting Started
- **[Main README](../README.md)** - Project overview and quick start
- **[Repository Structure](../STRUCTURE.md)** - Complete directory layout
- **[Deployment Guide](../deployment/README.md)** - Step-by-step deployment instructions

### ⚠️ Bitnami MongoDB Brownout (Sept 17–19, 2025)
If MongoDB images fail to pull (ImagePullBackOff), use the standalone MongoDB deployment and external DB configuration:
- See: [Troubleshooting: Bitnami MongoDB Brownout](TROUBLESHOOTING_GUIDE.md#issue-bitnami-mongodb-brownout---images-unavailable-september-17-19-2025)
- Files: `aks/config/mongodb-standalone.yaml`, `aks/scripts/deploy-mongodb-standalone.sh`

### 📊 Current Status
- **[Project Status](PROJECT_STATUS.md)** - Current deployment status and progress
- **[Project History](PROJECT_HISTORY.md)** - Development timeline and decisions

### � Operations & Maintenance
- **[Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions
- **[DNS Migration Guide](DNS_MIGRATION_GUIDE.md)** - DNS configuration procedures

### � Monitoring & Observability
- **[Enhanced Monitoring Plan](ENHANCED_MONITORING_PLAN.md)** - Monitoring implementation details
- **[Loki Query Guide](loki-query-guide.md)** - LogQL examples and log analysis
- **[Quick Loki Guide](quick-loki-guide.md)** - Fast start guide for log queries

### 🔮 Planning & Future
- **[Future Improvements](FUTURE_IMPROVEMENTS.md)** - Planned enhancements and roadmap

## 🎯 Quick Access

### For Deployment Issues
Start with [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md) for:
- Pod startup problems
- SSL certificate issues
- Ingress configuration problems
- Performance optimization

### For Log Analysis
Use [Loki Query Guide](loki-query-guide.md) for:
- Finding application errors
- Monitoring user activity
- Database query analysis
- System performance metrics

### For DNS/Network Issues
Refer to [DNS Migration Guide](DNS_MIGRATION_GUIDE.md) for:
- Domain configuration
- Certificate troubleshooting
- Load balancer issues
- Cloudflare integration

## 📊 Current Deployment Overview

**Production Environment:**
- **Platform**: Azure Kubernetes Service (AKS)
- **Rocket.Chat**: `https://chat.canepro.me` ✅
- **Grafana**: `https://grafana.chat.canepro.me` ✅
- **Status**: Production Active with Enhanced Monitoring Complete
- **Repository**: Professionally organized and cleaned (Sept 6, 2025)

**Infrastructure:**
- **Cluster**: 3-node AKS cluster
- **Storage**: 50Gi persistent storage
- **Monitoring**: Prometheus + Grafana + Loki
- **SSL**: Automated cert-manager with Let's Encrypt
- **Cost**: ~£65-95/month (within £100 Azure credit)

## 🛠️ Quick Commands

### Check System Status
```bash
kubectl get pods -n rocketchat
kubectl get pods -n monitoring
kubectl get ingress --all-namespaces
```

### View Logs
```bash
kubectl logs -n rocketchat deployment/rocketchat --tail=50
kubectl logs -n monitoring deployment/grafana-deployment --tail=50
```

### Access Services
```bash
# Port forward Grafana (if needed)
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

## 📞 Support Resources

### Internal Documentation
- All guides in this `docs/` directory
- Configuration examples in `../config/`
- Monitoring setups in `../monitoring/`

### External Resources
- [Rocket.Chat Official Docs](https://docs.rocket.chat/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Prometheus Monitoring](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

*For immediate assistance, start with the [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)*
