# Helm Values Examples

This directory contains example Helm values files for different deployment scenarios.

## Available Examples

### Production Configurations

- **`values-production.yaml`** - RocketChat production configuration
  - 3 replicas for high availability
  - Increased resources (1 CPU, 2Gi RAM per pod)
  - Pod disruption budgets
  - Anti-affinity rules
  - Production-ready health checks

- **`mongodb-production.yaml`** - MongoDB production configuration
  - 3-replica MongoDB cluster
  - Premium storage (50Gi)
  - Resource limits optimized for production
  - Backup configuration examples

### How to Use

#### For Production Deployment

1. **Copy and customize:**
   ```bash
   cp examples/helm-values/values-production.yaml aks/config/helm-values/values-production.yaml
   cp examples/helm-values/mongodb-production.yaml aks/config/helm-values/mongodb-production.yaml
   ```

2. **Update domain and secrets:**
   - Replace `<YOUR_DOMAIN>` with your actual domain
   - Change default passwords in MongoDB config
   - Update resource limits based on your needs

3. **Deploy with production values:**
   ```bash
   helm upgrade --install rocketchat rocketchat/rocketchat \
     -f aks/config/helm-values/values-production.yaml \
     -n rocketchat
   ```

#### For Development/Testing

The default values in `aks/config/helm-values/` are already optimized for development and testing with minimal resources.

## Configuration Comparison

| Setting | Dev/Test (Default) | Production (Example) |
|---------|-------------------|---------------------|
| **RocketChat Replicas** | 1 | 3 |
| **RocketChat CPU** | 250m / 100m | 1000m / 500m |
| **RocketChat Memory** | 512Mi / 256Mi | 2Gi / 1Gi |
| **MongoDB Replicas** | 1 | 3 |
| **MongoDB CPU** | 250m / 100m | 1000m / 500m |
| **MongoDB Memory** | 512Mi / 256Mi | 2Gi / 1Gi |
| **MongoDB Storage** | 5Gi | 50Gi |
| **Storage Class** | default | managed-premium |
| **Pod Disruption Budget** | Disabled | Enabled |
| **Anti-affinity** | None | Required |
| **Estimated Cost/Month** | ~$50-100 | ~$200-300 |

## Scaling Recommendations

### Small Production (100-500 users)
- RocketChat: 2 replicas, 500m CPU, 1Gi RAM
- MongoDB: 1 replica, 500m CPU, 1Gi RAM, 20Gi storage
- Cost: ~$100-150/month

### Medium Production (500-2000 users)
- RocketChat: 3 replicas, 1000m CPU, 2Gi RAM
- MongoDB: 3 replicas, 500m CPU, 1Gi RAM, 50Gi storage
- Cost: ~$200-300/month

### Large Production (2000+ users)
- RocketChat: 5+ replicas, 2000m CPU, 4Gi RAM
- MongoDB: 3 replicas, 1000m CPU, 2Gi RAM, 100Gi storage
- Cost: ~$500+/month

## Important Notes

⚠️ **Security:**
- Always change default passwords before production deployment
- Use Kubernetes secrets for sensitive data
- Never commit production configurations with real credentials

📊 **Monitoring:**
- Verify resource usage after deployment
- Adjust limits based on actual metrics
- Enable autoscaling for variable workloads

💾 **Backups:**
- Configure automated MongoDB backups
- Test restore procedures regularly
- Keep backups in separate region/account

## Support

For more information, see:
- [Deployment Guide](../../DEPLOYMENT_GUIDE.md)
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING_GUIDE.md)
- [RocketChat Official Documentation](https://docs.rocket.chat/)
