# 🚀 MicroK8s Rocket.Chat Deployment (Legacy)

This folder contains the legacy MicroK8s deployment files and documentation. This deployment is currently running on your Azure Ubuntu VM and will be kept as a rollback option during the AKS migration.

## 📁 Contents

### Documentation
- `MICROK8S_SETUP.md` - How to set up MicroK8s on Ubuntu
- `DEPLOYMENT_GUIDE.md` - Current MicroK8s Rocket.Chat deployment
- `PHASE1_STATUS.md` - Backup completion status
- `PHASE2_STATUS.md` - AKS migration progress (outdated)

### Configuration Files
- `rocketchat-deployment.yaml` - Custom Rocket.Chat deployment (not official Helm chart)
- `mongodb-aks.yaml` - MongoDB configuration for AKS testing
- `mongodb-statefulset-only.yaml` - MongoDB StatefulSet configuration
- `monitoring-aks.yaml` - Monitoring configuration for AKS
- `setup-ubuntu-server.sh` - Ubuntu server setup script

## 🔄 Current Status

- **Status**: ✅ **Running and operational**
- **Domain**: `chat.canepro.me` (currently active)
- **Data**: 6,986 documents backed up
- **Backup**: Available for rollback

## ⚠️ Important Notes

- This folder contains legacy/custom deployment files
- **Do not modify** files in this folder unless you're updating the current MicroK8s deployment
- These files are kept for rollback purposes only
- The main deployment will use the official Rocket.Chat Helm chart in the root directory

## 🔙 Rollback Instructions

If you need to rollback to MicroK8s:

1. Ensure MicroK8s VM is still running
2. Update DNS to point back to MicroK8s VM IP: `20.68.53.249`
3. Verify `https://chat.canepro.me` works
4. Keep this VM for 3-5 days as insurance

---

**Last Updated**: September 5, 2025
**Status**: 🟢 Active - Emergency Rollback Ready (3-5 day window)
