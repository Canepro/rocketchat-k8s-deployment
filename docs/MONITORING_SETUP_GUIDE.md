# 📊 Rocket.Chat AKS Monitoring Setup Guide

**Created**: September 19, 2025  
**Last Updated**: September 22, 2025 (Enhanced CPU/Memory Analytics Integration)
**Purpose**: Complete guide for setting up production-ready monitoring for Rocket.Chat on AKS  
**Scope**: Prometheus, Grafana, Loki, Alertmanager with Helm-managed configuration  
**Status**: ✅ **PRODUCTION-READY IMPLEMENTATION COMPLETE**

## 🎉 **SUCCESS STORY**
This monitoring stack has been **fully implemented and verified** with:
- **50+ Rocket.Chat metric series** flowing into Prometheus
- **34 comprehensive dashboard panels** displaying real-time data (6 new CPU/memory panels added)
- **Complete ServiceMonitor discovery** after troubleshooting
- **End-to-end log aggregation** via Loki with 7 log analysis panels
- **🆕 Advanced Resource Analytics** with CPU/memory efficiency tracking and optimization insights
- **🆕 Node-level monitoring** for cluster-wide resource health visibility
- **🆕 Historical trending** for capacity planning and performance analysis
- **Official Rocket.Chat dashboards** integrated from Grafana community
- **Comprehensive troubleshooting documentation** for future maintenance  

## 🎯 Overview

This guide provides a complete monitoring solution for Rocket.Chat deployed on Azure Kubernetes Service (AKS) using:

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards  
- **Loki** - Log aggregation and analysis
- **Alertmanager** - Alert routing and notifications
- **PodMonitors** - Rocket.Chat metrics scraping
- **ServiceMonitors** - Kubernetes component monitoring

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Rocket.Chat   │────│   PodMonitors    │────│   Prometheus    │
│  (ports 9458,   │    │  (Helm-managed)  │    │  (metrics DB)   │
│   9459, 9216)   │    └──────────────────┘    └─────────────────┘
└─────────────────┘                                      │
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│      Loki       │────│    Promtail      │    │    Grafana      │
│  (log storage)  │    │ (log collector)  │    │ (visualization) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                ┌─────────────────┐
                                                │  Alertmanager   │
                                                │ (notifications) │
                                                └─────────────────┘
```

## 📋 Prerequisites

- AKS cluster running Rocket.Chat
- Helm 3.x installed
- kubectl configured for your cluster
- Prometheus Community Helm repository added

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## 🚀 Quick Setup

### 1. Deploy Monitoring Stack

```bash
# Deploy complete monitoring stack
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f aks/config/helm-values/monitoring-values.yaml \
  --create-namespace \
  --wait \
  --timeout 10m0s
```

### 2. Deploy Loki for Logs

```bash
# Deploy Loki stack
helm upgrade --install loki grafana/loki-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set promtail.enabled=true \
  --wait
```

### 3. Deploy Enhanced CPU/Memory Dashboard (New)

```bash
# Deploy comprehensive resource monitoring dashboard
cd aks/scripts
chmod +x update-monitoring-dashboard.sh
./update-monitoring-dashboard.sh

# The script will automatically:
# ✅ Check prerequisites and connectivity
# ✅ Backup existing dashboard configuration  
# ✅ Deploy 6 new CPU/memory monitoring panels
# ✅ Restart Grafana to reload dashboards
# ✅ Verify deployment and show access information
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Verify PodMonitors
kubectl get podmonitor -n monitoring

# Check enhanced dashboard ConfigMap
kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring

# Check Prometheus targets
kubectl proxy --port=8001 &
# Visit: http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/targets
```

## 📁 Configuration Files

### monitoring-values.yaml

The main configuration file located at `aks/config/helm-values/monitoring-values.yaml` contains:

#### Prometheus Configuration
```yaml
prometheus:
  prometheusSpec:
    # Enable monitoring of ALL ServiceMonitors and PodMonitors
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    enableAdminAPI: true
    retention: "7d"
    
  # Helm-managed PodMonitors for Rocket.Chat
  additionalPodMonitors:
    - name: rocketchat-metrics
      namespace: monitoring
      labels:
        release: monitoring  # Critical for discovery
      selector:
        matchLabels:
          app.kubernetes.io/instance: rocketchat
          app.kubernetes.io/name: rocketchat
      podMetricsEndpoints:
        - portNumber: 9458  # Main Rocket.Chat metrics
          path: /metrics
          interval: 30s
```

#### Grafana Configuration
```yaml
grafana:
  adminPassword: "prom-operator"
  persistence:
    enabled: true
    size: 5Gi
    
  # Auto-provision Loki datasource
  additionalDataSources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki.monitoring.svc.cluster.local:3100
      
  # Official Rocket.Chat dashboards
  dashboards:
    rocketchat:
      - name: "rocketchat-metrics"
        folder: "rocketchat"
        id: "23428"
        revision: latest
```

#### Alertmanager Configuration
```yaml
alertmanager:
  alertmanagerSpec:
    route:
      group_by: ['alertname', 'severity', 'service']
      receiver: 'email-notifications'
    receivers:
      - name: 'email-notifications'
        email_configs:
          - to: 'your-email@domain.com'
            from: 'alerts@rocketchat-monitoring.com'
            smarthost: 'smtp.gmail.com:587'
```

## 🎛️ Accessing Services

### Grafana Dashboard
```bash
# Port-forward to access Grafana
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring

# Access: http://127.0.0.1:3000
# Username: admin
# Password: prom-operator
```

### Prometheus UI
```bash
# Port-forward to access Prometheus
kubectl proxy --port=8001

# Access: http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/
```

### Alertmanager UI
```bash
# Port-forward to access Alertmanager
kubectl proxy --port=8001

# Access: http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-alertmanager:9093/proxy/
```

## 📊 Key Metrics Monitored

### Rocket.Chat Application Metrics (Port 9458)
- `rocketchat_users_total` - Total registered users
- `rocketchat_rooms_total` - Total rooms/channels
- `rocketchat_messages_sent_total` - Messages sent counter
- `http_requests_total` - HTTP request metrics
- `http_request_duration_seconds` - Response time histograms

### Rocket.Chat Microservices (Port 9459)
- Service-specific metrics from:
  - Account service
  - Authorization service
  - DDP Streamer
  - Presence service
  - Stream Hub

### MongoDB Metrics (Port 9216)
- `mongodb_connections_current` - Active connections
- `mongodb_memory_resident_bytes` - Memory usage
- `mongodb_opcounters_total` - Operation counters
- `mongodb_network_bytes_total` - Network I/O

## 🔍 Troubleshooting

### Dashboard Shows "No Data"

**Symptoms**: Prometheus targets are UP but Grafana dashboards show no data

**Solution**: Check metric label alignment
```bash
# 1. Verify targets are UP
kubectl proxy --port=8001 &
# Visit Prometheus targets page

# 2. Check available metrics
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/label/__name__/values" | jq '.data[] | select(test("rocketchat"))'

# 3. Test queries in Grafana Explore
# Query: up{namespace="rocketchat"}
```

### PodMonitor Not Discovered

**Symptoms**: PodMonitor exists but Prometheus doesn't scrape targets

**Solution**: Verify labels and selectors
```bash
# Check PodMonitor labels
kubectl get podmonitor rocketchat-metrics -n monitoring -o yaml

# Ensure 'release: monitoring' label is present
kubectl patch podmonitor rocketchat-metrics -n monitoring --type merge -p '{"metadata":{"labels":{"release":"monitoring"}}}'
```

### Missing Metrics from Rocket.Chat

**Symptoms**: No Rocket.Chat specific metrics available

**Solution**: Verify Rocket.Chat metrics configuration
```bash
# Check if metrics endpoints are accessible
kubectl port-forward -n rocketchat svc/rocketchat 3000:3000
curl http://127.0.0.1:3000/metrics

# Verify Rocket.Chat has metrics enabled
kubectl exec -n rocketchat deployment/rocketchat -- printenv | grep METRICS
```

## 🔔 Alert Rules

### Critical Alerts
- **RocketChatDown**: Rocket.Chat service unavailable
- **HighResponseTime**: 95th percentile > 5 seconds
- **HighErrorRate**: Error rate > 5%
- **MongoDBDown**: MongoDB connection failures

### Warning Alerts  
- **HighMemoryUsage**: Memory usage > 80%
- **HighCPUUsage**: CPU usage > 80%
- **DiskSpaceRunningOut**: Disk usage > 85%

## 🔧 Customization

### Adding Custom Metrics
```yaml
# Add to monitoring-values.yaml
prometheus:
  additionalPodMonitors:
    - name: custom-service-metrics
      selector:
        matchLabels:
          app: custom-service
      podMetricsEndpoints:
        - port: metrics
          path: /custom/metrics
```

### Custom Dashboard
```json
{
  "dashboard": {
    "title": "Custom Rocket.Chat Dashboard",
    "panels": [
      {
        "title": "Active Users",
        "type": "stat",
        "targets": [
          {
            "expr": "rocketchat_users_online_total{namespace=\"rocketchat\"}"
          }
        ]
      }
    ]
  }
}
```

## 📈 Performance Tuning

### Prometheus Optimization
```yaml
prometheus:
  prometheusSpec:
    retention: "15d"  # Adjust based on storage
    scrapeInterval: "30s"  # Balance between accuracy and load
    evaluationInterval: "30s"
    resources:
      limits:
        cpu: 500m
        memory: 1Gi
```

### Grafana Optimization
```yaml
grafana:
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
  grafana.ini:
    database:
      cache_mode: shared
    server:
      enable_gzip: true
```

## 🔐 Security Considerations

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: rocketchat
```

### RBAC Configuration
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-monitoring
rules:
- apiGroups: [""]
  resources: ["nodes", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

## 📚 Additional Resources

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Rocket.Chat Metrics Documentation](https://docs.rocket.chat/use-rocket.chat/workspace-administration/settings/analytics)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/monitoring/)

## 🔄 Maintenance

### Regular Tasks
- Monitor storage usage and adjust retention policies
- Update dashboard queries when application changes
- Review and tune alert thresholds
- Backup Grafana dashboards and configurations
- Update Helm charts and container images

### Backup Strategy
```bash
# Backup Grafana dashboards
kubectl get configmap -n monitoring -o yaml > grafana-dashboards-backup.yaml

# Backup Prometheus rules
kubectl get prometheusrule -n monitoring -o yaml > prometheus-rules-backup.yaml
```

## 🎛️ **Comprehensive Dashboard Implementation**

### **Overview**
The comprehensive dashboard provides complete observability for Rocket.Chat with 28 panels covering user engagement, performance, business metrics, infrastructure health, and log analysis.

### **Dashboard Features**

#### **Real-time Monitoring (4 Panels)**
- **Rocket.Chat Uptime SLO**: 99%+ uptime tracking with color-coded thresholds
- **Active Users**: Live count of currently active users
- **Total Users**: Cumulative user count
- **Messages per Second**: Real-time message throughput

#### **User Engagement (2 Panels)**
- **User Status Distribution**: Online/Away/Offline distribution over time
- **DDP Connected Users**: WebSocket connection monitoring

#### **Performance Metrics (4 Panels)**
- **API Response Time**: Average and 95th percentile response times
- **API Request Rate**: Requests per second
- **DDP Sessions**: Total and authenticated session counts
- **Meteor Methods Performance**: Server-side method execution time and rate

#### **Business Intelligence (4 Panels)**
- **Message Types Distribution**: Breakdown by channel type (public, private, direct, livechat)
- **Room Statistics**: Total channels, private groups, direct messages, livechat
- **Livechat Performance**: Agent count, visitor count, webhook success/failures
- **Apps & Integrations**: Installed, enabled, failed apps and hooks

#### **Infrastructure Health (4 Panels)**
- **CPU Usage**: By pod with color-coded performance indicators
- **Memory Usage**: By pod with memory consumption tracking
- **Pod Status**: Running pods and total count
- **Pod Restarts**: Restart tracking by pod/container

#### **System Status (2 Panels)**
- **MongoDB Status**: Database replica set health
- **Log Ingest Rate**: Loki log ingestion performance

#### **Log Analysis (7 Panels)**
- **Rocket.Chat Application Logs**: Full-width log viewer with filtering
- **Error Logs**: Automated error detection and display
- **MongoDB Logs**: Database-specific log analysis
- **Log Volume by Service**: Log ingestion rates by container
- **Log Level Distribution**: Debug, info, warn, error, fatal breakdown
- **Recent Alerts & Warnings**: Filtered alert and warning logs
- **Performance Logs**: Slow queries, timeouts, and performance issues

### **Deployment Steps**

#### **1. Deploy Comprehensive Dashboard**
```bash
# Apply the comprehensive dashboard ConfigMap
kubectl apply -f aks/monitoring/rocket-chat-dashboard-comprehensive-configmap.yaml

# Verify dashboard is imported
kubectl get configmap -n monitoring | grep dashboard
```

#### **2. Update Monitoring Values for Official Dashboards**
```bash
# Update monitoring stack to include official Rocket.Chat dashboards
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/monitoring-values.yaml \
  -n monitoring

# Verify official dashboards are imported
kubectl get configmap -n monitoring | grep rocketchat
```

#### **3. Access Dashboards**
```bash
# Port-forward to access Grafana
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring

# Navigate to: http://localhost:3000
# Look for:
# - "Rocket.Chat Comprehensive Production Monitoring" (custom dashboard)
# - "rocketchat-metrics" (official dashboard)
# - "rocketchat-microservices" (official dashboard)
```

### **Available Metrics (50+ Total)**
The dashboard utilizes comprehensive Rocket.Chat metrics including:

**User Metrics:**
- `rocketchat_users_active`, `rocketchat_users_total`, `rocketchat_users_online`
- `rocketchat_users_away`, `rocketchat_users_offline`

**Message Metrics:**
- `rocketchat_messages_total`, `rocketchat_channel_messages_total`
- `rocketchat_direct_messages_total`, `rocketchat_private_group_messages_total`
- `rocketchat_livechat_messages_total`

**Performance Metrics:**
- `rocketchat_rest_api_count`, `rocketchat_rest_api_sum`
- `rocketchat_ddp_connected_users`, `rocketchat_ddp_sessions_count`
- `rocketchat_meteor_methods_count`, `rocketchat_meteor_methods_sum`

**Business Metrics:**
- `rocketchat_channels_total`, `rocketchat_private_groups_total`
- `rocketchat_livechat_total`, `rocketchat_agents_total`
- `rocketchat_apps_installed`, `rocketchat_apps_enabled`

**🆕 Resource Metrics (Enhanced CPU/Memory Analytics):**
- `container_cpu_usage_seconds_total` - Real-time CPU usage per container
- `container_memory_working_set_bytes` - Memory usage per container
- `kube_pod_container_resource_limits` - CPU and memory limits per pod
- `node_cpu_seconds_total` - Node-level CPU metrics via Node Exporter
- `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` - Node memory metrics

**🆕 Resource Efficiency Calculations:**
- CPU Utilization vs Limits: `rate(container_cpu_usage_seconds_total[5m]) / kube_pod_container_resource_limits{resource="cpu"} * 100`
- Memory Utilization vs Limits: `container_memory_working_set_bytes / kube_pod_container_resource_limits{resource="memory"} * 100`
- Node CPU Usage: `100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
- Node Memory Usage: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`

### **Log Analysis Capabilities**
The dashboard includes advanced log analysis using Loki:

**Structured Queries:**
- `{namespace="rocketchat", container=~"rocketchat.*"}` - Application logs
- `{namespace="rocketchat"} |~ "(?i)(error|exception|failed)"` - Error filtering
- `{namespace="rocketchat"} |~ "(?i)(slow|timeout|latency)"` - Performance issues

**Log Volume Analysis:**
- `sum by (container) (rate({namespace="rocketchat"}[5m]))` - Log rates by service
- `sum by (level) (rate({namespace="rocketchat"} |~ "level=(debug|info|warn|error|fatal)" [5m]))` - Log levels

### **Best Practices Implemented**

#### **Dashboard Design**
- **3-Column Layout**: Optimized for different screen sizes
- **Color Coding**: Consistent color scheme for different metric types
- **Time Ranges**: Appropriate time ranges for different metrics (2h default)
- **Refresh Rates**: 30-second refresh for real-time monitoring

#### **Log Management**
- **Structured Queries**: Using LogQL for efficient log filtering
- **Error Highlighting**: Automatic error log detection and display
- **Performance Tracking**: Log-based performance issue detection
- **Service Separation**: Separate log views for different services

#### **Alerting Integration**
- **Threshold Monitoring**: Visual thresholds for critical metrics
- **Trend Analysis**: Historical data for capacity planning
- **Correlation**: Metrics and logs in same dashboard for troubleshooting

## 📋 **Next Session Tasks (MongoDB Enhancement)**

### **Deploy MongoDB Exporter (Optional)**
```bash
# Add MongoDB exporter for detailed database metrics
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install mongodb-exporter prometheus-community/prometheus-mongodb-exporter \
  -n rocketchat \
  --set mongodb.uri="mongodb://mongodb.rocketchat.svc.cluster.local:27017" \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=monitoring

# Verify exporter is working
kubectl get pods -n rocketchat | grep mongodb-exporter
kubectl port-forward -n rocketchat svc/mongodb-exporter 9216:9216
curl http://127.0.0.1:9216/metrics | head -10
```

### **Update MongoDB Dashboard Panel**
```promql
# Once exporter is deployed, update the MongoDB Status panel query to:
up{job="mongodb-exporter"}
```

---

**Need Help?** Check the [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md#monitoring-stack-issues) for common issues and solutions.
