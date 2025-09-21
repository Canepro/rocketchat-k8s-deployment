# 🚨 Enhanced Monitoring & Alerting Guide

**Date**: September 19, 2025
**Last Updated**: September 21, 2025
**Status**: ✅ Enhanced Monitoring Deployed
**Purpose**: Comprehensive monitoring with alerts, notifications, and Azure integration

## 📊 Enhanced Monitoring Overview

### 🚀 Deployed Features
- **12 Advanced Alert Rules** - Comprehensive coverage of critical issues
- **Multi-Channel Notifications** - Email, Slack, webhooks, Azure Monitor
- **Intelligent Alert Routing** - Severity-based routing and grouping
- **Runbook Integration** - Direct links to troubleshooting guides
- **Azure Monitor Configuration** - Enterprise-grade monitoring (configuration ready)
- **Loki Volume API Support** - Advanced log volume visualization (Loki 2.9.0)
- **Enhanced Dashboard Panels** - Fixed data accuracy and added user metrics panels

### 📈 Monitoring Coverage

#### Alert Categories
```
Critical Alerts (Immediate Action Required):
├── Rocket.Chat service down
├── MongoDB connection issues
└── Ingress/network failures

Performance Alerts (Optimization Needed):
├── High CPU usage (>80%)
├── High memory usage (>90%)
├── MongoDB performance issues
└── Resource utilization warnings

Stability Alerts (Investigation Required):
├── Pod restart loops
├── Microservice failures
└── Configuration issues

Capacity Alerts (Planning Required):
├── Storage usage warnings (>85%)
├── MongoDB storage critical (>90%)
└── Resource scaling recommendations
```

## 🚨 Alert Configuration

### Enhanced Alert Rules Deployed

#### 1. Critical Service Availability
```yaml
- RocketChatDown: Service unavailable for 5+ minutes
- MongoDBConnectionIssues: Database connectivity lost
- RocketChatIngressDown: External access unavailable
```

#### 2. Performance Monitoring
```yaml
- RocketChatHighCPU: CPU >80% for 15 minutes
- RocketChatHighMemory: Memory >90% for 10 minutes
- MongoDBHighCPU/Memory: Database resource alerts
- HighResourceUtilization: Cost optimization opportunities
```

#### 3. Stability & Health
```yaml
- RocketChatPodRestarting: Frequent restarts detected
- RocketChatMicroserviceDown: Individual services failing
- Storage alerts: Capacity planning warnings
```

### Alert Severity Levels
```
🚨 Critical: Immediate action required (service down, data loss risk)
⚠️  Warning: Performance issues, capacity warnings
ℹ️  Info: Optimization opportunities, informational alerts
```

## 📧 Notification Channels

### Email Notifications
**Status**: ✅ Configured and ready
**Configuration**: `aks/config/helm-values/monitoring-values.yaml`
```yaml
email_configs:
  - to: 'admin@yourdomain.com'        # Update with your email
    smarthost: 'smtp.gmail.com:587'    # Configure SMTP server
    auth_username: 'your-email@gmail.com'
    auth_password: 'your-app-password'
```

### Slack Integration (Optional)
**Status**: ⏳ Ready to configure
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#rocketchat-alerts'
```

### Webhook Integration (Optional)
**Status**: ⏳ Ready to configure
```yaml
webhook_configs:
  - url: 'https://your-webhook-endpoint.com/alerts'
```

## 🔧 Azure Monitor Integration

### Features Enabled
- **Container Insights**: Detailed container metrics and logs
- **Log Analytics**: Centralized logging with KQL queries
- **Azure Alerts**: Native Azure alerting and notifications
- **Workbooks**: Custom dashboards and analytics

### Azure Monitor Queries
```kql
// Rocket.Chat pod status
KubePodInventory
| where ClusterName == "rocketchat-aks"
| where Namespace == "rocketchat"
| where PodName startswith "rocketchat"
| summarize count() by PodStatus, bin(TimeGenerated, 5m)

// MongoDB performance
Perf
| where ObjectName == "K8SContainer"
| where InstanceName contains "mongodb"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m)

// Resource usage trends
Perf
| where ObjectName == "K8SNode"
| where CounterName in ("% Processor Time", "% Used Memory")
| summarize avg(CounterValue) by CounterName, bin(TimeGenerated, 1h)
```

## 🎯 Alert Response Procedures

### Critical Alerts (🚨)
**Immediate Action Required (< 5 minutes)**

#### Rocket.Chat Service Down
1. **Check pod status**: `kubectl get pods -n rocketchat`
2. **Check logs**: `kubectl logs -n rocketchat deployment/rocketchat-rocketchat`
3. **Restart deployment**: `kubectl rollout restart deployment/rocketchat-rocketchat -n rocketchat`
4. **Check MongoDB**: `kubectl get pods -n rocketchat -l app=mongodb`

#### MongoDB Connection Issues
1. **Check MongoDB pods**: `kubectl get pods -n rocketchat -l app=mongodb`
2. **Check replica set**: `kubectl exec -n rocketchat mongodb-0 -- mongosh --eval "rs.status()"`
3. **Restart MongoDB**: `kubectl rollout restart statefulset/mongodb -n rocketchat`

### Warning Alerts (⚠️)
**Investigation Required (< 30 minutes)**

#### High Resource Usage
1. **Check current usage**: `kubectl top pods -n rocketchat`
2. **Review resource limits**: Check Helm values
3. **Scale if needed**: `kubectl scale deployment rocketchat-rocketchat -n rocketchat --replicas=3`
4. **Monitor for 24 hours**: Check if usage stabilizes

#### Storage Warnings
1. **Check PVC usage**: `kubectl get pvc -n rocketchat`
2. **Analyze disk usage**: Check Grafana storage panel
3. **Plan capacity increase**: Consider storage expansion

## 📊 Monitoring Dashboards

### Grafana Dashboards
- **Rocket.Chat Production Monitoring**: Main operational dashboard
- **Alertmanager**: Alert status and history
- **Prometheus**: System metrics and performance

### Azure Monitor Workbooks
- **Container Insights**: Detailed container analytics
- **Cost Analysis**: Spending trends and optimization
- **Log Analytics**: Centralized logging queries

## 🔍 Testing Alert System

### Manual Alert Testing
```bash
# Test Rocket.Chat down alert (temporary)
kubectl scale deployment rocketchat-rocketchat -n rocketchat --replicas=0

# Wait 5+ minutes for alert to trigger
# Check Alertmanager: https://grafana.chat.canepro.me/alertmanager

# Restore service
kubectl scale deployment rocketchat-rocketchat -n rocketchat --replicas=2
```

### Performance Alert Testing
```bash
# Simulate high CPU usage
kubectl run stress-test --image=alpine -- stress --cpu 4 --timeout 300

# Monitor alerts in Grafana
# Check resource usage: kubectl top pods -n rocketchat
```

## 📈 Monitoring Metrics

### Key Performance Indicators (KPIs)
```
Availability: >99.9% uptime
Response Time: <500ms API responses
Error Rate: <1% of total requests
Resource Usage: <80% average utilization
Alert Response: <5 minutes for critical alerts
```

### Monitoring Coverage Metrics
```
Services Monitored: 8 (Rocket.Chat, MongoDB, microservices)
Alert Rules: 12 comprehensive rules
Notification Channels: 4 configured
Log Retention: 7 days Prometheus, 30 days Loki
```

## 🔧 Maintenance Procedures

### Weekly Monitoring Review
1. **Check alert history**: Review fired alerts and resolution times
2. **Review dashboard trends**: Analyze performance patterns
3. **Update alert thresholds**: Adjust based on observed patterns
4. **Test notification channels**: Send test alerts

### Monthly Optimization
1. **Review alert rules**: Add missing coverage, remove false positives
2. **Optimize dashboards**: Improve visualization and alerting
3. **Update runbooks**: Keep troubleshooting guides current
4. **Cost analysis**: Review monitoring costs and optimization

### Quarterly Planning
1. **Capacity planning**: Review storage and compute growth trends
2. **Technology updates**: Plan monitoring stack upgrades
3. **Process improvements**: Enhance alert response procedures
4. **Training updates**: Keep team knowledge current

## 🚀 Deployment Instructions

### Deploy Enhanced Monitoring
```bash
# Deploy enhanced alerts and notifications
./aks/scripts/deploy-enhanced-monitoring.sh

# Optional: Deploy Azure Monitor integration
# Follow prompts in the deployment script
```

### Configure Email Notifications
1. Update SMTP settings in `aks/config/helm-values/monitoring-values.yaml`
2. Deploy updated configuration:
```bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/monitoring-values.yaml \
  -n monitoring
```

### Configure Additional Channels
1. Uncomment and configure Slack/webhook settings
2. Redeploy monitoring stack
3. Test notifications

## 📞 Support & Resources

### Alert Response Resources
- **[Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)**: Detailed resolution procedures
- **[Performance Analysis](PERFORMANCE_ANALYSIS.md)**: Optimization recommendations
- **[Cost Optimization](COST_OPTIMIZATION_GUIDE.md)**: Cost monitoring procedures

### Monitoring Tools
- **Grafana**: `https://grafana.chat.canepro.me` (admin/prom-operator)
- **Alertmanager**: `https://grafana.chat.canepro.me/alertmanager`
- **Prometheus**: `https://grafana.chat.canepro.me/prometheus`
- **Azure Monitor**: Portal → Monitor → Containers

### Contact Information
- **Alert Notifications**: Configured email recipients
- **On-call Rotation**: Define team rotation schedule
- **Escalation Procedures**: Critical alert response chain

---
**Enhanced Monitoring Guide**: September 19, 2025
**Alert Rules**: 12 comprehensive rules deployed
**Notification Channels**: Email + Azure Monitor configured
**Next Review**: October 19, 2025 (monthly review)
