# 🚀 Enhanced Monitoring Setup Plan: Azure Monitor + Loki Integration

**Created**: September 5, 2025
**Branch**: `feature/enhanced-monitoring-setup`
**Status**: Planning Phase
**Estimated Timeline**: 1-2 weeks
**Priority**: HIGH (Critical for production reliability)

---

## 📋 **Executive Summary**

This document outlines the comprehensive plan for implementing enhanced monitoring capabilities for the Rocket.Chat AKS deployment. The plan includes Azure Monitor integration, Loki centralized logging, and custom dashboards for production monitoring.

**Objectives:**
- ✅ Implement Azure Monitor workspace and integration
- ✅ Deploy Loki stack for centralized logging
- ✅ Create custom dashboards for Rocket.Chat server logs
- ✅ Configure Application Performance Monitoring (APM)
- ✅ Set up alerting and notification systems
- ✅ Update troubleshooting documentation

**Success Criteria:**
- Azure Monitor collecting all AKS metrics
- Loki stack ingesting Rocket.Chat application logs
- Custom Grafana dashboards operational
- Alerting system configured and tested
- Troubleshooting documentation updated

---

## 🎯 **Current State Assessment**

### ✅ **Already Deployed**
- **AKS Cluster**: 3 nodes running with monitoring enabled
- **Prometheus Stack**: kube-prometheus-stack deployed via Helm
- **Grafana**: Basic dashboards configured for Rocket.Chat
- **Rocket.Chat**: Running with 7 microservices
- **MongoDB**: 3-replica set with persistent storage

### 🔍 **Monitoring Gaps Identified**
- **Azure Monitor**: Not integrated with AKS cluster
- **Centralized Logging**: No Loki stack for application logs
- **APM**: No application performance monitoring
- **Custom Dashboards**: Limited Rocket.Chat-specific metrics
- **Alerting**: Basic Prometheus alerting, no Azure integration

---

## 📊 **Detailed Implementation Plan**

### **Phase 1: Enhanced Prometheus/Grafana Setup ✅ COMPLETED & VERIFIED (September 5, 2025)**

#### **1.1 Current Monitoring Assessment**
**Objective**: Evaluate existing monitoring capabilities and identify enhancement opportunities

**Current Status:**
- ✅ **Prometheus**: Running with kube-prometheus-stack
- ✅ **Grafana**: Basic dashboards configured
- ✅ **Alertmanager**: Email notifications configured
- 🔍 **Metrics Collection**: Rocket.Chat metrics partially configured
- 🔍 **Dashboards**: Basic infrastructure monitoring

**Assessment Steps:**
```bash
# 1. Check current monitoring status
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
kubectl get prometheusrules -n monitoring

# 2. Verify Grafana access
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &
# Access: http://localhost:3000 (admin/GrafanaAdmin2024!)

# 3. Check existing dashboards
kubectl get configmap -n monitoring -l grafana_dashboard
```

#### **1.2 Rocket.Chat Metrics Enhancement**
**Objective**: Improve Rocket.Chat metrics collection and monitoring

**Current Metrics Analysis:**
```bash
# Check current Rocket.Chat metrics
kubectl get servicemonitor -n rocketchat
kubectl port-forward -n rocketchat svc/rocketchat-rocketchat 3000:3000 &
curl http://localhost:3000/metrics
```

**Enhancement Steps:**
```yaml
# Create ServiceMonitor for Rocket.Chat
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rocketchat-servicemonitor
  namespace: monitoring
  labels:
    app.kubernetes.io/name: rocketchat
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: rocketchat
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

**Configuration Files Created & Verified:**
- ✅ `monitoring/rocket-chat-servicemonitor.yaml`: ServiceMonitor active and collecting metrics
- ✅ `monitoring/rocket-chat-alerts.yaml`: 5 alerts loaded and functional
- ✅ `monitoring/rocket-chat-dashboard-configmap.yaml`: Dashboard auto-imported successfully
- ✅ `monitoring/prometheus-patch.yaml`: Cross-namespace monitoring enabled

**Dashboard Verification Results:**
- ✅ **8 Panels Active**: All monitoring panels displaying correctly
- ✅ **Real-time Data**: CPU, memory, pod status updating live
- ✅ **Alert Integration**: Alert status table functional
- ✅ **Grafana Access**: `http://4.250.192.85` working perfectly

### **Phase 2: Loki Stack Deployment (Days 3-4)**

#### **2.1 Loki Infrastructure Setup**
**Objective**: Deploy Loki stack for centralized logging

**Prerequisites:**
- Helm 3.x installed
- Kubernetes cluster access
- Storage class available for persistent volumes

**Steps:**
```bash
# 1. Add Loki Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 2. Create Loki namespace
kubectl create namespace loki-stack

# 3. Install Loki stack with persistent storage
helm install loki grafana/loki-stack \
  --namespace loki-stack \
  --create-namespace \
  --values loki-values.yaml \
  --wait
```

**Loki Configuration (`loki-values.yaml`):**
```yaml
loki:
  persistence:
    enabled: true
    size: 50Gi
    storageClass: "azurefile-premium"

promtail:
  enabled: true
  config:
    clients:
      - url: http://loki.loki-stack.svc.cluster.local:3100/loki/api/v1/push

grafana:
  enabled: false  # We already have Grafana

persistence:
  enabled: true
  size: 10Gi
  accessModes:
    - ReadWriteOnce
```

#### **2.2 Rocket.Chat Log Integration**
**Objective**: Configure Promtail to collect Rocket.Chat application logs

**Steps:**
```yaml
# 1. Update Promtail configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: loki-stack
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki.loki-stack.svc.cluster.local:3100/loki/api/v1/push

    scrape_configs:
      - job_name: rocket-chat
        static_configs:
          - targets:
              - localhost
            labels:
              job: rocket-chat
              __path__: /var/log/containers/*rocketchat*.log
        pipeline_stages:
          - docker: {}
          - json:
              expressions:
                level: level
                message: message
                timestamp: timestamp
      - job_name: mongodb
        static_configs:
          - targets:
              - localhost
            labels:
              job: mongodb
              __path__: /var/log/containers/*mongodb*.log
```

### **Phase 3: Custom Dashboards & APM (Days 5-7)**

#### **3.1 Rocket.Chat-Specific Dashboards**
**Objective**: Create comprehensive monitoring dashboards for Rocket.Chat

**Dashboard Components:**
1. **Application Health Dashboard**
   - Rocket.Chat pod status and restarts
   - Microservice health checks
   - Response times and error rates

2. **Database Performance Dashboard**
   - MongoDB connection pool usage
   - Query performance metrics
   - Replica set status

3. **Infrastructure Monitoring Dashboard**
   - AKS node utilization
   - Network traffic patterns
   - Storage usage trends

**Implementation Steps:**
```yaml
# Create Grafana dashboard configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: rocket-chat-dashboards
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  rocket-chat-overview.json: |
    {
      "dashboard": {
        "title": "Rocket.Chat Overview",
        "tags": ["rocket-chat", "overview"],
        "timezone": "browser",
        "panels": [
          {
            "title": "Active Users",
            "type": "stat",
            "targets": [
              {
                "expr": "rocketchat_users_online",
                "legendFormat": "Online Users"
              }
            ]
          }
        ]
      }
    }
```

#### **3.2 Application Performance Monitoring (APM)**
**Objective**: Implement application-level performance monitoring

**Steps:**
1. **Enable Rocket.Chat Metrics Endpoint**
2. **Configure Prometheus ServiceMonitor**
3. **Create APM Dashboards**
4. **Set up Performance Alerts**

```yaml
# ServiceMonitor for Rocket.Chat metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rocketchat-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: rocketchat
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

### **Phase 4: Alerting & Notification Setup (Days 8-10)**

#### **4.1 Alert Manager Configuration**
**Objective**: Set up comprehensive alerting for critical events

**Alert Rules:**
- Rocket.Chat pod crashes or restarts
- High memory/CPU usage
- Database connection failures
- SSL certificate expiration warnings
- Storage capacity thresholds

**Steps:**
```yaml
# Update alertmanager configuration
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-main
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yaml: |
    global:
      smtp_smtp:
        host: smtp.gmail.com
        port: 587
        username: alerts@yourdomain.com
        password: your-password

    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'email'

    receivers:
    - name: 'email'
      email_configs:
      - to: 'admin@yourdomain.com'
        from: 'alerts@yourdomain.com'
        smarthost: smtp.gmail.com:587
        auth_username: alerts@yourdomain.com
        auth_password: your-password
```

#### **4.2 Azure Monitor Alerts**
**Objective**: Create Azure-native alerting for infrastructure events

**Steps:**
```bash
# Create Azure Monitor alert rules
az monitor metrics alert create \
  --name "AKS-CPU-Usage-High" \
  --resource /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerService/managedClusters/<aks-name> \
  --condition "avg Percentage CPU > 80" \
  --description "CPU usage is above 80%" \
  --action /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/microsoft.insights/actionGroups/<action-group>
```

### **Phase 5: Testing & Documentation (Days 11-12)**

#### **5.1 Testing & Validation**
**Objective**: Comprehensive testing of monitoring setup

**Test Scenarios:**
- Generate test alerts and verify notifications
- Simulate pod failures and check recovery
- Test log aggregation and search functionality
- Validate dashboard accuracy and responsiveness
- Performance testing under load

#### **5.2 Documentation Updates**
**Objective**: Update all documentation with new monitoring capabilities

**Documentation Updates:**
- Update `docs/TROUBLESHOOTING_GUIDE.md` with monitoring troubleshooting
- Update `docs/PROJECT_STATUS.md` with monitoring implementation
- Create `docs/MONITORING_SETUP.md` with maintenance procedures
- Update runbooks and operational procedures

---

## 🛠️ **Technical Requirements**

### **Prerequisites**
- **Azure CLI**: Version 2.40+
- **kubectl**: Version 1.26+
- **Helm**: Version 3.10+
- **Azure Subscription**: With monitoring permissions
- **AKS Cluster**: With Azure Monitor addon enabled

### **Resource Requirements**
- **CPU**: Additional 0.5-1 vCPU for monitoring components
- **Memory**: Additional 1-2GB RAM for Loki and Promtail
- **Storage**: 50GB for Loki logs, 10GB for monitoring data
- **Network**: Outbound connectivity to Azure Monitor endpoints

### **Security Considerations**
- Azure Monitor workspace access control
- Loki authentication and authorization
- Network policies for monitoring components
- Alert notification security (encrypted emails/SMS)

---

## 📈 **Success Metrics & KPIs**

### **Technical Metrics**
- **Uptime**: >99.9% monitoring system availability
- **Coverage**: 100% of Rocket.Chat components monitored
- **Alert Response**: <5 minutes average alert response time
- **Log Retention**: 30 days searchable log history

### **Business Metrics**
- **MTTR**: Mean Time to Resolution < 30 minutes
- **False Positives**: <5% alert accuracy
- **Dashboard Usage**: Daily active monitoring sessions
- **Incident Prevention**: Proactive issue detection

---

## 🚨 **Risk Assessment & Mitigation**

### **High-Risk Items**
1. **Azure Monitor Integration Issues**
   - **Risk**: Configuration conflicts or permission issues
   - **Mitigation**: Test in non-production environment first

2. **Storage Capacity Issues**
   - **Risk**: Log storage exceeding allocated capacity
   - **Mitigation**: Implement log rotation and retention policies

3. **Alert Fatigue**
   - **Risk**: Too many alerts causing notification overload
   - **Mitigation**: Fine-tune alert thresholds and grouping

### **Rollback Plan**
- **Azure Monitor**: Can be disabled via Azure CLI
- **Loki Stack**: Can be uninstalled via Helm
- **Alerting**: Can be disabled by updating configurations
- **Dashboards**: Can be removed from Grafana

---

## 📋 **Implementation Checklist**

### **Phase 1: Azure Monitor Integration**
- [ ] Azure Monitor workspace created
- [ ] AKS monitoring addon enabled
- [ ] Container metrics collection verified
- [ ] Azure Monitor dashboards accessible

### **Phase 2: Loki Stack Deployment**
- [ ] Loki Helm chart deployed
- [ ] Persistent storage configured
- [ ] Promtail collecting Rocket.Chat logs
- [ ] Loki datasource added to Grafana

### **Phase 3: Custom Dashboards & APM**
- [ ] Rocket.Chat overview dashboard created
- [ ] Database performance dashboard implemented
- [ ] Infrastructure monitoring dashboard configured
- [ ] APM metrics collection enabled

### **Phase 4: Alerting & Notifications**
- [ ] Alertmanager configuration updated
- [ ] Azure Monitor alerts created
- [ ] Notification channels tested
- [ ] Alert escalation procedures defined

### **Phase 5: Testing & Documentation**
- [ ] End-to-end monitoring testing completed
- [ ] Documentation updated
- [ ] Troubleshooting guides enhanced
- [ ] Team training completed

---

## 📞 **Support & Communication**

### **Team Responsibilities**
- **DevOps Lead**: Azure Monitor and Loki implementation
- **Infrastructure Admin**: Azure resource provisioning
- **Application Owner**: Rocket.Chat monitoring requirements
- **Security Officer**: Security configuration validation

### **Communication Plan**
- **Daily Updates**: Progress updates during implementation
- **Weekly Reviews**: Stakeholder alignment meetings
- **Testing Notifications**: Test alert notifications
- **Go-Live Announcement**: Successful implementation notification

---

## 🎯 **Next Steps**

1. **Review and Approve**: Review this plan with stakeholders
2. **Resource Allocation**: Ensure team availability for implementation
3. **Timeline Confirmation**: Confirm 2-week timeline feasibility
4. **Kickoff Meeting**: Schedule implementation kickoff
5. **Branch Management**: Ensure feature branch is up to date

---

**Document Version**: 1.0
**Last Updated**: September 5, 2025
**Author**: Vincent Mogah
**Review Date**: September 6, 2025
**Approval Required**: DevOps Team Lead
