# 📁 Repository Structure

## Overview
This repository contains a production-ready Rocket.Chat deployment on Azure Kubernetes Service (AKS) with comprehensive monitoring, logging, and observability features.

## Directory Structure

```
rocketchat-k8s-deployment/
├── 📁 config/                    # Configuration files
│   ├── 📁 certificates/          # SSL certificate configurations
│   │   └── clusterissuer.yaml    # Let's Encrypt cluster issuer
│   └── 📁 helm-values/           # Helm chart value files
│       ├── values-official.yaml  # Main Rocket.Chat configuration
│       ├── values-monitoring.yaml # Monitoring stack configuration
│       ├── values-production.yaml # Production settings
│       ├── values.yaml           # Base configuration
│       ├── loki-stack-values.yaml # Loki logging configuration
│       └── monitoring-values.yaml # Additional monitoring settings
│
├── 📁 deployment/                # Deployment scripts and tools
│   └── deploy-aks-official.sh    # Main deployment script
│
├── 📁 docs/                      # Documentation
│   ├── README.md                 # Documentation index
│   ├── PROJECT_STATUS.md         # Current project status
│   ├── PROJECT_HISTORY.md        # Project development history
│   ├── TROUBLESHOOTING_GUIDE.md  # Common issues and solutions
│   ├── DNS_MIGRATION_GUIDE.md    # DNS migration procedures
│   ├── ENHANCED_MONITORING_PLAN.md # Monitoring implementation plan
│   ├── FUTURE_IMPROVEMENTS.md    # Planned enhancements
│   ├── loki-query-guide.md       # Loki LogQL query examples
│   └── quick-loki-guide.md       # Quick start guide for Loki
│
├── 📁 monitoring/                # Monitoring and observability
│   ├── grafana-datasource-loki.yaml # Loki data source configuration
│   ├── grafana-dashboard-rocketchat.yaml # Custom Rocket.Chat dashboard
│   ├── prometheus-current.yaml   # Prometheus configuration
│   ├── prometheus-patch.yaml     # Prometheus patches
│   ├── rocket-chat-alerts.yaml   # Alert configurations
│   ├── rocket-chat-dashboard-configmap.yaml # Dashboard ConfigMap
│   ├── rocket-chat-dashboard.json # Dashboard JSON definition
│   ├── rocket-chat-podmonitor.yaml # Pod monitoring configuration
│   ├── rocket-chat-servicemonitor.yaml # Service monitoring
│   └── loki-values.yaml          # Loki-specific values
│
├── 📁 scripts/                   # Utility scripts
│   ├── aks-shell.sh              # AKS cluster access script
│   ├── migrate-to-aks.sh         # Migration utilities
│   └── setup-kubeconfig.sh       # Kubernetes configuration setup
│
├── 📁 aks/                       # AKS-specific documentation
│   ├── README.md                 # AKS deployment guide
│   ├── AKS_SETUP_GUIDE.md        # Detailed AKS setup
│   ├── DOMAIN_STRATEGY.md        # Domain configuration strategy
│   ├── MASTER_PLANNING.md        # Architecture planning
│   └── MIGRATION_PLAN.md         # Migration strategy
│
├── 📁 microk8s/                  # Legacy MicroK8s deployment (rollback)
│   ├── README.md                 # MicroK8s documentation
│   ├── DEPLOYMENT_GUIDE.md       # Legacy deployment guide
│   └── [various legacy files]    # Original deployment files
│
├── 📄 README.md                  # Main project documentation
├── 📄 .gitignore                 # Git ignore patterns
└── 📄 .env.example               # Environment variables template
```

## Key Configuration Files

### Deployment
- **`deployment/deploy-aks-official.sh`** - Main deployment script using official Rocket.Chat Helm charts
- **`config/helm-values/values-official.yaml`** - Production Rocket.Chat configuration
- **`config/certificates/clusterissuer.yaml`** - SSL certificate management

### Monitoring & Observability
- **`monitoring/grafana-datasource-loki.yaml`** - Loki integration for log aggregation
- **`monitoring/rocket-chat-podmonitor.yaml`** - Application metrics collection
- **`monitoring/rocket-chat-dashboard-configmap.yaml`** - Custom Grafana dashboards

### Access Scripts
- **`scripts/aks-shell.sh`** - Quick AKS cluster access
- **`scripts/setup-kubeconfig.sh`** - Kubernetes configuration management

## Usage

### Quick Deployment
```bash
cd deployment
chmod +x deploy-aks-official.sh
./deploy-aks-official.sh
```

### Monitoring Stack
The monitoring stack includes:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation and analysis
- **Alertmanager** - Alert management and notifications

### Documentation
Start with `docs/README.md` for comprehensive documentation and troubleshooting guides.

## Status
- ✅ **Production Active** - AKS deployment running at `https://chat.canepro.me`
- ✅ **Monitoring Complete** - Full observability stack operational
- ✅ **SSL Certificates** - Automated certificate management
- ✅ **Enhanced Logging** - Loki integration for centralized logging

## Support
Refer to `docs/TROUBLESHOOTING_GUIDE.md` for common issues and solutions.
