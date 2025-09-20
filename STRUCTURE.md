# 📁 Repository Structure

## Overview
This repository contains a production-ready Rocket.Chat deployment with support for both Azure Kubernetes Service (AKS) and MicroK8s environments. The structure clearly separates resources by deployment platform.

## Directory Structure

```
rocketchat-k8s-deployment/
├── 📁 aks/                                # Azure Kubernetes Service (Production)
│   ├── 📁 config/                         # AKS configuration files
│   │   ├── 📁 certificates/               # SSL certificate configurations
│   │   │   └── clusterissuer.yaml        # Let's Encrypt cluster issuer
│   │   └── 📁 helm-values/               # Helm chart value files
│   │       ├── values-official.yaml      # Main Rocket.Chat configuration
│   │       ├── values-production.yaml    # Production settings
│   │       ├── values.yaml               # Base configuration
│   │       ├── loki-stack-values.yaml    # Loki logging configuration
│   │       ├── mongodb-values.yaml       # MongoDB configuration
│   │       ├── monitoring-values.yaml    # Additional monitoring settings
│   │       ├── values-official-backup-*.yaml # Configuration backups
│   │       └── values-monitoring.yaml    # Monitoring stack configuration
│   │
│   ├── 📁 deployment/                     # AKS deployment scripts
│   │   ├── deploy-aks-official.sh        # Main AKS deployment script
│   │   └── README.md                      # AKS deployment guide
│   │
│   ├── 📁 docs/                           # AKS-specific documentation
│   │   ├── README.md                      # AKS documentation index
│   │   ├── AKS_SETUP_GUIDE.md            # Detailed AKS setup instructions
│   │   ├── DOMAIN_STRATEGY.md            # Domain configuration strategy
│   │   ├── MASTER_PLANNING.md            # Architecture planning
│   │   ├── MIGRATION_PLAN.md             # Migration from MicroK8s to AKS
│   │   ├── DNS_MIGRATION_GUIDE.md        # DNS migration procedures
│   │   ├── REMOTE_ACCESS_GUIDE.md        # Remote AKS cluster access
│   │   ├── ENHANCED_MONITORING_PLAN.md   # Monitoring implementation
│   │   ├── loki-query-guide.md           # Loki LogQL query examples
│   │   └── quick-loki-guide.md           # Quick start guide for Loki
│   │
│   ├── 📁 monitoring/                     # AKS monitoring configurations
│   │   ├── azure-monitor-integration.yaml # Azure Monitor configuration
│   │   ├── grafana-datasource-loki.yaml  # Loki data source configuration
│   │   ├── prometheus-current.yaml       # Prometheus configuration
│   │   ├── prometheus-patch.yaml         # Prometheus patches
│   │   ├── rocket-chat-alerts.yaml       # Alert rules (12 comprehensive alerts)
│   │   ├── rocket-chat-dashboard-configmap.yaml # Grafana dashboard
│   │   ├── rocket-chat-podmonitor.yaml   # Pod monitoring configuration
│   │   ├── rocket-chat-servicemonitor.yaml # Service monitoring
│   │   └── loki-values.yaml              # Loki-specific values
│   │
│   └── 📁 scripts/                        # AKS utility scripts
│       ├── aks-shell.sh                  # AKS cluster access script
│       ├── apply-cost-optimizations.sh   # Cost optimization deployment
│       ├── cost-monitoring.sh            # Cost monitoring and analysis
│       ├── deploy-enhanced-monitoring.sh # Enhanced monitoring deployment
│       ├── deploy-mongodb-standalone.sh  # Brownout workaround deployment
│       ├── fix-mongodb-image.sh          # Helper script (image repo fixes)
│       ├── migrate-to-aks.sh             # Migration utilities
│       └── setup-kubeconfig.sh           # Kubernetes configuration setup
│
├── 📁 microk8s/                           # MicroK8s (Legacy/Rollback)
│   ├── 📁 config/                         # MicroK8s configurations
│   │   ├── mongodb.yaml                  # MongoDB deployment
│   │   ├── mongodb-statefulset.yaml      # MongoDB StatefulSet
│   │   └── rocketchat-deployment.yaml    # Rocket.Chat deployment
│   │
│   ├── 📁 docs/                           # MicroK8s documentation
│   │   ├── README.md                      # MicroK8s documentation index
│   │   ├── DEPLOYMENT_GUIDE.md           # MicroK8s deployment guide
│   │   ├── MICROK8S_SETUP.md             # MicroK8s setup instructions
│   │   ├── PHASE1_STATUS.md              # Phase 1 completion status
│   │   └── PHASE2_STATUS.md              # Phase 2 completion status
│   │
│   ├── 📁 monitoring/                     # MicroK8s monitoring
│   │   └── monitoring.yaml                # Monitoring configuration
│   │
│   └── 📁 scripts/                        # MicroK8s scripts
│       └── setup-ubuntu-server.sh        # Ubuntu server setup script
│
├── 📁 docs/                               # Common/General documentation
│   ├── README.md                          # Documentation index
│   ├── PROJECT_STATUS.md                 # Overall project status
│   ├── PROJECT_HISTORY.md                # Project development history
│   ├── TROUBLESHOOTING_GUIDE.md          # General troubleshooting
│   └── FUTURE_IMPROVEMENTS.md            # Planned enhancements
│
├── 📄 README.md                           # Main project documentation
├── 📄 STRUCTURE.md                        # This file - repository structure
├── 📄 CLEANUP_SUMMARY.md                 # Repository cleanup history
├── 📄 .gitignore                          # Git ignore patterns
└── 📄 .env.example                        # Environment variables template
```

## Environment Separation

### AKS (Production Environment)
All production resources are contained within the `aks/` directory:
- **Configuration**: `aks/config/` - Helm values, certificates
- **Deployment**: `aks/deployment/` - Deployment scripts
- **Monitoring**: `aks/monitoring/` - Prometheus, Grafana, Loki configs
- **Scripts**: `aks/scripts/` - Utility and maintenance scripts
- **Documentation**: `aks/docs/` - AKS-specific guides

### MicroK8s (Legacy/Rollback Environment)
Legacy MicroK8s resources are preserved in the `microk8s/` directory:
- **Configuration**: `microk8s/config/` - YAML manifests
- **Monitoring**: `microk8s/monitoring/` - Monitoring setup
- **Scripts**: `microk8s/scripts/` - Setup and deployment scripts
- **Documentation**: `microk8s/docs/` - MicroK8s guides

### Common Resources
Shared documentation and project-wide files remain at the root:
- **Common Docs**: `docs/` - Project status, history, troubleshooting
- **Project Files**: Root level - README, .gitignore, .env.example

## Usage

### For AKS Deployment (Production)
```bash
cd aks/deployment
./deploy-aks-official.sh
```

### For MicroK8s Deployment (Legacy)
```bash
cd microk8s/scripts
./setup-ubuntu-server.sh
```

### Accessing Documentation
- **AKS Guides**: `aks/docs/`
- **MicroK8s Guides**: `microk8s/docs/`
- **General Documentation**: `docs/`

## Key Benefits of This Structure

1. **Clear Separation**: No confusion between AKS and MicroK8s resources
2. **Easy Navigation**: All related files grouped by environment
3. **Simplified Maintenance**: Updates to one environment don't affect the other
4. **Better Version Control**: Clear commit history per environment
5. **Rollback Ready**: MicroK8s preserved for emergency rollback

## Status
- ✅ **AKS**: Production deployment active at `https://chat.canepro.me`
- ✅ **MicroK8s**: Legacy deployment preserved for rollback
- ✅ **Documentation**: Comprehensive guides for both environments
- ✅ **Monitoring**: Full observability stack operational on AKS