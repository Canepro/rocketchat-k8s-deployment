# 🔧 Rocket.Chat AKS Deployment Troubleshooting Guide

**Created**: September 4, 2025
**Last Updated**: September 23, 2025 (Security Hardening + Alerts Testing & Domain Migration)
**Purpose**: Comprehensive troubleshooting guide for Rocket.Chat deployment on Azure Kubernetes Service
**Scope**: Official Helm chart deployment with enhanced monitoring
**Status**: Living document - updated as issues are encountered and resolved
**Current Status**: Security hardening completed - Exposed credentials removed, local secrets management implemented. Currently executing alerts testing and domain migration (grafana.chat.canepro.me → grafana.canepro.me) (Updated: September 23, 2025)

## 🏆 **MONITORING STACK: SECURITY HARDENED & PRODUCTION READY**
- ✅ **Rocket.Chat Metrics**: 1238+ series flowing, all dashboards operational
- ✅ **Prometheus**: ServiceMonitor discovery resolved, all targets UP
- ✅ **Grafana**: Beautiful real-time dashboards with corrected panels and proper data
- ✅ **Loki 2.9.0**: Log aggregation with volume API support for advanced log visualization
- ✅ **Alertmanager**: Email notifications configured with secure webhook integration
- ✅ **Dashboard Panels**: Fixed Pod Restarts panel and added Total vs Active Users panel
- ✅ **🆕 CPU/Memory Analytics**: 6 comprehensive resource monitoring panels with efficiency metrics
- ✅ **🆕 Resource Efficiency**: Real-time utilization vs limits with optimization insights
- ✅ **🆕 Node-Level Monitoring**: Cluster-wide resource health visibility
- ✅ **🆕 Historical Trending**: 24h resource patterns for capacity planning
- ✅ **🆕 Security Hardening**: Exposed credentials removed, local secrets management implemented
- 🔄 **Today's Progress**: Executing alerts testing and domain migration (grafana.chat.canepro.me → grafana.canepro.me)

## 🔐 **SECURITY IMPROVEMENTS: LOCAL SECRETS MANAGEMENT**

### **Issue Addressed: Exposed Credentials in Repository**
**Problem:** Gmail credentials and Rocket.Chat webhook tokens were hardcoded in Kubernetes manifests, creating security vulnerabilities.

**Solution Implemented:**
- ✅ **Removed hardcoded credentials** from `alertmanager-configmap.yaml`
- ✅ **Created local `.env` file** for real credentials (ignored by Git)
- ✅ **Implemented `apply-secrets.sh` script** for secure credential deployment
- ✅ **Added `.env.example` template** for team collaboration

### **New Secure Workflow**
```bash
# 1. Copy template (safe for repository)
cp .env.example .env

# 2. Edit with real credentials
nano .env  # Your real Gmail app password & webhook token

# 3. Apply to cluster securely
./scripts/apply-secrets.sh
```

### **Security Benefits**
- ✅ **Repository Safe**: Only placeholders committed to Git
- ✅ **Team Friendly**: Each developer uses their own `.env`
- ✅ **Audit Clean**: No credential history in Git
- ✅ **Easy Updates**: One command reapplies all secrets

### **Credentials Now Secured**
- **Gmail SMTP**: App password stored securely in Kubernetes secret
- **Rocket.Chat Webhook**: Token applied via AlertmanagerConfig
- **Alert Emails**: Configured via environment variables

**Status:** ✅ **Security hardening complete - ready for production deployment**

### **📋 CURRENT ALERTS TESTING PROGRESS**

**✅ Completed Setup:**
- [x] Verify local `.env` file has correct credentials
- [x] Run `./scripts/apply-secrets.sh` to ensure secrets are current
- [x] Check AlertmanagerConfig status: `kubectl get alertmanagerconfig -n monitoring`

**🔄 In Progress - Alert Testing Sequence:**
- [ ] **Email Alerts**: Send test alert and verify Gmail delivery
- [ ] **Rocket.Chat Alerts**: Trigger alert and verify webhook message in #alerts
- [ ] **Alert Rules**: Test each alert rule in `rocket-chat-alerts.yaml`
- [ ] **SMTP Configuration**: Verify Gmail App Password is working
- [ ] **Webhook Integration**: Confirm Rocket.Chat receives and displays alerts

### **🌐 DOMAIN MIGRATION PROGRESS (grafana.chat.canepro.me → grafana.canepro.me)**

**✅ DNS Status:** Domain `grafana.canepro.me` already configured and resolving to AKS IP (4.250.169.133)

**🔄 Migration Tasks:**
- [ ] Create new ingress for `grafana.canepro.me` with SSL certificate
- [ ] Update dashboard configurations to use new domain
- [ ] Test new domain accessibility and SSL
- [ ] Switch primary domain (cutover)
- [ ] Cleanup old domain configuration

**Test Commands:**
```bash
# Test email alert delivery
kubectl exec -n monitoring deployment/monitoring-kube-prometheus-alertmanager -- \
  amtool alert add alertname=TestAlert severity=warning message="Test alert from troubleshooting"

# Check alertmanager logs
kubectl logs -n monitoring deployment/monitoring-kube-prometheus-alertmanager --tail=10

# Verify webhook delivery (check Rocket.Chat #alerts channel)
```

**Expected Results:**
- ✅ Email received within 5 minutes at configured address
- ✅ Rocket.Chat webhook message appears in #alerts channel
- ✅ Alertmanager logs show successful delivery
- ✅ No authentication errors in logs

**If Issues Found:**
- 🔄 Check Gmail App Password validity
- 🔄 Regenerate Rocket.Chat webhook token if needed
- 🔄 Verify email address configuration
- 🔄 Test SMTP connectivity manually

---

## 🚨 **Most Common Issues & Quick Fixes**

### **Dashboard Shows "No Data" but Targets are UP**
**Quick Fix:** ServiceMonitor discovery issue - restart Prometheus:
```bash
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
# Wait 3-5 minutes for target rediscovery
```

### **Metrics Endpoint Not Responding**
**Quick Fix:** Test metrics directly:
```bash
kubectl run debug-pod --image=curlimages/curl --rm -i --tty -- /bin/sh
curl http://rocketchat-rocketchat-monolith-ms-metrics.rocketchat.svc.cluster.local:9458/metrics
```

### **Port-Forward Connection Refused**
**Quick Fix:** Use pod name instead of service:
```bash
kubectl port-forward -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 9091:9090
```

### **ServiceMonitor Not Discovered**
**Quick Fix:** Check API group and recreate:
```bash
kubectl get servicemonitors.monitoring.coreos.com -n monitoring | grep rocketchat
kubectl apply -f aks/monitoring/rocketchat-servicemonitors.yaml
```

### **Dashboard Not Appearing in Grafana UI**
**Symptoms:**
- ConfigMap exists with dashboard JSON
- Dashboard sidecar logs show no processing activity
- Dashboard missing from Grafana dashboard list

**Quick Fix:** Add required label to ConfigMap:
```bash
# Check if ConfigMap has grafana_dashboard=1 label
kubectl get configmap <dashboard-configmap-name> -n monitoring --show-labels

# Add the required label if missing
kubectl label configmap <dashboard-configmap-name> -n monitoring grafana_dashboard=1

# Verify dashboard processing in sidecar logs
kubectl logs -n monitoring <grafana-pod> -c grafana-sc-dashboard --tail=10
```

**Root Cause:** Grafana's dashboard sidecar only processes ConfigMaps with the `grafana_dashboard=1` label.

### **Dashboard Import Fails with JSON Syntax Errors**
**Symptoms:**
- ConfigMap labeled correctly but dashboard not visible in Grafana
- Dashboard file exists in sidecar but Grafana shows import errors
- Error logs: "invalid character" or "failed to load dashboard"

**Quick Fix:** Validate and fix JSON syntax issues:
```bash
# Check for JSON syntax errors
python3 -m json.tool aks/monitoring/dashboard.json

# Fix common issues:
# 1. Convert Windows to Unix line endings
sed -i 's/\r$//' aks/monitoring/dashboard.json

# 2. Convert multi-line strings to single line in JSON
# Change: "expr": "(\n  sum(metric1) +\n  sum(metric2)\n)" 
# To: "expr": "(sum(metric1) + sum(metric2))"

# 3. Validate and update ConfigMap
python3 -m json.tool dashboard.json > /dev/null && kubectl create configmap dashboard-name --from-file=dashboard.json -n monitoring --dry-run=client -o yaml | kubectl apply -f -
```

**Root Cause:** JSON syntax errors (Windows line endings, multi-line string literals) prevent Grafana from parsing dashboard files.

### **Enhanced CPU/Memory Monitoring Issues**

#### **CPU/Memory Panels Show "No Data"**
**Symptoms:**
- Panels 15-16, 29-34 (CPU/Memory analytics) display "No data"
- Node Exporter and cadvisor targets are UP in Prometheus
- Other dashboard panels work correctly

**Quick Fix:** Check Node Exporter and cAdvisor metrics availability:
```bash
# Verify Node Exporter is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=node-exporter

# Check cAdvisor metrics from kubelet
kubectl proxy --port=8001 &
curl "http://127.0.0.1:8001/api/v1/nodes/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')/proxy/metrics/cadvisor" | grep container_cpu_usage_seconds_total

# Test resource limit metrics
kubectl proxy --port=8001 &
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=kube_pod_container_resource_limits" | jq '.data.result[] | select(.metric.namespace=="rocketchat")'
```

**Root Cause:** Missing Node Exporter deployment or kube-state-metrics not collecting resource limit data.

#### **Resource Efficiency Panels Show Invalid Values**
**Symptoms:**
- CPU/Memory Efficiency panels (29-30) show 0% or infinity values
- Resource limits not properly configured for pods
- Division by zero errors in Prometheus queries

**Quick Fix:** Verify resource limits are set on pods:
```bash
# Check if pods have resource limits configured
kubectl get pods -n rocketchat -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# Verify kube-state-metrics is exposing limit data
kubectl port-forward -n monitoring svc/monitoring-kube-state-metrics 8080:8080 &
curl http://localhost:8080/metrics | grep "kube_pod_container_resource_limits.*rocketchat"

# Check for missing resource limits
kubectl describe pods -n rocketchat | grep -A5 -B5 "Limits:"
```

**Solution:** Add resource limits to pods if missing:
```yaml
# In values-official.yaml or deployment spec
resources:
  limits:
    cpu: 500m
    memory: 1536Mi
  requests:
    cpu: 250m
    memory: 512Mi
```

#### **Historical Trends Panel (33) Shows Flat Lines**
**Symptoms:**
- Resource Usage Trends panel shows constant flat lines
- No historical variation in CPU/memory usage
- Time range selector doesn't affect the data

**Quick Fix:** Check Prometheus retention and query time range:
```bash
# Verify Prometheus retention period
kubectl get prometheus -n monitoring monitoring-kube-prometheus-prometheus -o jsonpath='{.spec.retention}'

# Test historical data availability
kubectl proxy --port=8001 &
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query_range?query=rate(container_cpu_usage_seconds_total[5m])&start=$(date -d '1 day ago' -u +%s)&end=$(date -u +%s)&step=300" | jq '.data.result | length'

# Check for consistent metrics collection
kubectl port-forward -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 9091:9090 &
# Visit: http://localhost:9091/graph
# Query: rate(container_cpu_usage_seconds_total{namespace="rocketchat"}[5m])
```

**Root Cause:** Insufficient Prometheus retention period or recent deployment without historical data.

#### **MongoDB Resource Panel (34) Shows No MongoDB Data**
**Symptoms:**
- Panel 34 (MongoDB Resource Usage) displays no metrics
- MongoDB pods are running and healthy
- Other MongoDB-related panels work

**Quick Fix:** Verify MongoDB pod labeling and metrics:
```bash
# Check MongoDB pod labels
kubectl get pods -n rocketchat -l app=mongodb --show-labels

# Verify MongoDB pods match the query pattern
kubectl get pods -n rocketchat -o name | grep mongodb

# Test MongoDB resource query directly
kubectl proxy --port=8001 &
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=rate(container_cpu_usage_seconds_total{namespace=\"rocketchat\",pod=~\"mongodb-.*\"}[5m])" | jq '.data.result'
```

**Solution:** Update MongoDB pod selector in dashboard if labels don't match:
```json
// Update the query in Panel 34 if MongoDB pods use different naming
"expr": "sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"rocketchat\", pod=~\"<actual-mongodb-pod-pattern>.*\", image!=\"\"}[5m])) * 100"
```

#### **Node-Level Panels (31-32) Show Cluster Averages Instead of Individual Nodes**
**Symptoms:**
- Node CPU/Memory Usage panels show only average values
- Cannot see per-node resource distribution
- All nodes appear to have identical usage

**Quick Fix:** Modify queries to show per-node breakdown:
```bash
# Test individual node metrics
kubectl proxy --port=8001 &
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=100-(avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m]))by(instance)*100)" | jq '.data.result'

# Check if multiple nodes are reporting
kubectl get nodes -o wide
kubectl port-forward -n monitoring svc/monitoring-prometheus-node-exporter 9100:9100 &
curl http://localhost:9100/metrics | grep node_cpu_seconds_total | head -5
```

**Solution:** Update panel queries to show per-instance breakdown:
```json
// For per-node CPU usage (modify Panel 31)
"expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
"legendFormat": "{{instance}}"

// For per-node memory usage (modify Panel 32) 
"expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
"legendFormat": "{{instance}}"
```

### **Loki Volume API 404 Error**
**Symptoms:** 
- Console error: `GET https://grafana.chat.canepro.me/api/datasources/uid/loki/resources/index/volume?end=... 404 (Not Found)`
- Grafana shows "Log volume has not been configured" message
- Loki version 2.6.1 doesn't support volume API

**Root Cause:** 
1. Loki version 2.6.1 doesn't support volume API feature
2. Grafana datasource pointing to wrong Loki service URL

**Complete Fix:**
```bash
# Step 1: Upgrade Loki to version 2.9.0 (supports volume API)
helm upgrade loki grafana/loki-stack --namespace monitoring --values aks/monitoring/loki-values.yaml --timeout=600s

# Step 2: Fix Grafana datasource URL (if needed)
kubectl patch configmap grafana-datasource-loki -n monitoring --type='merge' -p='{"data":{"loki.yaml":"# Automatically provisioned Loki datasource\napiVersion: 1\ndatasources:\n  - name: Loki\n    type: loki\n    uid: loki\n    url: http://loki.monitoring.svc.cluster.local:3100\n    access: proxy\n    isDefault: true\n    editable: false\n    jsonData:\n      maxLines: 2000\n      timeout: 60\n      manageAlerts: false\n      derivedFields: []\n      httpHeaderName1: \"X-Scope-OrgID\"\n    secureJsonData: {}\n"}}'

# Step 3: Restart Grafana to pick up datasource changes
kubectl rollout restart deployment/monitoring-grafana -n monitoring
kubectl rollout status deployment/monitoring-grafana -n monitoring --timeout=300s
```

**Configuration Changes:**
- Upgraded Loki from 2.6.1 → 2.9.0 (supports volume API)
- Updated Grafana datasource URL from `loki-stack.loki-stack.svc.cluster.local:3100` → `loki.monitoring.svc.cluster.local:3100`

### **Dashboard Panel Shows Wrong Data**
**Symptoms:**
- "Rocket.Chat Pod Restarts" panel shows "Total Users" data instead of pod restart metrics
- Panel title doesn't match the data being displayed

**Root Cause:** Incorrect Prometheus query in dashboard panel configuration

**Quick Fix:** Apply the corrected dashboard:
```bash
# Apply the fixed dashboard configuration
kubectl apply -f aks/monitoring/rocket-chat-dashboard-configmap.yaml -n monitoring

# Restart Grafana to load updated dashboard
kubectl rollout restart deployment/grafana -n monitoring

# Wait for restart
kubectl rollout status deployment/grafana -n monitoring --timeout=300s
```

**Configuration Changes:**
- Fixed Pod Restarts panel query: `increase(kube_pod_container_status_restarts_total{namespace="rocketchat", pod=~"rocketchat.*"}[5m])`
- Added proper Total Users vs Active Users panel with separate queries

### **Dashboard Panel Legends Show Duplication or Are Non-Descriptive**
**Symptoms:**
- Multiple series in dashboard panels show identical legend labels (e.g., "Average Response Time" appears multiple times)
- Legends don't distinguish between different pods, methods, or instances
- Hard to identify which series corresponds to which data source
- Panels affected: API Response Time, API Request Rate, Meteor Methods Performance, CPU/Memory Utilization, Pod Status, Notifications, Resource Usage Trends, MongoDB Resource Usage

**Root Cause:** Generic `legendFormat` values in dashboard panel configurations don't include distinguishing labels like `{{pod}}`, `{{method}}`, or `{{instance}}`, causing duplicates when multiple series exist.

**Quick Fix:** Apply the updated ConfigMap with improved legend formats:
```bash
# Apply the corrected dashboard configuration with improved legends
kubectl apply -f aks/monitoring/rocket-chat-dashboard-comprehensive-configmap.yaml -n monitoring

# Restart Grafana to load updated dashboard
kubectl rollout restart deployment/monitoring-grafana -n monitoring

# Wait for restart
kubectl rollout status deployment/monitoring-grafana -n monitoring --timeout=300s
```

**Configuration Changes:**
- **API Response Time (Panel 7)**: Added `{{pod}}` and `{{method}}` to legends for unique identification
- **API Request Rate (Panel 8)**: Enhanced legends with pod and method context
- **Meteor Methods Performance (Panel 12)**: Added pod context to method time and rate legends
- **CPU Utilization (Panel 15)**: Improved legends to show pod-specific CPU usage and limits
- **Memory Usage (Panel 16)**: Added descriptive labels for memory usage vs limits per pod
- **Pod Status (Panel 17)**: Maintained pod-specific legends for running status
- **Pod Restarts (Panel 18)**: Added "Restarts" suffix to distinguish restart metrics
- **Notifications Sent (Panel 21)**: Added pod context to notification rate legends
- **Resource Usage Trends (Panel 33)**: Enhanced with descriptive labels for aggregated metrics
- **MongoDB Resource Usage (Panel 34)**: Improved legends for CPU and memory usage per MongoDB pod

**Verification Steps:**
1. Refresh the Rocket.Chat dashboard in Grafana
2. Navigate to affected panels and check legends for uniqueness
3. Use Query Inspector to verify series count matches legend count
4. Test with different time ranges to ensure legends remain distinct

### **Dashboard Best Practices Enhancements**

**Recent Dashboard Improvements Applied (September 2025):**
The Rocket.Chat monitoring dashboard has been enhanced with best practices implementations for improved user experience, performance, and maintainability.

**Enhanced Features:**
- **Panel Descriptions**: Added hover descriptions to key panels explaining their purpose and what they monitor
- **Template Variables**: Added namespace filtering capability for multi-environment deployments
- **Extended Time Ranges**: Added 3h and 3d time range options for better granularity
- **Query Performance Limits**: Added maxDataPoints limits to prevent performance issues with high-cardinality metrics
- **Deployment Annotations**: Added Kubernetes deployment event annotations for timeline correlation
- **Improved Legends**: Enhanced legend formatting for better readability and uniqueness

**Dashboard Structure Enhancements:**
- **Panel Descriptions**: Critical panels now include detailed explanations (Uptime SLO, API Response Time, CPU Utilization, MongoDB Resources)
- **Template Variables**: Namespace dropdown for flexible multi-environment monitoring
- **Time Range Options**: Expanded from 8 to 11 options including 3h and 3d for operational flexibility
- **Query Optimization**: Added maxDataPoints: 100 to resource monitoring panels (CPU, Memory, MongoDB)
- **Annotations**: Deployment events marked on timelines with green indicators
- **Legend Consistency**: Standardized legend formats across all resource monitoring panels

**Performance Improvements:**
- **Query Limits**: Prevents Grafana performance degradation with large numbers of series
- **Optimized Aggregation**: Resource panels limited to 100 data points maximum
- **Efficient Queries**: Maintained optimal Prometheus query patterns with proper aggregation

**User Experience Enhancements:**
- **Better Tooltips**: Panel descriptions provide context for complex metrics
- **Improved Navigation**: Template variables enable easier environment switching
- **Enhanced Time Selection**: More granular time range options for different monitoring scenarios
- **Clearer Legends**: Consistent formatting makes series identification easier

**Maintenance Benefits:**
- **Scalable Design**: Template variables support multi-namespace deployments
- **Performance Safeguards**: Query limits prevent dashboard slowdowns
- **Event Correlation**: Deployment annotations help correlate metrics with changes
- **Documentation**: Self-documenting panels reduce learning curve

### **Dashboard Panel Improvements (September 2025)**

**Panel Redesign for Better Information Architecture:**

**Fixed Double Information Issues:**
- **Messages per Second Panel**: Changed from rate-based timeseries to proper stat panel showing "Total Messages Sent"
- **Added New Messages per Second Timeseries**: New dedicated timeseries panel showing real-time message rates
- **Resolved Redundancy**: Eliminated confusion between total messages and rate metrics

**New Advanced Panel Types:**
- **Table Panel**: "Top Resource Consumers" - Shows top 10 pods by CPU/memory usage with sortable columns
- **Heatmap Panel**: "Log Levels Heatmap" - Visual representation of log level patterns over time
- **Enhanced Layout**: Better information hierarchy and reduced visual clutter

**Panel-Specific Improvements:**
- **Stat Panels**: Active Users, Total Users, Total Messages Sent now show current values instead of rates
- **Timeseries Panels**: Messages per Second, Message Types Distribution provide complementary rate information
- **Table Panel**: Sortable by CPU usage, shows both CPU % and Memory MB for top consumers
- **Heatmap Panel**: Color-coded visualization of log level frequency patterns

**User Experience Enhancements:**
- **Clearer Information Hierarchy**: Stat panels show current state, timeseries show trends
- **Advanced Visualizations**: Table and heatmap panels provide deeper insights
- **Reduced Cognitive Load**: Eliminated redundant information display
- **Better Resource Monitoring**: Table panel helps identify problematic pods quickly

**Technical Implementation:**
- **Proper Panel Types**: Stat panels for current values, timeseries for trends
- **Advanced Visualizations**: Table sorting, heatmap color schemes (Viridis)
- **Performance Optimized**: Added maxDataPoints limits to new panels
- **Responsive Design**: Full-width panels for comprehensive views

**Migration Path:**
- **Backward Compatible**: Existing functionality preserved
- **Progressive Enhancement**: New panels add value without breaking workflows
- **Information Architecture**: Clear separation between current state and trending data

### **Template Variables and Multi-Environment Support (September 2025)**

**Expanded Environment Management:**

**Environment Template Variable:**
- **Variable Name**: `$namespace`
- **Type**: Custom dropdown selector
- **Current Options**:
  - Production (rocketchat) - *Default/Current*
  - Development (dev-rocketchat)
  - Staging (staging-rocketchat)
  - QA (qa-rocketchat)

**Pod Filter Template Variable:**
- **Variable Name**: `$pod_filter`
- **Type**: Dynamic query-based selector
- **Purpose**: Filter specific pods within selected namespace
- **Query**: `label_values(kube_pod_info{namespace="$namespace"}, pod)`

**Implementation Benefits:**
- **Namespace-Aware Queries**: All Prometheus and Loki queries automatically update when switching environments
- **Dynamic Pod Selection**: Pod filter dynamically populates based on selected namespace
- **URL Persistence**: Environment selection preserved in dashboard URLs for bookmarking/sharing

**How Environment Switching Works:**
```yaml
# Template Variable Definition
"templating": {
  "list": [
    {
      "name": "namespace",
      "label": "Environment",
      "options": [
        {"text": "Production (rocketchat)", "value": "rocketchat"},
        {"text": "Development (dev-rocketchat)", "value": "dev-rocketchat"},
        {"text": "Staging (staging-rocketchat)", "value": "staging-rocketchat"},
        {"text": "QA (qa-rocketchat)", "value": "qa-rocketchat"}
      ]
    }
  ]
}

# Query Usage Examples
"expr": "kube_pod_status_phase{namespace=\"$namespace\", phase=\"Running\"}"  # Prometheus
"expr": "{namespace=\"${namespace}\", app!=\"mongodb\"}"                    # Loki
```

**Deployment Tracking Enhancement:**
- **Annotation Query**: `kube_deployment_created{namespace="$namespace"}`
- **Cross-Environment Correlation**: Deployment markers show in all environments
- **Multi-Environment Timelines**: Compare deployment impacts across dev/staging/prod

**Best Practices Implementation:**
- **Scalable Architecture**: Template variables enable unlimited environment expansion
- **Query Consistency**: All metrics automatically scoped to selected environment
- **Operational Efficiency**: Single dashboard serves multiple environments
- **Change Management**: Environment-specific deployment tracking

**Usage Scenarios:**
1. **Environment Comparison**: Switch between prod/dev to compare performance
2. **Deployment Validation**: Monitor staging before promoting to production
3. **Incident Analysis**: Correlate issues across environments
4. **Capacity Planning**: Analyze resource usage patterns by environment

**Adding New Environments:**
```bash
# Create new namespace
kubectl create namespace new-environment-rocketchat

# Deploy Rocket.Chat
helm install new-environment-rocketchat rocketchat/rocketchat \
  --namespace new-environment-rocketchat

# Update dashboard template variables to include new environment
# Dashboard automatically detects and monitors new environment
```

### **Dashboard Layout and Display Issues (September 2025)**

**Fixed Layout Overlaps and Blank Spaces:**

**Panel Overlap Issues:**
- **Top Resource Consumers table** was overlapping with **MongoDB Resource Usage panel**
- **Pod Status/Pod Restarts panels** were overlapping with **Resource Usage Trends/MongoDB Resource Usage**
- **MongoDB Status/Log Ingest Rate/Notifications Sent** panels were overlapping with **Pod Status/Pod Restarts**

**Resolution Applied:**
- Repositioned **MongoDB Resource Usage** from y=60 to y=68 (next to Resource Usage Trends)
- Moved **Pod Status** and **Pod Restarts** from y=68 to y=76
- Relocated **MongoDB Status**, **Log Ingest Rate**, and **Notifications Sent** to y=84
- Adjusted **Rocket.Chat Application Logs** from y=84 to y=96
- Moved **Log Levels Heatmap** from y=112 to y=108

**Layout Improvements:**
- Eliminated all panel overlaps causing blank spaces
- Maintained logical flow: Resource monitoring → Kubernetes health → Logging
- Optimized use of dashboard real estate
- Ensured responsive full-width panels for advanced visualizations

**Fixed Stat Panel Duplicate Display:**

**Issue:** Stat panels (Active Users, Total Users, Total Messages Sent) displayed numbers twice (e.g., "4 4", "7 7")

**Root Cause:** Missing `options` configuration in stat panels, causing Grafana to display both value and additional metadata

**Resolution:**
- Added `"options": {"graphMode": "none", "textMode": "value"}` to all stat panels
- Ensures clean single-value display
- Prevents duplicate number rendering
- Maintains proper threshold coloring

**Livechat Performance Panel Enhancement:**

**Issue:** Livechat metrics may not be available if livechat features are disabled

**Improvements:**
- Added descriptive panel explanation
- Enhanced webhook queries with fallback: `or vector(0)`
- Changed "Webhook Failures" to "Webhook Failure Rate" for clarity
- Added panel description noting dependency on livechat feature enablement

**Technical Fixes:**
- **Panel Repositioning**: Resolved grid coordinate conflicts
- **Stat Panel Options**: Added proper display configuration
- **Query Fallbacks**: Graceful handling of unavailable metrics
- **Layout Optimization**: Eliminated visual gaps and overlaps

### **Loki Volume API 404 Error in Logs Tab (RECURRING ISSUE)**

**Symptoms:**
- Logs tab shows errors when opened
- Browser console shows: `GET /api/datasources/uid/loki/resources/index/volume 404 (Not Found)`
- loki-explore-app plugin fails to load volume statistics
- Error message: `{"message":"not found"}`

**Root Cause:** This issue has recurred despite previous attempts to enable Loki's volume API. The volume API configuration may not be properly applied or supported in the current Loki deployment.

**Historical Context:**
- **Previously encountered:** Loki 2.6.1 → 2.9.0 upgrade was attempted to fix this
- **Issue persisted:** Volume API still not functional despite version upgrade
- **Current status:** Alternative solution applied - volume queries disabled

**Applied Solution (Volume Queries Disabled):**
```bash
# Disable volume API calls in Grafana datasource (safe, non-disruptive)
kubectl patch configmap grafana-datasource-loki -n monitoring --type merge -p '{
  "data": {
    "loki.yaml": "apiVersion: 1\ndatasources:\n  - name: Loki\n    type: loki\n    uid: loki\n    url: http://loki.monitoring.svc.cluster.local:3100\n    access: proxy\n    isDefault: true\n    editable: false\n    jsonData:\n      maxLines: 2000\n      timeout: 60\n      manageAlerts: false\n      volumeDisabled: true\n      derivedFields: []\n      httpHeaderName1: \"X-Scope-OrgID\"\n    secureJsonData: {}\n"
  }
}'

# Restart Grafana
kubectl rollout restart deployment/monitoring-grafana -n monitoring
```

**Impact of Solution:**
- ✅ **Eliminates 404 errors** - No more volume API failures
- ✅ **Preserves functionality** - Logs still work, just without volume statistics
- ✅ **Non-disruptive** - No changes to Loki deployment
- ✅ **Stable** - Won't break if Loki is upgraded/restarted

**Verification:**
1. Refresh Grafana and open the logs tab
2. Check browser console - should see no 404 volume API errors
3. loki-explore-app loads without volume statistics
4. All other log functionality remains intact

**Note:** This is a persistent issue with Loki's volume API implementation. Disabling volume queries provides a stable workaround while maintaining full log aggregation capabilities.

### **Rocket.Chat Integration Creation 400 Error**

**Symptoms:**
- `POST /api/v1/integrations.create 400 (Bad Request)` when creating webhooks
- Cannot create incoming webhooks for alert notifications
- Integration creation fails in Rocket.Chat admin panel
- Error appears when trying to save webhook configuration

**Root Cause:** Insufficient permissions, disabled integrations, or missing admin privileges for webhook creation.

**Quick Diagnosis:**
```bash
# Check if you're logged in as admin user
# Go to: https://chat.canepro.me/admin/users
# Verify your user has "admin" role assigned

# Check if integrations are enabled globally
# Admin → Settings → General → Integrations → Should be "True"
```

**Solutions:**

#### **Option A: Verify Admin Permissions**
1. **Log in** as the Rocket.Chat admin user (usually the first user created during setup)
2. **Navigate to**: `https://chat.canepro.me/admin/users`
3. **Find your user account** and ensure the "admin" role is assigned
4. **If not admin**: Contact the Rocket.Chat administrator to grant admin privileges

#### **Option B: Enable Integrations Feature**
1. **Go to**: Admin → Settings → General
2. **Find**: "Integrations" section
3. **Set**: "Enable" to "True"
4. **Save changes** and retry webhook creation

#### **Option C: Create Integration via MongoDB (Advanced)**
```bash
# If UI/API fails, create directly in database
kubectl exec -it deployment/rocketchat-rocketchat -n rocketchat -- mongo rocketchat

# Insert webhook integration
db.integrations.insert({
  "type": "webhook-incoming",
  "name": "Alert Bot",
  "enabled": true,
  "username": "alert-bot",
  "channel": "#alerts",
  "scriptEnabled": true,
  "createdAt": new Date(),
  "createdBy": {
    "_id": "SYSTEM",
    "username": "system"
  },
  "token": "generate-random-token-here"
});

# Find the generated webhook URL
db.integrations.find({"name": "Alert Bot"}, {"_id": 1, "token": 1});
```

#### **Option D: Use Rocket.Chat REST API**
```bash
# Get authentication token first
curl -X POST "https://chat.canepro.me/api/v1/login" \
  -H "Content-Type: application/json" \
  -d '{"user": "admin-username", "password": "admin-password"}'

# Use the returned authToken and userId to create integration
curl -X POST "https://chat.canepro.me/api/v1/integrations.create" \
  -H "X-Auth-Token: YOUR_AUTH_TOKEN" \
  -H "X-User-Id: YOUR_USER_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "webhook-incoming",
    "name": "Alert Bot",
    "enabled": true,
    "username": "alert-bot",
    "channel": "#alerts",
    "scriptEnabled": true
  }'
```

**Verification:**
1. **Check integrations list**: Admin → Integrations → Should show "Alert Bot"
2. **Test webhook**: Copy the webhook URL and send a test POST request
3. **Verify permissions**: User should have admin role in user management

**Webhook URL Format:**
```
https://chat.canepro.me/hooks/INTEGRATION_ID/TOKEN
```

**Common Issues:**
- **403 Forbidden**: User lacks admin permissions
- **400 Bad Request**: Missing required fields or invalid channel name
- **Integration Disabled**: Feature not enabled in Rocket.Chat settings

**Note:** Integration creation requires admin privileges. Ensure you're logged in as an administrator and that integrations are enabled globally.

### **Grafana Loki Datasource Connection Error**
**Symptoms:**
- Error: `dial tcp: lookup loki-stack.loki-stack.svc.cluster.local on 10.0.0.10:53: no such host`
- Grafana Explore page shows DNS lookup failure for Loki
- Loki queries fail with connection errors

**Root Cause:** Grafana datasource configured with old Loki service URL after Loki migration

**Quick Fix:** Update datasource URL to correct service:
```bash
# Update Grafana datasource to point to correct Loki service
kubectl patch configmap grafana-datasource-loki -n monitoring --type='merge' -p='{"data":{"loki.yaml":"# Automatically provisioned Loki datasource\napiVersion: 1\ndatasources:\n  - name: Loki\n    type: loki\n    uid: loki\n    url: http://loki.monitoring.svc.cluster.local:3100\n    access: proxy\n    isDefault: true\n    editable: false\n    jsonData:\n      maxLines: 2000\n      timeout: 60\n      manageAlerts: false\n      derivedFields: []\n      httpHeaderName1: \"X-Scope-OrgID\"\n    secureJsonData: {}\n"}}'

# Restart Grafana to apply changes
kubectl rollout restart deployment/monitoring-grafana -n monitoring
```

**Configuration Change:** Updated datasource URL from `loki-stack.loki-stack.svc.cluster.local:3100` → `loki.monitoring.svc.cluster.local:3100`

### **Automated Fix Script**
**One-Command Solution:** Use the automated fix script:
```bash
# Run the comprehensive fix script
./aks/scripts/fix-loki-volume-and-dashboard.sh
```

This script will:
1. ✅ Enable Loki volume API
2. ✅ Fix dashboard panel data issues  
3. ✅ Add proper Total Users vs Active Users panel
4. ✅ Restart all necessary services

**✅ Successfully Resolved Issues:**
- PVC deadlock causing pod scheduling failures
- Rocket.Chat EE license causing DDP streamer crashes
- Grafana 404 errors due to missing ingress
- Grafana authentication issues (credentials resolved)
- MongoDB connection string conflicts
- Environment variable configuration issues
- **Grafana dashboards showing no data (metrics label mismatch resolved)**
- **PodMonitor vs ServiceMonitor conflicts (Helm-managed solution implemented)**

---

## 📋 **Guide Overview**

This troubleshooting guide covers common issues encountered during Rocket.Chat deployment on AKS using official Helm charts. Each issue includes:

- **🔍 Symptoms** - How to identify the problem
- **🔍 Diagnosis** - How to investigate root cause
- **🔧 Solutions** - Step-by-step resolution steps
- **🛡️ Prevention** - How to avoid the issue in future

### **Quick Reference**
- [Deployment Issues](#deployment-issues)
- [AKS Cluster Issues](#aks-cluster-issues)
- [Helm Chart Problems](#helm-chart-problems)
- [Network & Ingress Issues](#network--ingress-issues)
- [SSL Certificate Problems](#ssl-certificate-problems)
- [Database Connection Issues](#database-connection-issues)
- [Application Startup Problems](#application-startup-problems)
- [Monitoring Stack Issues](#monitoring-stack-issues)
- [DNS Migration Issues](#dns-migration-issues)
- [Performance Problems](#performance-problems)
- [Cost-Related Issues](#cost-related-issues)

---

## � **Recent Issues & Solutions (September 19, 2025)**

### **Issue: Rocket.Chat Pods Stuck in Pending - PVC Terminating Deadlock**

**Symptoms:**
- Rocket.Chat pods in `Pending` status indefinitely
- `kubectl describe pod` shows: `0/2 nodes are available: persistentvolumeclaim "rocketchat-rocketchat" is being deleted`
- PVC shows `Terminating` status for extended periods (hours)
- `FailedScheduling` events mentioning PVC deletion
- Cluster autoscaler messages: `pod didn't trigger scale-up: 1 persistentvolumeclaim "rocketchat-rocketchat" is being deleted`
- Existing Rocket.Chat pods may be in `CrashLoopBackOff` due to missing MONGO_URL

**Root Cause:**
- PVC stuck in `Terminating` status due to `kubernetes.io/pvc-protection` finalizer
- Deadlock scenario: Pods can't start because PVC is terminating, but PVC can't delete because pods reference it
- Environment variable conflicts between direct values and secret references for MONGO_URL
- Often occurs after failed Helm upgrades or pod deletions during configuration changes

**Solutions:**

**Option A: Force Delete Stuck PVC (Recommended)**
```bash
# 1. Check PVC status
kubectl get pvc -n rocketchat
kubectl describe pvc rocketchat-rocketchat -n rocketchat

# 2. Remove PVC protection finalizer
kubectl patch pvc rocketchat-rocketchat -n rocketchat -p '{"metadata":{"finalizers":null}}'

# 3. Force delete the PVC
kubectl delete pvc rocketchat-rocketchat -n rocketchat --force --grace-period=0

# 4. Wait for cleanup and monitor new PVC creation
sleep 30
kubectl get pvc -n rocketchat
kubectl get pods -n rocketchat -w
```

**Option B: Fix Environment Variable Conflicts**
```bash
# If helm upgrade fails with patch order errors:
# Error: UPGRADE FAILED: failed to create patch: The order in patch list doesn't match

# 1. Update the secret with correct MongoDB URLs
kubectl patch secret rocketchat-rocketchat -n rocketchat \
  --type merge \
  -p '{"data":{"mongo-uri":"bW9uZ29kYjovL21vbmdvZGItZWFkeWxvYWRpbmctbW9uZ29kYi0wLm1vbmdvZGItZWFkeWxvYWRpbmctbW9uZ29kYi5zdmMuY2x1c3Rlci5sb2NhbDo1NDAwMy9yb2NrZXRjaGF0P3JlcGxpY2FTZXQ9cnMwJnJlYWRQcmVmZXJlbmNlPXByaW1hcnkg","mongo-oplog-uri":"bW9uZ29kYjovL21vbmdvZGItZWFkeWxvYWRpbmctbW9uZ29kYi0wLm1vbmdvZGItZWFkeWxvYWRpbmctbW9uZ29kYi5zdmMuY2x1c3Rlci5sb2NhbDo1NDAwMy9sb2NhbD9yZXBsaWNhU2V0PXJzMCZyZWFkUHJlZmVyZW5jZT1wcmltYXJ5"}}'

# 2. Remove conflicting extraEnv entries from values-official.yaml
# Comment out or remove MONGO_URL and MONGO_OPLOG_URL from extraEnv section

# 3. Apply the helm upgrade
helm upgrade rocketchat rocketchat/rocketchat -f config/helm-values/values-official.yaml -n rocketchat --wait --timeout=300s
```

**Prevention:**
- Avoid manual PVC deletions during pod restarts
- Use proper Helm upgrade procedures instead of manual pod management
- Monitor PVC status during deployments: `kubectl get pvc -n rocketchat`
- Don't mix direct environment variables with secret references in Helm charts
- Use `kubectl get events -n rocketchat --sort-by=.metadata.creationTimestamp` to monitor for scheduling issues

**Expected Resolution Time:** 2-5 minutes after PVC deletion

**Advanced Troubleshooting:**
```bash
# If PVC recreation fails, manually create it:
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rocketchat-rocketchat
  namespace: rocketchat
  labels:
    app.kubernetes.io/instance: rocketchat
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: rocketchat
    helm.sh/chart: rocketchat-6.25.3
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: default
  resources:
    requests:
      storage: 30Gi
EOF

# If environment variables still fail after PVC fix:
kubectl set env deployment/rocketchat-rocketchat -n rocketchat \
  MONGO_URL=mongodb://mongodb-headless.rocketchat.svc.cluster.local:27017/rocketchat \
  MONGO_OPLOG_URL=mongodb://mongodb-headless.rocketchat.svc.cluster.local:27017/local \
  NODE_ENV=production
```

**Related Issues:**
- **DDP Streamer Crash**: Apply same MONGO_URL fix to `rocketchat-ddp-streamer` deployment
- **Storage Class Issues**: Use `managed` instead of `default` for immediate PVC binding
- **Helm Chart Conflicts**: Direct `kubectl set env` bypasses Helm environment variable issues
- **EE License Issues**: See "Rocket.Chat EE License Causing Service Crashes" section below

**Success Indicators:**
- ✅ PVC status changes from `Terminating` to `Bound`
- ✅ Pod status changes from `Pending` to `Running`
- ✅ No `MONGO_URL must be set in environment` errors
- ✅ Rocket.Chat accessible at configured domain

**Verification:**
```bash
# Check all components are running
kubectl get pods -n rocketchat
kubectl get pvc -n rocketchat

# Verify Rocket.Chat access
curl -k https://chat.canepro.me/health

# Check application logs
kubectl logs -n rocketchat deployment/rocketchat-rocketchat
```

---

### **Issue: Rocket.Chat EE License Causing Service Crashes**

**Symptoms:**
- DDP Streamer pods show: `"Enterprise license not found. Shutting down..."`
- Services crash in CrashLoopBackOff despite MongoDB connectivity being fine
- Rocket.Chat functions but microservices fail due to license issues
- Logs show repeated license validation failures

**Root Cause:**
- Invalid or expired EE license in MongoDB cloud settings
- License synchronization issues between workspace and cloud
- Cloud registration token expired or workspace deregistered
- Manual removal of cloud settings without proper re-registration

**Solutions:**

**Option A: Reset Cloud Settings and Re-register (Recommended)**
```bash
# 1. Remove cloud settings from MongoDB (use correct mongosh command)
kubectl exec -n rocketchat mongodb-0 -- \
  mongosh "mongodb://127.0.0.1:27017/rocketchat" --eval '
    const r = db.rocketchat_settings.deleteMany({ _id: { $regex: /^Cloud_Workspace/ } });
    printjson(r);
    print("Cloud settings removed");
  '

# 2. Restart Rocket.Chat services
kubectl rollout restart deployment rocketchat-rocketchat -n rocketchat
kubectl rollout restart deployment rocketchat-ddp-streamer -n rocketchat
kubectl rollout restart deployment rocketchat-account -n rocketchat
kubectl rollout restart deployment rocketchat-authorization -n rocketchat

# 3. Re-register workspace via web UI:
# - Go to https://chat.canepro.me
# - Administration > Workspace > Register workspace
# - Paste your registration token
# - Administration > Subscription > Sync license update
```

**Option B: Manual License Update via Database**
```bash
# Direct database license update (if you have license key)
kubectl exec -n rocketchat mongodb-0 -- \
  mongosh "mongodb://127.0.0.1:27017/rocketchat" --eval '
    db.rocketchat_settings.updateOne(
      { _id: "Enterprise_License" },
      { $set: { value: "YOUR_LICENSE_KEY_HERE" } },
      { upsert: true }
    );
    print("License updated");
  '
```

**Prevention:**
- Regularly verify license status in Administration > Subscription
- Set up alerts for license expiration (EE feature)
- Keep cloud registration token secure and up-to-date
- Don't manually remove cloud settings without re-registration
- Monitor license validation in pod logs

**Expected Resolution Time:** 5-10 minutes after re-registration

**Success Indicators:**
- ✅ DDP Streamer runs without `"Enterprise license not found"` errors
- ✅ All microservices function with proper EE features
- ✅ License shows as active in Administration > Subscription
- ✅ No more CrashLoopBackOff on license-dependent services

**Verification:**
```bash
# Check all pods are stable
kubectl get pods -n rocketchat

# Check ddp-streamer logs for license messages
kubectl logs -n rocketchat deployment/rocketchat-ddp-streamer --tail=20

# Verify license status via API
curl -k https://chat.canepro.me/api/v1/licenses.info
```

**Related Issues:**
- **PVC Deadlock**: Can occur simultaneously with license issues
- **MongoDB Connectivity**: License issues can mask connectivity problems
- **Helm Environment Variables**: Ensure MONGO_URL is properly configured

---

### **Issue: Grafana Returns 404 Not Found**

**Symptoms:**
- `GET https://grafana.chat.canepro.me/ 404 (Not Found)`
- Grafana pod is running but not accessible via browser
- `kubectl get ingress -n monitoring` returns no resources
- Grafana service exists but no ingress routes traffic to it

**Root Cause:**
- Missing ingress resource for Grafana in the monitoring namespace
- Grafana service is running but not exposed externally
- Ingress configuration was not created during initial deployment
- Traffic cannot reach Grafana due to missing routing rules

**Solutions:**

**Option A: Create Grafana Ingress (Recommended)**
```bash
# Create ingress resource for Grafana
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - grafana.chat.canepro.me
    secretName: grafana-tls
  rules:
  - host: grafana.chat.canepro.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
EOF
```

**Option B: Port Forward for Temporary Access**
```bash
# Temporary access via port forwarding
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Access at: http://localhost:3000
```

**Prevention:**
- Always verify ingress resources after deployment: `kubectl get ingress --all-namespaces`
- Include Grafana ingress in initial deployment scripts
- Monitor ingress resources: `kubectl get ingress -n monitoring`
- Check service availability: `kubectl get svc -n monitoring`
- Use consistent naming conventions for ingress resources

**Expected Resolution Time:** 1-2 minutes after ingress creation

**Success Indicators:**
- ✅ Grafana accessible at `https://grafana.chat.canepro.me`
- ✅ SSL certificate issued for grafana.chat.canepro.me
- ✅ Login page loads successfully
- ✅ Ingress shows proper external IP and ports

**Verification:**
```bash
# Check ingress creation
kubectl get ingress -n monitoring

# Check certificate status
kubectl get certificate -n monitoring

# Test access
curl -k https://grafana.chat.canepro.me

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20
```

**Related Issues:**
- **Missing Services**: Ensure Grafana service exists before creating ingress
- **SSL Certificate Issues**: Certificate may take time to issue
- **DNS Configuration**: Ensure DNS points to correct ingress IP
- **Ingress Class**: Verify nginx ingress controller is running
- **Grafana Password**: Retrieve from `kubectl get secret grafana-admin -n monitoring`

**Grafana Credentials:**
```bash
# Check what credentials Grafana is actually using
kubectl exec deployment/monitoring-grafana -n monitoring -- env | grep GF_SECURITY_ADMIN

# Retrieve Grafana admin username from secret
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d

# Retrieve Grafana admin password from secret
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

# Alternative: Get complete secret
kubectl get secret grafana-admin -n monitoring -o yaml
```

**Grafana Authentication Troubleshooting:**
```bash
# Test login API directly
curl -k -X POST "https://grafana.chat.canepro.me/login" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"prom-operator"}'

# Check for authentication logs
kubectl logs -n monitoring deployment/monitoring-grafana | grep -i login

# Reset admin password (SOLUTION: This fixed the 401 error!)
kubectl exec deployment/monitoring-grafana -n monitoring -- \
  grafana-cli admin reset-admin-password prom-operator

# Verify login works after reset
curl -k -X POST "https://grafana.chat.canepro.me/login" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"prom-operator"}' \
  -s -o /dev/null -w "%{http_code}"
# Should return: 200 (success)
```

**⚠️ Note**: Grafana may use different credentials than stored in the secret. Check the actual environment variables in the pod using the first command above.

---

### **Issue: Loki StatefulSet Update Failed - Persistence Configuration**

**Symptoms:**
- `Error: UPGRADE FAILED: cannot patch "loki-stack" with kind StatefulSet`
- `StatefulSet.apps "loki-stack" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'ordinals', 'template', 'updateStrategy', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden`
- Cannot enable persistence on existing Loki deployment

**Root Cause:**
- StatefulSets don't allow changes to volumeClaimTemplates after creation
- Enabling persistence requires recreating the StatefulSet
- Kubernetes protects against data loss by preventing these changes

**Solutions:**

**Option A: Safe Recreation (Recommended)**
```bash
# 1. Backup current Loki data (if any)
kubectl get pvc -n loki-stack

# 2. Delete the existing Loki stack
helm uninstall loki-stack -n loki-stack

# 3. Wait for cleanup
sleep 30

# 4. Reinstall with persistence enabled
helm install loki-stack grafana/loki-stack \
  --namespace loki-stack \
  --create-namespace \
  --values loki-stack-values.yaml \
  --wait \
  --timeout=10m
```

**Option B: Force Recreation**
```bash
# Delete StatefulSet and PVCs
kubectl delete statefulset loki-stack -n loki-stack
kubectl delete pvc --all -n loki-stack

# Reinstall
helm install loki-stack grafana/loki-stack \
  --namespace loki-stack \
  --create-namespace \
  --values loki-stack-values.yaml
```

**Prevention:**
- Always plan persistence from initial deployment
- Test configuration changes in staging first
- Use `--dry-run` to validate changes before applying

**Expected Resolution Time:** 5-10 minutes

### **Issue: Promtail Cannot Connect to Loki - Service Name Resolution**

**Symptoms:**
- `error sending batch, will retry" status=-1 tenant= error="Post \"http://loki:3100/loki/api/v1/push\": dial tcp: lookup loki on 10.0.0.10:53: no such host"`
- Promtail logs show DNS lookup failures for `loki:3100`
- Logs not appearing in Grafana/Loki despite Promtail running

**Root Cause:**
- Incorrect service name in Promtail client configuration
- Should be `loki-stack:3100` not `loki:3100` when using Helm chart

**Solution:**
```bash
# Fix the service URL in values file
# Change: url: http://loki:3100/loki/api/v1/push
# To:     url: http://loki-stack:3100/loki/api/v1/push

# Update the deployment
helm upgrade loki-stack grafana/loki-stack \
  --namespace loki-stack \
  --values loki-stack-values.yaml \
  --wait \
  --timeout=5m

# Verify fix
kubectl logs -n loki-stack loki-stack-promtail-xxxxx --tail=10
```

**Prevention:**
- Always verify service names match the actual Kubernetes services
- Test connectivity before deploying: `kubectl get svc -n loki-stack`

**Expected Resolution Time:** 2-3 minutes

### **Resolution Status: September 6, 2025 - COMPLETED ✅**
- ✅ **Loki Persistence**: Successfully enabled with 50Gi storage
- ✅ **StatefulSet Recreation**: Completed without data loss
- ✅ **Promtail Connection**: Fixed service name resolution (`loki-stack:3100`)
- ✅ **Log Collection**: Promtail now successfully collecting from Rocket.Chat pods
- ✅ **Loki Processing**: Server receiving and processing log data
- ✅ **Grafana Integration**: Datasource configured and ready for log queries

**Final Verification (September 6, 22:05 UTC):**
```bash
# All pods running correctly:
NAME                        READY   STATUS    RESTARTS   AGE
loki-stack-0                1/1     Running   0          6m36s
loki-stack-promtail-kqlhk   1/1     Running   0          29s
loki-stack-promtail-z72t6   1/1     Running   0          71s
```

### **Issue: Grafana Dashboards Show No Data Except Loki Logs (September 19, 2025)**

**Symptoms:**
- Grafana dashboards display empty/no data for all panels
- Only Loki logs are visible and working
- Prometheus appears healthy but targets show no Rocket.Chat metrics
- Error logs show: `Failed to determine correct type of scrape target` with `content_type="text/html"`
- Kubernetes metrics (node, pod status) may work, but Rocket.Chat-specific metrics are missing

**Root Cause:**
- Rocket.Chat does not have built-in Prometheus metrics enabled/working
- PodMonitor/ServiceMonitor configured to scrape non-existent metrics endpoints
- Rocket.Chat deployment configured with `prometheusScraping.enabled: true` but metrics not actually exposed
- ServiceMonitor attempting to scrape Rocket.Chat web interface (port 3000) instead of metrics endpoint

**Diagnosis:**
```bash
# Check if Rocket.Chat exposes metrics on expected ports
kubectl exec -n rocketchat rocketchat-rocketchat-<pod-id> -- nc -z localhost 9458 && echo "Port 9458 open" || echo "Port 9458 closed"
kubectl exec -n rocketchat rocketchat-rocketchat-<pod-id> -- nc -z localhost 9459 && echo "Port 9459 open" || echo "Port 9459 closed"

# Check Prometheus targets
kubectl exec -n monitoring monitoring-grafana-<pod-id> -- curl -s http://monitoring-kube-prometheus-prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | select(.scrapePool | contains("rocketchat")) | {scrapeUrl, health}'

# Check for scraping errors
kubectl logs -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus --tail=20 | grep -i "rocketchat\|error"
```

**Solutions Applied:**

**Solution 1: Remove Problematic ServiceMonitor**
```bash
# Delete ServiceMonitor causing HTML scraping errors
kubectl delete servicemonitors.monitoring.coreos.com rocketchat-servicemonitor -n monitoring
```

**Solution 2: Update PodMonitor Configuration**
```bash
# Updated PodMonitor to only target available metrics (MongoDB if present)
kubectl apply -f aks/monitoring/rocket-chat-podmonitor.yaml
```

**Solution 3: Apply Official Rocket.Chat Monitoring Configuration**
```bash
# Updated monitoring values with official recommendations
# Added: serviceMonitorSelectorNilUsesHelmValues: false
# Added: podMonitorSelectorNilUsesHelmValues: false
# Added: Official Grafana dashboards (IDs: 23428, 23427)
helm upgrade monitoring prometheus-community/kube-prometheus-stack -f aks/config/helm-values/monitoring-values.yaml
```

**Current Status:**
- ✅ ServiceMonitor errors eliminated
- ✅ Prometheus configuration updated with official recommendations
- ✅ Official Rocket.Chat Grafana dashboards added
- ✅ Kubernetes metrics working (node, pod status from kube-state-metrics)
- ❌ Rocket.Chat application metrics not available (Rocket.Chat doesn't expose Prometheus metrics)
- ❌ Application-specific dashboards show no data due to missing metrics

**Prevention:**
- Verify Rocket.Chat version supports Prometheus metrics before configuring
- Check if metrics are actually exposed: `OVERWRITE_SETTING_Prometheus_Enabled=true` and `OVERWRITE_SETTING_Prometheus_Port=9458`
- Use official Rocket.Chat Helm chart monitoring configuration
- Consider alternative monitoring approaches if built-in metrics unavailable

**Expected Behavior:**
- Kubernetes infrastructure metrics will work (CPU, memory, pod status)
- Rocket.Chat-specific dashboards will remain empty due to lack of application metrics
- Loki logging will continue to work normally
- MongoDB metrics may be available if properly configured

**Alternative Solutions if Rocket.Chat Metrics Needed:**
1. Use Rocket.Chat API monitoring instead of Prometheus
2. Implement custom exporters for Rocket.Chat metrics
3. Monitor at infrastructure level (Kubernetes metrics only)
4. Consider upgrading to Rocket.Chat Enterprise with enhanced monitoring

**Resolution Status: September 19, 2025 - PARTIALLY RESOLVED ⚠️**
- Issue identified as expected behavior (Rocket.Chat Community Edition has limited Prometheus metrics)
- Rocket.Chat DOES expose metrics on ports 9458 (main) and 9459 (microservices)
- ServiceMonitor/PodMonitor creation issues discovered (monitors disappear after creation)
- Documentation updated with comprehensive findings
- Further investigation needed for monitor persistence issue

### **Update: PodMonitor vs ServiceMonitor Investigation (September 19, 2025)**

**Key Finding:** Both ServiceMonitors and PodMonitors disappear immediately after creation despite proper configuration.

**Technical Analysis:**
1. **Rocket.Chat Metrics ARE Available:**
   - Port 9458: Main application metrics (`rocketchat_info`, `rocketchat_metrics_requests`, etc.)
   - Port 9459: Microservices metrics (process memory, heap size, etc.)
   - Both endpoints return valid Prometheus metrics format

2. **PodMonitor vs ServiceMonitor Comparison:**
   - **PodMonitor Advantages:**
     - Direct pod discovery without Service dependency
     - Better for microservices architecture
     - More flexible port targeting
     - Recommended by Rocket.Chat official monitoring chart
   
   - **ServiceMonitor Advantages:**
     - Service-level abstraction
     - More stable for traditional services
     - Requires proper port naming in Service definitions

3. **Configuration Issue Discovered:**
   - Prometheus configured with selector: `matchLabels: {release: monitoring}`
   - Both PodMonitors and ServiceMonitors require this label
   - Monitors are created but disappear immediately (likely garbage collected)
   - No validation webhook errors found

**Attempted Solutions:**
1. Created ServiceMonitors with proper labels and port names
2. Created PodMonitors targeting container ports directly
3. Both approaches result in monitors disappearing after creation

**Current Workaround:**
- Metrics endpoints are accessible but not scraped by Prometheus
- Manual port-forward allows direct metric queries
- Infrastructure metrics (node, kubelet) continue working normally

**Next Steps Required:**
1. Investigate why CRD resources (ServiceMonitor/PodMonitor) are being deleted
2. Check if there's a controller or operator removing non-conforming monitors
3. Consider using Prometheus scrape configs directly instead of monitors
4. Review kube-prometheus-stack operator logs for cleanup activities

**Verification Commands:**
```bash
# Test Rocket.Chat metrics endpoints directly
POD=$(kubectl get pods -n rocketchat -l app.kubernetes.io/name=rocketchat -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n rocketchat $POD -- wget -O- http://localhost:9458/metrics | head -20
kubectl exec -n rocketchat $POD -- wget -O- http://localhost:9459/metrics | head -20

# Check for monitor resources
kubectl get servicemonitors,podmonitors --all-namespaces

# Watch for deletion events
kubectl get events --all-namespaces -w | grep -i monitor

# Check if metrics are accessible via service
kubectl run test-metrics --image=busybox --rm -it --restart=Never -- \
  wget -O- http://rocketchat-rocketchat.rocketchat.svc.cluster.local:9458/metrics
```

## �🚀 **Deployment Issues**

### **Issue 1.1: Helm Deployment Fails**

**Symptoms:**
- `helm install` command fails
- Error messages about resource conflicts
- Chart installation timeout

**Diagnosis:**
```bash
# Check Helm status
helm list --all-namespaces

# Check cluster resources
kubectl get all --all-namespaces

# Check Helm release status
helm status rocketchat -n rocketchat
```

**Solutions:**

**Option A: Clean Previous Installation**
```bash
# Delete previous release
helm uninstall rocketchat -n rocketchat

# Clean up resources
kubectl delete namespace rocketchat --ignore-not-found=true

# Wait for cleanup
sleep 60

# Retry deployment
./deploy-aks-official.sh
```

**Option B: Force Reinstall**
```bash
# Force reinstall
helm install rocketchat rocketchat/rocketchat \
  --namespace rocketchat \
  --create-namespace \
  --values values-official.yaml \
  --wait \
  --timeout=15m \
  --debug
```

**Prevention:**
- Always clean up previous deployments before reinstalling
- Use `--wait` and `--timeout` flags for better error handling
- Check cluster resources before deployment

---

## ☸️ **AKS Cluster Issues**

### **Issue 2.1: kubectl Connection Fails**

**Symptoms:**
- `kubectl get nodes` returns connection errors
- Authentication failures
- Context not found errors

**Diagnosis:**
```bash
# Check kubeconfig
kubectl config current-context

# Test cluster connection
kubectl cluster-info

# Check Azure authentication
az account show
```

**Solutions:**

**Option A: Refresh kubeconfig**
```bash
# Get new kubeconfig from Azure
az aks get-credentials --resource-group <resource-group> --name <cluster-name> --overwrite-existing

# Set correct context
kubectl config use-context <aks-context-name>
```

**Option B: Check Network Connectivity**
```bash
# Test API server connectivity
curl -k https://<aks-api-server>:443/api/v1/

# Check firewall rules
az network nsg rule list --resource-group <rg> --nsg-name <nsg>
```

**Prevention:**
- Regularly refresh kubeconfig (expires every 24-48 hours)
- Store kubeconfig securely, never in version control
- Use Azure CLI authentication instead of static credentials

### **Issue 2.2: Insufficient Cluster Resources**

**Symptoms:**
- Pods stuck in `Pending` state
- `Insufficient cpu/memory` errors
- Node scaling failures

**Diagnosis:**
```bash
# Check node status
kubectl get nodes
kubectl describe nodes

# Check pod events
kubectl get events -n rocketchat
kubectl describe pod <pod-name> -n rocketchat

# Check resource quotas
kubectl get resourcequotas -n rocketchat
```

**Solutions:**

**Option A: Scale Cluster**
```bash
# Scale node pool
az aks scale --resource-group <rg> --name <cluster> --node-count 3

# Or use cluster autoscaler
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

**Option B: Reduce Resource Requests**
```yaml
# In values-official.yaml, reduce requests:
resources:
  requests:
    cpu: 200m      # Reduced from 500m
    memory: 512Mi  # Reduced from 1Gi
  limits:
    cpu: 800m      # Reduced from 1000m
    memory: 1.5Gi  # Reduced from 2Gi
```

**Prevention:**
- Monitor resource usage regularly
- Set appropriate resource requests/limits
- Use cluster autoscaling for variable workloads

---

## 🛠️ **Helm Chart Problems**

### **Issue 3.1: Chart Version Conflicts**

**Symptoms:**
- `chart version not found` errors
- Dependency resolution failures
- Template rendering errors

**Diagnosis:**
```bash
# Check available chart versions
helm search repo rocketchat/rocketchat --versions

# Check current Helm repos
helm repo list
helm repo update

# Validate chart dependencies
helm dependency list
```

**Solutions:**

**Option A: Update Chart Version**
```bash
# Specify exact version
helm install rocketchat rocketchat/rocketchat \
  --version 1.0.0 \
  --namespace rocketchat \
  --values values-official.yaml
```

**Option B: Update Dependencies**
```bash
# Update helm repositories
helm repo update

# Build dependencies
helm dependency build
```

**Prevention:**
- Keep Helm repositories updated
- Pin chart versions for production deployments
- Test chart upgrades in staging environment first

### **Issue 3.2: Template Rendering Errors**

**Symptoms:**
- YAML parsing errors
- Template syntax errors
- Value interpolation failures

**Diagnosis:**
```bash
# Debug template rendering
helm template rocketchat rocketchat/rocketchat --values values-official.yaml

# Check for syntax errors in values file
helm lint values-official.yaml

# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('values-official.yaml'))"
```

**Solutions:**

**Option A: Fix Values File**
```yaml
# Common fixes in values-official.yaml:
# Fix indentation
host: "chat.canepro.me"

# Fix boolean values
microservices:
  enabled: true  # Not "True"

# Fix resource values
resources:
  requests:
    cpu: "500m"  # Use quotes for milli-units
```

**Option B: Use Debug Mode**
```bash
# Install with debug output
helm install rocketchat rocketchat/rocketchat \
  --values values-official.yaml \
  --debug \
  --dry-run
```

**Prevention:**
- Use YAML validators
- Test values files with `helm lint`
- Use `--dry-run` for validation before actual deployment

---

### Issue 3.3: kube-prometheus-stack install/upgrade taking too long

Symptoms:
- `helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --wait` hangs for many minutes
- Install feels stuck or times out, or was cancelled and re-run

Likely causes:
- Large chart pulling multiple container images for the first time (Prometheus, Operator, Grafana, Alertmanager)
- Prometheus Operator CRDs/webhooks initializing (normal first install delay)
- Pending PVCs due to storageClass mismatch
- Slow image pulls or registry rate limiting

Quick diagnosis:
```bash
kubectl -n monitoring get pods -w | cat
kubectl -n monitoring get events --sort-by=.lastTimestamp | tail -n 80 | cat
kubectl get crds | grep monitoring.coreos | cat
kubectl get storageclass | cat
helm status monitoring -n monitoring | cat
```

Common resolutions:
1) Give it more time and set a longer timeout:
```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f aks/config/helm-values/values-monitoring.yaml \
  --timeout 20m --wait
```

2) If you cancelled (`context canceled`), simply re-run the command; Helm is idempotent.

3) PVC pending (no default storage class):
```bash
kubectl get pvc -n monitoring | cat
kubectl get storageclass | cat   # ensure a `(default)` storage class exists
# If needed, set your default or update values to an available storageClassName
```

4) Watch for webhook readiness (first install):
```bash
kubectl -n monitoring logs deploy/monitoring-kube-prometheus-operator --tail=50 | cat
```

5) Install without waiting and watch manually:
```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f aks/config/helm-values/values-monitoring.yaml
kubectl -n monitoring get pods -w | cat
```

Verification:
```bash
kubectl -n monitoring get pods
kubectl -n monitoring get svc | grep grafana
kubectl -n monitoring get prometheus
```

Prevention:
- Use a higher `--timeout` on first installs
- Ensure a valid default StorageClass exists or set `storageClassName` explicitly in values
- Avoid interrupting long first-time image pulls

Grafana Multi-Attach (RWO) during upgrade:
- Symptom: New Grafana pod in Init/Pending with event `Multi-Attach error ... volume is already used by pod ...`
- Cause: RollingUpdate tries to run two pods while PVC is ReadWriteOnce.
- Fix: Set Grafana to single replica and Recreate strategy, then re-run upgrade:
```yaml
grafana:
  replicas: 1
  deploymentStrategy:
    type: Recreate
```
Apply and restart:
```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f aks/config/helm-values/values-monitoring.yaml --timeout 20m --wait
# If still stuck once, delete the new pending pod to let Recreate happen cleanly
kubectl -n monitoring delete pod -l app.kubernetes.io/name=grafana --field-selector=status.phase=Pending
```

---

## 🌐 **Network & Ingress Issues**

### **Issue 4.1: Ingress Not Accessible**

**Symptoms:**
- 404 errors when accessing domain
- Ingress shows no backend services
- SSL certificate issues

**Diagnosis:**
```bash
# Check ingress status
kubectl get ingress -n rocketchat
kubectl describe ingress rocketchat-ingress -n rocketchat

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test service connectivity
kubectl get svc -n rocketchat
curl http://<cluster-ip>:3000
```

**Solutions:**

**Option A: Fix Ingress Configuration**
```yaml
# Check values-official.yaml ingress section:
ingress:
  enabled: true
  ingressClassName: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "production-cert-issuer"
  tls:
    - secretName: rocketchat-tls
      hosts:
        - chat.canepro.me
```

**Option B: Check Ingress Controller**
```bash
# Verify ingress controller is running
kubectl get svc -n ingress-nginx

# Check for LoadBalancer IP
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Prevention:**
- Verify ingress controller is properly installed
- Use correct ingress class name
- Test ingress configuration with temporary host

### **Issue 4.2: External IP Not Assigned**

**Symptoms:**
- LoadBalancer service stuck in `Pending`
- No external IP assigned to ingress

**Diagnosis:**
```bash
# Check service status
kubectl get svc -n ingress-nginx
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Check Azure load balancer
az network lb list --resource-group <rg>
```

**Solutions:**

**Option A: Check Azure Resource Limits**
```bash
# Check public IP quota
az network public-ip list --resource-group <rg>

# Check load balancer limits
az network lb list --resource-group <rg>
```

**Option B: Recreate Service**
```bash
# Delete and recreate ingress controller
kubectl delete svc ingress-nginx-controller -n ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

**Prevention:**
- Monitor Azure resource quotas
- Use static public IPs for production
- Plan for load balancer limits in large deployments

---

## 🔒 **SSL Certificate Problems**

### **Issue 5.1: Certificate Not Issued**

**Symptoms:**
- HTTP instead of HTTPS
- Certificate shows as `Not Ready`
- Let's Encrypt challenges failing

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificates -n rocketchat
kubectl describe certificate rocketchat-tls -n rocketchat

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check challenge status
kubectl get certificaterequests -n rocketchat
kubectl describe certificaterequest <name> -n rocketchat
```

**Solutions:**

**Option A: Fix DNS Configuration**
```bash
# Verify DNS points to correct IP
nslookup chat.canepro.me
# Should return AKS ingress IP: 4.250.169.133

# Check domain ownership
curl -I http://chat.canepro.me/.well-known/acme-challenge/test
```

**Option B: Check ClusterIssuer**
```yaml
# Verify clusterissuer.yaml is correct:
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: production-cert-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Your email
    privateKeySecretRef:
      name: cert-manager-secret-production
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Option C: Recreate Certificate**
```bash
# Delete and recreate certificate
kubectl delete certificate rocketchat-tls -n rocketchat
kubectl apply -f values-official.yaml  # Re-applies certificate
```

**Prevention:**
- Ensure DNS is properly configured before deployment
- Use staging Let's Encrypt for testing
- Monitor certificate expiry dates
- Keep contact email current

### **Issue 5.2: Incorrect Ingress Class Configuration** ⭐ **Recently Resolved**

**Symptoms:**
- Certificate stuck in "ISSUING" status for extended periods (hours)
- cert-manager logs show "propagation check failed" errors
- HTTP requests return HTML instead of ACME challenge token
- Certificate shows "True" for Issuing but "False" for Ready

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificates -n monitoring
kubectl describe certificate grafana-tls -n monitoring

# Check cert-manager logs for specific errors
kubectl logs -n cert-manager cert-manager-777f759894-ft8cs --tail=20

# Verify ingress class configuration
kubectl get ingressclass
kubectl get clusterissuers

# Check ClusterIssuer configuration
kubectl describe clusterissuer production-cert-issuer
```

**Root Cause:**
- ClusterIssuer configured with wrong ingress class (e.g., `public` instead of `nginx`)
- ACME solver ingresses created with incorrect ingress class annotation
- Certificate validation requests routed to application instead of ACME solver pod

**Solutions:**

**Option A: Fix ClusterIssuer Configuration**
```bash
# Update clusterissuer.yaml
vi clusterissuer.yaml

# Change from:
solvers:
- http01:
    ingress:
      class: public  # ❌ Wrong

# To:
solvers:
- http01:
    ingress:
      class: nginx   # ✅ Correct

# Apply changes
kubectl apply -f clusterissuer.yaml
```

**Option B: Recreate Certificate**
```bash
# Delete existing certificate
kubectl delete certificate grafana-tls -n monitoring

# Recreate certificate (will use corrected ClusterIssuer)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: grafana-tls
  namespace: monitoring
spec:
  dnsNames:
  - grafana.chat.canepro.me
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: production-cert-issuer
  secretName: grafana-tls
EOF
```

**Option C: Verify Ingress Class**
```bash
# Confirm available ingress classes
kubectl get ingressclass

# Expected output:
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       41h
```

**Prevention:**
- Always verify ingress class before configuring ClusterIssuer
- Use `kubectl get ingressclass` to confirm available classes
- Test certificate issuance in staging environment first
- Monitor certificate status after deployment
- Include ingress class validation in deployment checklists

**Expected Resolution Time:** 5-10 minutes after fix

### **Issue 5.3: Ingress Missing After Helm Upgrade**

**Symptoms:**
- 404 Not Found errors when accessing Grafana/Rocket.Chat
- `kubectl get ingress -n <namespace>` returns no resources
- Services are running but not accessible via ingress
- SSL certificates are READY but application unreachable

**Root Cause:**
- Helm upgrade removed manually created ingress without creating replacement
- Service name mismatch between ingress and actual Kubernetes service
- kube-prometheus-stack chart creates services with different naming convention
- Ingress configuration conflicts during Helm upgrade process

**Diagnosis:**
```bash
# Check ingress status
kubectl get ingress -n monitoring
kubectl get ingress -n rocketchat

# Verify services exist and are running
kubectl get services -n monitoring
kubectl get pods -n monitoring

# Check service names (common issue)
kubectl get svc -n monitoring | grep grafana  # Should be: monitoring-grafana
kubectl get svc -n rocketchat | grep rocketchat  # Should be: rocketchat-rocketchat

# Verify ingress class
kubectl get ingressclass
```

**Service Naming Reference:**
```yaml
# kube-prometheus-stack services:
monitoring-grafana                    # Grafana service
monitoring-kube-prometheus-prometheus # Prometheus service
monitoring-kube-prometheus-alertmanager # Alertmanager service

# Rocket.Chat services:
rocketchat-rocketchat                 # Main Rocket.Chat service
rocketchat-mongodb                    # MongoDB service
```

**Solutions:**

**Option A: Recreate Ingress Manually**
```bash
# Create ingress with correct service names
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.chat.canepro.me
    http:
      paths:
      - backend:
          service:
            name: monitoring-grafana  # ✅ Correct service name
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - grafana.chat.canepro.me
    secretName: grafana-tls
EOF
```

**Option B: Fix Helm Values and Redeploy**
```yaml
# Ensure values-monitoring.yaml has correct ingress config:
ingress:
  enabled: true
  ingressClassName: "nginx"
  tls: true
  grafana:
    enabled: true
    host: "grafana.chat.canepro.me"
    path: "/"

# Redeploy with corrected values
helm upgrade monitoring prometheus-community/kube-prometheus-stack -f values-monitoring.yaml
```

**Option C: Restore from Backup**
```bash
# If you have a backup, restore it
kubectl apply -f monitoring-ingress-backup.yaml

# Update service name if needed
kubectl edit ingress monitoring-ingress -n monitoring
```

**Prevention Measures:**
- **Always backup ingress before Helm upgrades:**
  ```bash
  kubectl get ingress -n monitoring -o yaml > monitoring-ingress-backup-$(date +%Y%m%d).yaml
  ```
- **Document service names** for your specific Helm charts
- **Use `--dry-run`** to preview Helm upgrade changes:
  ```bash
  helm upgrade --dry-run monitoring prometheus-community/kube-prometheus-stack -f values-monitoring.yaml
  ```
- **Verify ingress after upgrades:**
  ```bash
  kubectl get ingress -n monitoring
  kubectl describe ingress monitoring-ingress -n monitoring
  ```
- **Consider using external ingress management** separate from Helm releases

**Expected Resolution Time:** 5-10 minutes

**Post-Resolution Verification:**
```bash
# Test ingress accessibility
curl -I https://grafana.chat.canepro.me

# Check ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### **Issue 5.4: Certificate Expired**

**Symptoms:**
- Browser shows certificate expired
- HTTPS connections fail
- Mixed content warnings

**Diagnosis:**
```bash
# Check certificate expiry
kubectl get certificates -n rocketchat
kubectl describe certificate rocketchat-tls -n rocketchat

# Check renewal status
kubectl get certificaterequests -n rocketchat
```

**Solutions:**

**Option A: Force Renewal**
```bash
# Delete certificate to force renewal
kubectl delete certificate rocketchat-tls -n rocketchat
kubectl delete secret rocketchat-tls -n rocketchat

# Redeploy to recreate
helm upgrade rocketchat rocketchat/rocketchat -n rocketchat -f values-official.yaml
```

**Option B: Check Rate Limits**
```bash
# Let's Encrypt has rate limits - check if exceeded
# Wait 1 hour for rate limit reset
kubectl get certificaterequests -n rocketchat
```

**Prevention:**
- Set up certificate monitoring alerts
- Use staging environment for testing
- Plan certificate renewals before expiry
- Keep backup certificates ready

---

## 🗄️ **Database Connection Issues**

### **Issue 6.1: MongoDB Connection Failed**

**Symptoms:**
- Rocket.Chat pods crash with MongoDB errors
- `MongoNetworkError` or `MongoTimeoutError`
- Application logs show connection failures

**Diagnosis:**
```bash
# Check MongoDB pods
kubectl get pods -n rocketchat | grep mongodb
kubectl logs -n rocketchat <mongodb-pod-name>

# Test MongoDB connectivity
kubectl exec -n rocketchat <mongodb-pod> -- mongo --eval "db.stats()"

# Check MongoDB service
kubectl get svc -n rocketchat | grep mongodb
```

**Solutions:**

**Option A: Check MongoDB Configuration**
```yaml
# Verify values-official.yaml MongoDB section:
mongodb:
  enabled: true
  auth:
    passwords:
      - "rocketchat"  # Must match app config
    rootPassword: "rocketchatroot"
  architecture: "replicaset"
  replicaCount: 3
```

**Option B: Test Internal Connectivity**
```bash
# Test from Rocket.Chat pod
kubectl exec -n rocketchat deployment/rocketchat -- mongo --host mongodb-0.mongodb-headless --eval "db.stats()"

# Check MongoDB replica set status
kubectl exec -n rocketchat <mongodb-pod> -- mongo --eval "rs.status()"
```

**Option C: Restore from Backup**
```bash
# If database is corrupted, restore from backup
kubectl exec -n rocketchat <mongodb-pod> -- mongorestore /path/to/backup/dump
```

**Prevention:**
- Use MongoDB replica sets for high availability
- Monitor MongoDB connection pools
- Implement proper resource limits
- Regular backup testing

### **Issue 6.2: MongoDB Replica Set Issues**

**Symptoms:**
- Replica set not initialized
- Primary election failures
- Replication lag

**Diagnosis:**
```bash
# Check replica set status
kubectl exec -n rocketchat mongodb-0 -- mongo --eval "rs.status()"

# Check MongoDB logs
kubectl logs -n rocketchat mongodb-0

# Verify PVCs are bound
kubectl get pvc -n rocketchat
```

**Solutions:**

**Option A: Initialize Replica Set**
```bash
# Connect to MongoDB and initialize
kubectl exec -n rocketchat mongodb-0 -- mongo --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    {_id: 0, host: 'mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017'},
    {_id: 1, host: 'mongodb-1.mongodb-headless.rocketchat.svc.cluster.local:27017'},
    {_id: 2, host: 'mongodb-2.mongodb-headless.rocketchat.svc.cluster.local:27017'}
  ]
})
"
```

**Option B: Fix PVC Issues**
```bash
# Check PVC status
kubectl get pvc -n rocketchat
kubectl describe pvc <pvc-name> -n rocketchat

# If PVC stuck, delete and recreate
kubectl delete pvc <pvc-name> -n rocketchat
kubectl apply -f values-official.yaml
```

**Prevention:**
- Ensure sufficient storage capacity
- Monitor replica set health
- Use persistent storage for MongoDB
- Plan for replica set maintenance

---

## 🚀 **Application Startup Problems**

### **Issue 7.1: Rocket.Chat Pod Crashes**

**Symptoms:**
- Pods in `CrashLoopBackOff` state
- Container restart loops
- Application startup failures

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n rocketchat
kubectl describe pod <rocketchat-pod> -n rocketchat

# View application logs
kubectl logs -n rocketchat <rocketchat-pod> --previous
kubectl logs -f -n rocketchat <rocketchat-pod>

# Check resource usage
kubectl top pods -n rocketchat
```

**Solutions:**

**Option A: Check Resource Limits**
```yaml
# Adjust resources in values-official.yaml:
resources:
  requests:
    cpu: 300m      # Increase if needed
    memory: 768Mi  # Increase if needed
  limits:
    cpu: 1000m
    memory: 2Gi
```

**Option B: Fix Environment Variables**
```yaml
# Verify environment configuration:
extraEnv:
  - name: NODE_ENV
    value: "production"
  - name: ROOT_URL
    value: "https://chat.canepro.me"
  - name: MONGO_URL
    value: "mongodb://..."
```

**Option C: Check Dependencies**
```bash
# Verify MongoDB is ready
kubectl get pods -n rocketchat | grep mongodb

# Check network connectivity
kubectl exec -n rocketchat <rocketchat-pod> -- ping mongodb-0.mongodb-headless
```

**Prevention:**
- Set appropriate resource limits
- Use liveness/readiness probes
- Monitor application logs regularly
- Implement proper health checks

### **Issue 7.2: Microservice MongoDB Connection Issues - UPDATED (September 19, 2025)**

**Symptoms:**
- Rocket.Chat microservices (account, authorization, ddp-streamer) in `CrashLoopBackOff`
- Main Rocket.Chat pods running normally
- Microservice logs show `AuthenticationFailed` or `ENOTFOUND` errors
- MongoDB connection issues specific to microservices

**Diagnosis:**
```bash
# Check microservice pod status
kubectl get pods -n rocketchat | grep -E "(account|authorization|ddp-streamer)"

# Check microservice logs for MongoDB errors
kubectl logs -n rocketchat <microservice-pod> --tail=20

# Verify MongoDB service names
kubectl get svc -n rocketchat | grep mongo

# Check secret contents used by microservices
kubectl get secret rocketchat-rocketchat -n rocketchat -o jsonpath='{.data.mongo-uri}' | base64 -d
```

**Root Causes:**
1. **Incorrect Service Names**: Microservices using wrong MongoDB service names (e.g., `rocketchat-mongodb-headless` instead of `mongodb-headless.rocketchat.svc.cluster.local`)
2. **Authentication Mismatch**: Microservices trying to authenticate when MongoDB runs without authentication
3. **Secret Configuration**: Helm-generated secrets containing incorrect connection strings

**Solutions Applied:**

**Option A: Fix MongoDB Service Names in Secrets**
```bash
# Update secret with correct service names (base64 encoded)
kubectl patch secret rocketchat-rocketchat -n rocketchat --type='json' -p='[
  {"op": "replace", "path": "/data/mongo-uri", "value": "bW9uZ29kYjovL21vbmdvZGItaGVhZGxlc3Mucm9ja2V0Y2hhdC5zdmMuY2x1c3Rlci5sb2NhbDoyNzAxNy9yb2NrZXRjaGF0"},
  {"op": "replace", "path": "/data/mongo-oplog-uri", "value": "bW9uZ29kYjovL21vbmdvZGItaGVhZGxlc3Mucm9ja2V0Y2hhdC5zdmMuY2x1c3Rlci5sb2NhbDoyNzAxNy9sb2NhbA=="}
]'

# Restart microservice pods
kubectl delete pod <failing-microservice-pods> -n rocketchat
```

**Option B: Align Authentication Configuration**
```yaml
# Ensure microservices and main app use same MongoDB config:
# Main Rocket.Chat: mongodb://mongodb-headless.rocketchat.svc.cluster.local:27017/rocketchat
# Microservices: Same connection string (from secret)
```

**Prevention:**
- Verify MongoDB service names match between deployments and secrets
- Ensure consistent authentication configuration across all components
- Test microservice connectivity after configuration changes
- Monitor all pod statuses after deployments

**Resolution Applied (September 19, 2025):**
1. **Service Name Correction**: Updated secrets to use correct FQDN `mongodb-headless.rocketchat.svc.cluster.local`
2. **Authentication Alignment**: Removed authentication from microservice connections to match main app
3. **Pod Restart**: Triggered microservice pod restarts to pick up corrected configuration
4. **Verification**: Confirmed all microservices running successfully

---

### **Issue 7.3: Application Performance Issues**

**Symptoms:**
- Slow response times
- High memory usage
- CPU throttling

**Diagnosis:**
```bash
# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes

# Check application metrics
kubectl exec -n rocketchat <rocketchat-pod> -- curl http://localhost:3000/metrics

# Review pod events
kubectl get events -n rocketchat --sort-by=.metadata.creationTimestamp
```

**Solutions:**

**Option A: Optimize Resources**
```yaml
# Adjust resource allocation:
replicaCount: 2  # Increase replicas for load distribution

resources:
  requests:
    cpu: 400m
    memory: 1Gi
  limits:
    cpu: 800m
    memory: 1.5Gi
```

**Option B: Enable Microservices**
```yaml
# Scale microservices in values-official.yaml:
microservices:
  enabled: true
  ddpStreamer:
    replicas: 3  # Scale based on concurrent users
```

**Prevention:**
- Implement horizontal pod autoscaling
- Use performance monitoring tools
- Optimize database queries
- Implement caching strategies

---

## 📊 **Monitoring Stack Issues**

### **Issue 8.1: Grafana Not Accessible**

**Symptoms:**
- Grafana returns 404 or connection errors
- Port-forward doesn't work
- Dashboard not loading

**Diagnosis:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana
kubectl logs -n monitoring <grafana-pod>

# Test service connectivity
kubectl get svc -n monitoring
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

**Solutions:**

**Option A: Check Grafana Configuration**
```yaml
# Verify values-monitoring.yaml:
grafana:
  adminPassword: "GrafanaAdmin2024!"
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    hosts:
      - grafana.chat.canepro.me
```

**Option B: Fix Service Issues**
```bash
# Check service endpoints
kubectl get endpoints -n monitoring prometheus-grafana

# Recreate Grafana deployment
kubectl delete pod <grafana-pod> -n monitoring
```

**Prevention:**
- Verify ingress configuration
- Use correct service types
- Monitor Grafana logs regularly
- Test port-forwarding before DNS changes

---

### **Issue 8.2: Grafana Dashboards Showing "No Data" Despite Healthy Targets**

**Symptoms:**
- Prometheus targets show UP status (ports 9458, 9459, 9216)
- Grafana dashboards display "No data" for all panels
- Loki logs are working correctly
- Official Rocket.Chat dashboards (IDs 23428, 23427) show no metrics

**Root Cause:**
- **Metric label mismatch** between dashboard queries and actual PodMonitor labels
- Dashboard queries expect different label names than what PodMonitors provide
- Conflict between PodMonitor and ServiceMonitor label structures

**Diagnosis:**
```bash
# 1. Verify Prometheus targets are UP
kubectl proxy --port=8001 &
# Visit: http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/targets
# Look for: rocketchat-metrics, rocketchat-microservices, mongodb-metrics

# 2. Check available metrics
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/label/__name__/values" | jq '.data[] | select(test("rocketchat|mongodb"))'

# 3. Inspect metric labels
curl -s "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=up{namespace=\"rocketchat\"}" | jq '.data.result[].metric'

# 4. Check PodMonitor vs ServiceMonitor conflicts
kubectl get podmonitor -n monitoring
kubectl get servicemonitor -n monitoring | grep rocketchat
```

**Solutions:**

**Option A: Use Helm-Managed PodMonitors (Recommended)**
```bash
# 1. Deprecate manual PodMonitor manifest
# Add header to aks/monitoring/rocketchat-podmonitor.yaml:
###############################################
# DEPRECATION NOTICE
# This manifest is retained for reference only.
# Do NOT apply manually. PodMonitors are now
# rendered and managed by the monitoring Helm
# release via prometheus.additionalPodMonitors
###############################################

# 2. Configure PodMonitors via Helm values
# In aks/config/helm-values/monitoring-values.yaml:
prometheus:
  additionalPodMonitors:
    - name: rocketchat-metrics
      namespace: monitoring
      labels:
        release: monitoring  # Critical for Prometheus discovery
      selector:
        matchLabels:
          app.kubernetes.io/instance: rocketchat
          app.kubernetes.io/name: rocketchat
      podMetricsEndpoints:
        - portNumber: 9458
          path: /metrics
          relabelings:
            - sourceLabels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
              targetLabel: service_name
              replacement: rocketchat

# 3. Upgrade monitoring stack
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f aks/config/helm-values/monitoring-values.yaml \
  --create-namespace --wait --timeout 10m0s
```

**Option B: Fix Dashboard Label Queries**
```bash
# 1. Export current dashboard JSON
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
# Visit Grafana → Dashboard → Settings → JSON Model

# 2. Update dashboard queries to match your labels:
# Change from: {job="rocketchat-metrics"}
# Change to: {job="rocketchat-metrics",namespace="rocketchat"}

# 3. Common label mappings needed:
# service_name → job
# instance → pod  
# namespace → namespace (should match)
```

**Option C: Create Custom Dashboard**
```json
{
  "dashboard": {
    "title": "Rocket.Chat Custom Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"rocketchat\"}[5m])",
            "legendFormat": "{{service_name}} - {{method}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace=\"rocketchat\"}[5m]))",
            "legendFormat": "95th percentile - {{service_name}}"
          }
        ]
      }
    ]
  }
}
```

**Verification Steps:**
```bash
# 1. Confirm PodMonitors exist and are Helm-managed
kubectl get podmonitor -n monitoring
kubectl get podmonitor rocketchat-metrics -n monitoring -o yaml | grep -A5 "labels:"

# 2. Verify Prometheus targets show correct labels
# Visit: http://127.0.0.1:8001/.../proxy/targets
# Look for: job="rocketchat-metrics", namespace="rocketchat"

# 3. Test metric queries in Grafana Explore
# Query: up{namespace="rocketchat"}
# Should return: 1 for each healthy target

# 4. Import working dashboard
# Use Dashboard ID: 23428 (Rocket.Chat Metrics)
# Modify variable queries to match your label structure
```

**Prevention:**
- Always use Helm-managed monitoring resources to avoid label conflicts
- Test dashboard queries in Grafana Explore before importing
- Document custom label mappings for future dashboard imports
- Use consistent labeling strategy across all monitoring components
- Regularly verify Prometheus target labels match dashboard expectations

**RESOLUTION CONFIRMED (September 19, 2025):**
✅ **ServiceMonitor Discovery Issue FULLY RESOLVED** - Complete monitoring stack now operational:

**Phase 1: ServiceMonitor Discovery Fixed**
- After Prometheus restart + 3-5 minute wait, ServiceMonitor targets successfully discovered
- `up{job=~".*rocketchat.*"}` returns 1238 series
- `rocketchat_info`, `rocketchat_users_total`, `rocketchat_version` all working
- Multiple job names discovered: `rocketchat-rocketchat-monolith-ms-metrics`, `rocketchat-rocketchat`

**Phase 2: Dashboard Queries Fixed**
- ✅ **Rocket.Chat Service Status**: `avg(up{job=~".*rocketchat.*"})` → Shows 0.889 (UP)
- ✅ **Active Pods**: `count(up{job=~".*rocketchat.*"} == 1)` → Shows 16 active pods
- ✅ **CPU Usage**: `rate(process_cpu_seconds_total{job=~".*rocketchat.*"}[5m])` → Real-time CPU metrics
- ✅ **Memory Usage**: `process_resident_memory_bytes{job=~".*rocketchat.*"}` → Memory tracking
- ✅ **HTTP Requests**: `rate(rocketchat_rest_api_count[5m])` → API request rates
- ✅ **Log Ingest**: `rate({namespace="rocketchat"}[5m])` → Loki log rates
- ✅ **Alerts Table**: `ALERTS{namespace="rocketchat"}` → Alert monitoring

**Phase 3: MongoDB Metrics Investigation**
- ✅ **ServiceMonitor Fixed**: Updated selector to match service labels
- ❌ **MongoDB Metrics Endpoint**: Connection refused on port 9216 - no MongoDB exporter running
- 📋 **Next Session**: Deploy MongoDB exporter for detailed database metrics (optional enhancement)

**Complete Solution Files Created:**
- `aks/monitoring/rocketchat-servicemonitors.yaml` - Working ServiceMonitors
- `aks/monitoring/rocketchat-dashboard-fixed.json` - Fixed dashboard with all working queries
- `docs/MONITORING_SETUP_GUIDE.md` - Complete setup documentation

**MongoDB ServiceMonitor Status:**
```bash
# ✅ FIXED: ServiceMonitor selector updated to match service labels
# ❌ PENDING: MongoDB metrics endpoint not responding (no exporter running)
# 📋 NEXT SESSION: Deploy MongoDB exporter for detailed database metrics

# For next session - MongoDB exporter deployment:
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install mongodb-exporter prometheus-community/prometheus-mongodb-exporter \
  -n rocketchat \
  --set mongodb.uri="mongodb://mongodb.rocketchat.svc.cluster.local:27017" \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=monitoring
```

---

### **Issue 8.4: Dashboard Shows "No Data" Despite Working Metrics**

**Symptoms:**
- Grafana Explore shows metrics working (e.g., `rocketchat_info` returns data)
- Dashboard panels display "No data"
- ServiceMonitors discovered and Prometheus targets UP
- Metrics queries work in Explore but not in dashboards

**Root Cause:**
- Dashboard queries use incorrect job names or metric names

### **Issue 8.5: MongoDB Status Panel Shows "No Data" (RESOLVED - January 2025)**

**Symptoms:**
- MongoDB Status panel in Rocket.Chat Production Monitoring dashboard displays "No data"
- Other dashboard panels work correctly
- MongoDB pods are running and healthy
- Prometheus targets show UP status for other services

**Root Cause:**
- Dashboard query `up{job=~".*mongodb.*"}` was looking for Prometheus jobs with "mongodb" in the name
- MongoDB deployment uses standalone StatefulSet without ServiceMonitor configuration
- No Prometheus job was created for MongoDB monitoring

**Solution Applied:**
```bash
# 1. Updated dashboard query to use Kubernetes pod status instead of Prometheus job status
# Changed from: up{job=~".*mongodb.*"}
# Changed to: count(kube_pod_status_phase{namespace="rocketchat", pod=~"mongodb-[0-9]+.*", phase="Running"})

# 2. Removed "(Fixed)" from dashboard title
# Changed from: "Rocket.Chat Production Monitoring (Fixed)"
# Changed to: "Rocket.Chat Production Monitoring"

# 3. Fixed MongoDB query to exclude init jobs and show count instead of individual pods
# Final query: count(kube_pod_status_phase{namespace="rocketchat", pod=~"mongodb-[0-9]+.*", phase="Running"})

# 4. Updated Active Pods panel to count all running pods in namespace
# Changed to: count(kube_pod_status_phase{namespace="rocketchat", phase="Running"})

# 5. Created MongoDB ServiceMonitor (optional for future metrics)
kubectl apply -f aks/monitoring/mongodb-servicemonitor.yaml
```

**Files Updated:**
- `aks/monitoring/rocketchat-dashboard-fixed.json` - Fixed query and title
- `aks/monitoring/rocket-chat-dashboard-configmap.yaml` - Updated ConfigMap version
- `aks/monitoring/mongodb-servicemonitor.yaml` - Created ServiceMonitor for future use

**Verification:**
```bash
# Check MongoDB pods are running
kubectl get pods -n rocketchat | grep mongodb

# Verify MongoDB count query works in Grafana Explore
count(kube_pod_status_phase{namespace="rocketchat", pod=~"mongodb-[0-9]+.*", phase="Running"})

# Verify total pod count matches kubectl output
count(kube_pod_status_phase{namespace="rocketchat", phase="Running"})

# Expected results:
# - MongoDB Status panel: Shows "3" (count of MongoDB pods)
# - Active Pods panel: Shows "13" (total running pods in namespace)
```

**Prevention:**
- Use Kubernetes-native metrics for standalone deployments without ServiceMonitors
- Verify dashboard queries match actual Prometheus job names or use kube-state-metrics
- Test dashboard queries in Grafana Explore before deploying

### **Issue 8.6: Dashboard Panel Layout and Query Optimization (RESOLVED - January 2025)**

**Symptoms:**
- MongoDB Status panel showing multiple individual panels instead of single count
- Active Pods panel showing incorrect count (excluding NATS pods)
- Some panels displaying "No data" errors
- Dashboard layout appearing cluttered and unprofessional
- Service Status panel showing individual UP/DOWN indicators instead of uptime percentage
- HTTP Requests and Loki panels showing "No data"
- Empty space in dashboard layout
- Mixed data source UIDs causing inconsistent data loading
- Poor grid positioning creating wasted space

**Root Cause:**
- MongoDB query was returning individual pod status instead of aggregated count
- Active Pods query was excluding NATS infrastructure pods
- Some queries were looking for non-existent Rocket.Chat application metrics
- Panel titles didn't reflect actual data being displayed
- Data source UID mismatch (using wrong Prometheus UID)
- Service Status panel lacked proper uptime SLO formatting
- Inconsistent data source UIDs across panels
- Suboptimal grid layout with empty spaces

**Solution Applied:**
```bash
# 1. Fixed MongoDB Status panel to show count instead of individual pods
# Changed from: kube_pod_status_phase{namespace="rocketchat", pod=~"mongodb-.*", phase="Running"}
# Changed to: count(kube_pod_status_phase{namespace="rocketchat", pod=~"mongodb-[0-9]+.*", phase="Running"})

# 2. Updated Active Pods panel to count ALL running pods in namespace
# Changed to: count(kube_pod_status_phase{namespace="rocketchat", phase="Running"})

# 3. Updated panel titles to reflect actual data
# "Active Rocket.Chat Pods" → "Active Pods (All Services)"
# "Rocket.Chat Users: Total vs Active" → "Rocket.Chat Pods: Status vs Count"

# 4. Fixed HTTP Requests panel query
# Changed from: rate(rocketchat_rest_api_count{job=~".*rocketchat.*"}[5m])
# Changed to: rate(http_requests_total{namespace="rocketchat"}[5m])

# 5. Fixed Log Ingest Rate panel query
# Changed from: rate({namespace="rocketchat"}[5m])
# Changed to: sum(rate({namespace="rocketchat"}[5m]))

# 6. Fixed Data Source UID mismatch
# Changed from: "uid": "eeylh52phogsga"
# Changed to: "uid": "prometheus"

# 7. Improved Service Status panel to Uptime SLO
# Changed from: up{job=~".*rocketchat.*"}
# Changed to: avg(up{job=~".*rocketchat.*"}) * 100
# Added percentage formatting and SLO thresholds (95% yellow, 99% green)

# 8. Fixed HTTP Requests panel query
# Changed from: rate(http_requests_total{namespace="rocketchat"}[5m])
# Changed to: sum(rate(http_requests_total{namespace="rocketchat"}[5m]))

# 9. Added Response Time panel to fill empty space
# New panel: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="rocketchat"}[5m]))

# 10. Created optimized dashboard layout
# - Standardized all data source UIDs to "prometheus"
# - Optimized grid positions to eliminate empty spaces
# - Created compact 3-column layout for stat panels
# - Improved visual hierarchy and spacing

# 11. Fixed "No data" issues and improved legend formatting
# - Pod Restarts: Fixed query and legend format to show {{pod}}/{{container}}
# - Pod Status vs Count: Improved legend to show individual pod names and total count
# - HTTP Requests: Fixed query to sum by (method, status) with proper legend {{method}} ({{status}})
# - Response Time: Fixed to use summary metrics instead of non-existent bucket metrics
# - Loki Log Ingest: Fixed namespace filter syntax for proper log matching

# 12. Improved legend formatting across all panels
# - Eliminated duplicate "Pod Restarts" entries by using proper label templates
# - Added meaningful labels showing pod names, container names, HTTP methods, status codes
# - Made panels more informative and easier to read

# 13. Fixed Loki log ingestion failure
# - Corrected Promtail configuration URL from loki-stack.loki-stack to loki.monitoring
# - Created new Secret with corrected configuration
# - Updated DaemonSet to use corrected Secret
# - Restarted Promtail pods to establish proper log shipping
```

**Files Updated:**
- `aks/monitoring/rocketchat-dashboard-fixed.json` - All panel queries and titles
- `aks/monitoring/rocket-chat-dashboard-configmap.yaml` - ConfigMap version with fixes
- `rocket-chat-dashboard-v2` - New ConfigMap with corrected data source UID
- `aks/monitoring/rocketchat-dashboard-optimized.json` - Optimized layout with no empty spaces
- `rocket-chat-dashboard-optimized` - Final optimized ConfigMap
- `rocket-chat-dashboard-fixed-v2` - ConfigMap with "No data" issues resolved
- `rocket-chat-dashboard-final` - Final ConfigMap with proper legend formatting and working queries
- `loki-promtail-fixed` - Corrected Promtail configuration Secret
- `loki-promtail` - Updated DaemonSet using corrected configuration

**Verification:**
```bash
# Apply updated dashboard
kubectl apply -f aks/monitoring/rocket-chat-dashboard-configmap.yaml -n monitoring

# Restart Grafana
kubectl rollout restart deployment/monitoring-grafana -n monitoring

# Expected results:
# - MongoDB Status: Single panel showing "3"
# - Active Pods: Single panel showing "13" (matches kubectl get pods)
# - Uptime SLO: Shows percentage with color-coded thresholds
# - HTTP Requests: Shows request rate per second
# - Response Time: Shows 95th and 50th percentile response times
# - All panels showing data instead of "No data"
# - Clean, professional dashboard layout with no empty spaces
# - Compact 3-column layout for stat panels
# - All panels using consistent "prometheus" data source UID
```

**Prevention:**
- Use `count()` function for aggregated metrics instead of individual pod status
- Test queries in Grafana Explore before updating dashboards
- Ensure panel titles accurately reflect the data being displayed
- Use namespace-wide queries for comprehensive monitoring

---
        }]
      },
      {
        "title": "Active Users",
        "type": "stat", 
        "targets": [{
          "expr": "rocketchat_users_total"
        }]
      },
      {
        "title": "Version",
        "type": "stat",
        "targets": [{
          "expr": "rocketchat_version"
        }]
      }
    ]
  }
}
```

**Verification Steps:**
```bash
# 1. Test queries in Grafana Explore first
# 2. Edit one dashboard panel and update the query
# 3. Save and verify the panel shows data
# 4. Apply same pattern to other panels
```

**Common Query Patterns That Work:**
```promql
# Service health
up{job=~".*rocketchat.*"}

# User metrics  
rocketchat_users_total
rocketchat_users_online
rocketchat_users_active

# Message metrics
rocketchat_messages_total
rate(rocketchat_message_sent[5m])

# API metrics
rate(rocketchat_rest_api_sum[5m])
histogram_quantile(0.95, rate(rocketchat_rest_api_bucket[5m]))

# System metrics
rocketchat_version
rocketchat_migration
```

**Troubleshooting Tips:**
- **No metrics at all**: Check if Rocket.Chat has metrics enabled and endpoints accessible
- **Partial metrics**: Verify all microservices are running and exposing metrics on correct ports
- **Label mismatches**: Use Grafana Explore to discover actual available labels
- **Dashboard import failures**: Check Grafana logs and validate JSON syntax

---

### **Issue 8.3: ServiceMonitor Discovery Problems**

**Symptoms:**
- ServiceMonitors exist and have correct configuration
- Services have matching labels and expose metrics successfully
- Prometheus configuration allows all ServiceMonitors (`serviceMonitorSelector: {}`)
- But Prometheus doesn't discover/scrape the targets
- No Rocket.Chat targets appear in Prometheus targets page

**Root Cause:**
- ServiceMonitor to Prometheus discovery timing issues
- Potential conflicts between multiple ServiceMonitor API groups (`azmonitoring.coreos.com` vs `monitoring.coreos.com`)
- Prometheus operator not detecting ServiceMonitor changes

**Diagnosis:**
```bash
# 1. Verify metrics endpoints are working
kubectl run debug-pod --image=curlimages/curl --rm -i --tty -- /bin/sh
curl -v http://rocketchat-rocketchat-monolith-ms-metrics.rocketchat.svc.cluster.local:9458/metrics

# 2. Check ServiceMonitor configuration
kubectl get servicemonitors.monitoring.coreos.com -n monitoring | grep rocketchat
kubectl get servicemonitors.monitoring.coreos.com rocketchat-metrics -n monitoring -o yaml

# 3. Verify service labels match ServiceMonitor selectors
kubectl get svc rocketchat-rocketchat-monolith-ms-metrics -n rocketchat --show-labels

# 4. Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml | grep -A5 -B5 serviceMonitorSelector

# 5. Test Prometheus API access
kubectl port-forward -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 9091:9090
curl -s http://127.0.0.1:9091/api/v1/targets | jq '.data.activeTargets | length'
```

**Solutions:**

**Option A: Force Prometheus Reload (Recommended)**
```bash
# Restart Prometheus to force ServiceMonitor discovery
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus

# Wait for pod to restart
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -w

# Wait 2-3 minutes for target discovery, then check
kubectl port-forward -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 9091:9090 &
sleep 180
curl -s http://127.0.0.1:9091/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | test("rocketchat")) | {job: .labels.job, health: .health}'
```

**Option B: Recreate ServiceMonitors**
```bash
# Delete and recreate ServiceMonitors to trigger discovery
kubectl delete servicemonitors.monitoring.coreos.com -n monitoring rocketchat-metrics rocketchat-mongodb-metrics

# Apply fresh ServiceMonitors
kubectl apply -f aks/monitoring/rocketchat-servicemonitors.yaml

# Check discovery after 2-3 minutes
```

**Option C: Use Direct Grafana Queries**
```bash
# Since metrics endpoints work, create custom dashboard queries:
# In Grafana Explore, use these queries directly against the service:

# Query Rocket.Chat info
up{job="rocketchat-rocketchat-monolith-ms-metrics"}

# If ServiceMonitor discovery fails, manually add datasource:
# Grafana → Connections → Data sources → Add Prometheus
# URL: http://rocketchat-rocketchat-monolith-ms-metrics.rocketchat.svc.cluster.local:9458
```

**Option D: Check API Group Conflicts**
```bash
# Check if multiple ServiceMonitor CRDs cause conflicts
kubectl api-resources | grep servicemonitor

# If both azmonitoring.coreos.com and monitoring.coreos.com exist:
kubectl get servicemonitors.azmonitoring.coreos.com -A
kubectl get servicemonitors.monitoring.coreos.com -A

# Ensure Prometheus operator is using the correct CRD
kubectl get prometheus -n monitoring -o yaml | grep -i "apiVersion\|kind"
```

**Verification Steps:**
```bash
# 1. Confirm metrics endpoint responds
curl http://rocketchat-rocketchat-monolith-ms-metrics.rocketchat.svc.cluster.local:9458/metrics

# 2. Check Prometheus targets page
kubectl port-forward -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 9091:9090
# Visit: http://127.0.0.1:9091/targets

# 3. Test in Grafana Explore
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Visit: http://127.0.0.1:3000 → Explore → Query: up{job="rocketchat-metrics"}

# 4. Verify dashboard data
# Visit existing dashboards: Dashboards → Browse → rocketchat folder
```

**Prevention:**
- Always test metrics endpoints directly before creating ServiceMonitors
- Use consistent API groups (prefer `monitoring.coreos.com/v1`)
- Allow sufficient time (3-5 minutes) for Prometheus target discovery after changes
- Monitor Prometheus operator logs for ServiceMonitor processing errors
- Document working ServiceMonitor configurations for future reference

**Advanced Debugging:**
```bash
# Check Prometheus operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator

# Check Prometheus configuration reload logs
kubectl logs -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus

# Verify ServiceMonitor RBAC permissions
kubectl auth can-i get servicemonitors --as=system:serviceaccount:monitoring:monitoring-kube-prometheus-prometheus -n monitoring
```

### **Issue 8.2: Prometheus Metrics Collection Fails**

**Symptoms:**
- No metrics in Grafana
- Prometheus targets down
- Scraping errors

**Diagnosis:**
```bash
# Check Prometheus status
kubectl get pods -n monitoring | grep prometheus
kubectl logs -n monitoring <prometheus-pod>

# Check service discovery
kubectl get servicemonitors -n monitoring
kubectl get servicemonitors -n rocketchat
```

**Solutions:**

**Option A: Fix ServiceMonitor**
```yaml
# Verify monitoring configuration in values-official.yaml:
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    path: "/metrics"
    port: "http"
```

**Option B: Check Prometheus Configuration**
```bash
# Verify Prometheus can reach targets
kubectl exec -n monitoring <prometheus-pod> -- curl http://rocketchat.rocketchat.svc.cluster.local:3000/metrics
```

**Prevention:**
- Ensure ServiceMonitor annotations are correct
- Test metrics endpoints manually
- Use proper network policies
- Monitor scraping success rates

---

## 🌐 **DNS Migration Issues**

### **Issue 9.1: DNS Propagation Delays**

**Symptoms:**
- Domain still resolves to old IP
- Mixed results from different DNS servers
- Intermittent connectivity

**Diagnosis:**
```bash
# Check DNS propagation globally
nslookup chat.canepro.me 8.8.8.8      # Google DNS
nslookup chat.canepro.me 1.1.1.1      # Cloudflare DNS
nslookup chat.canepro.me 208.67.222.222  # OpenDNS

# Check DNS cache
dig chat.canepro.me @8.8.8.8
```

**Solutions:**

**Option A: Force DNS Cache Flush**
```bash
# Windows DNS flush
ipconfig /flushdns

# Linux DNS flush
sudo systemctl restart systemd-resolved
sudo resolvectl flush-caches
```

**Option B: Reduce TTL Before Migration**
```bash
# Set low TTL 24 hours before migration
# DNS Record Configuration:
# Type: A
# Name: chat
# Value: 4.250.169.133
# TTL: 300 (5 minutes during migration)
```

**Prevention:**
- Plan DNS changes during low-traffic periods
- Reduce TTL 24-48 hours before migration
- Test with multiple DNS resolvers
- Have rollback plan ready

### **Issue 9.2: DNS Migration Rollback**

**Symptoms:**
- Issues after DNS migration
- Need to rollback to MicroK8s
- Emergency rollback required

**Solutions:**

**Immediate Rollback (2 minutes):**
```bash
# Update DNS records back to MicroK8s
# chat.canepro.me → 20.68.53.249
# grafana.chat.canepro.me → 20.68.53.249

# Verify rollback
nslookup chat.canepro.me
# Should return: 20.68.53.249

curl -I https://chat.canepro.me
# Should return: HTTP/2 200
```

**Investigation Steps:**
```bash
# Check AKS deployment status
kubectl get pods -n rocketchat
kubectl logs -f deployment/rocketchat -n rocketchat

# Compare with MicroK8s
# Access MicroK8s at: https://chat.canepro.me
```

**Prevention:**
- Test AKS deployment thoroughly before DNS cutover
- Keep MicroK8s running as backup for 3-5 days
- Have DNS rollback procedure documented
- Monitor application health post-migration

---

## ⚡ **Performance Problems**

### **Issue 10.1: High Resource Usage**

**Symptoms:**
- CPU/memory usage >80%
- Pod restarts due to OOM
- Slow response times

**Diagnosis:**
```bash
# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes

# Check pod resource limits
kubectl get pods -n rocketchat -o jsonpath='{.items[*].spec.containers[*].resources}'

# Review application metrics
kubectl exec -n rocketchat <rocketchat-pod> -- curl http://localhost:3000/metrics
```

**Solutions:**

**Option A: Scale Resources**
```yaml
# Increase resource limits in values-official.yaml:
resources:
  limits:
    cpu: 1500m     # Increased from 1000m
    memory: 3Gi    # Increased from 2Gi
```

**Option B: Scale Horizontally**
```yaml
# Increase replica count:
replicaCount: 3   # Increased from 2

# Scale microservices:
microservices:
  ddpStreamer:
    replicas: 4   # Scale based on concurrent users
```

**Prevention:**
- Implement horizontal pod autoscaling
- Set up resource monitoring alerts
- Use performance profiling tools
- Plan capacity based on expected load

### **Issue 10.2: Network Latency Issues**

**Symptoms:**
- Slow page loads
- WebSocket connection issues
- High latency in user interactions

**Diagnosis:**
```bash
# Test network connectivity
kubectl run test-pod --image=busybox --rm -i --restart=Never -- wget -O- http://rocketchat.rocketchat.svc.cluster.local:3000

# Check ingress controller performance
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Monitor network policies
kubectl get networkpolicies -n rocketchat
```

**Solutions:**

**Option A: Optimize Ingress Configuration**
```yaml
# Improve ingress performance:
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

**Option B: Scale Ingress Controller**
```bash
# Scale ingress controller replicas
kubectl scale deployment ingress-nginx-controller -n ingress-nginx --replicas=2
```

**Prevention:**
- Use CDN for static assets
- Implement connection pooling
- Monitor network latency
- Use appropriate ingress annotations

---

## 💰 **Cost-Related Issues**

### **Issue 11.1: Unexpected Azure Costs - UPDATED (September 19, 2025)**

**Symptoms:**
- Higher than expected Azure bills
- Resource over-provisioning detected
- Cluster running above optimal utilization levels
- Cost monitoring alerts triggered

**Diagnosis:**
```bash
# Use the cost monitoring script
./aks/scripts/cost-monitoring.sh

# Check current resource usage vs limits
kubectl top pods -n rocketchat
kubectl top nodes

# Monitor Azure costs via portal
# https://portal.azure.com/#blade/Microsoft_Azure_Billing/ModernBillingMenuBlade/Overview

# Check for resource over-provisioning
kubectl get pods -n rocketchat -o jsonpath='{.items[*].spec.containers[*].resources}'
```

**Solutions Applied:**

**Option A: Resource Rightsizing (Implemented)**
```yaml
# Applied optimizations in values-official.yaml:
resources:
  limits:
    cpu: 500m      # Reduced from 1000m (-50%)
    memory: 1536Mi # Reduced from 2048Mi (-25%)
  requests:
    cpu: 250m      # Reduced from 500m (-50%)
    memory: 512Mi  # Reduced from 1024Mi (-50%)

# Applied MongoDB optimizations in mongodb-standalone.yaml:
resources:
  limits:
    cpu: 300m      # Reduced from 1000m (-70%)
    memory: 512Mi  # Reduced from 2048Mi (-75%)
  requests:
    cpu: 100m      # Reduced from 500m (-80%)
    memory: 256Mi  # Reduced from 1024Mi (-75%)
```

**Option B: Cost Monitoring & Alerts Setup**
```bash
# Deploy cost optimizations
./aks/scripts/apply-cost-optimizations.sh

# Set up Azure budget alerts
az consumption budget create \
  --budget-name "monthly-budget" \
  --amount 80 \
  --time-grain "Monthly" \
  --start-date "2025-09-01" \
  --notifications "cost-alerts"

# Run regular cost monitoring
./aks/scripts/cost-monitoring.sh
```

**Option C: Storage Optimization (Future)**
```bash
# Analyze storage usage
kubectl get pvc -n rocketchat -o jsonpath='{.items[*].status.capacity.storage}'

# Consider storage class optimization
kubectl get storageclass

# Monitor storage costs in Azure portal
```

**Prevention & Monitoring:**
- ✅ Automated cost monitoring script created (`cost-monitoring.sh`)
- ✅ Resource optimization script implemented (`apply-cost-optimizations.sh`)
- ✅ Comprehensive cost optimization guide documented
- ⏳ Set up Azure budget alerts for proactive monitoring
- ⏳ Regular cost reviews (weekly/monthly)
- ⏳ Performance monitoring to ensure optimizations don't impact service

**Resolution Applied (September 19, 2025):**
1. **PVC Annotation Fix**: Added missing Helm ownership annotations to `rocketchat-rocketchat` PVC
2. **Direct Resource Patching**: Applied conservative resource limits via kubectl patch
3. **Helm Upgrade Success**: Completed optimization through proper Helm upgrade
4. **MongoDB Optimization**: Reduced MongoDB resource limits by 70% CPU, 75% memory

**Results Achieved:**
- ✅ Monthly cost reduction: £5-10/month (10-20% savings)
- ✅ Target monthly spend: £60-80/month (within £100 Azure credit)
- ✅ Improved cost efficiency while maintaining full application performance
- ✅ All services running stably with optimized resource utilization

---

## 🔒 **SSL Certificate Issues - RESOLVED (September 6, 2025)**

### **Issue: Grafana SSL Certificate Authority Invalid Error**

**Symptoms:**
- Browser shows: `net::ERR_CERT_AUTHORITY_INVALID` when accessing Grafana
- Certificate appears valid in Kubernetes (`kubectl get certificates` shows READY)
- Grafana accessible via HTTP but SSL certificate rejected by browser
- Error persists across browser restarts and incognito mode

**Diagnosis:**
```bash
# Check certificate status
kubectl get certificates -A
# Shows: grafana-tls   True    grafana-tls   29h

# Check ingress configuration
kubectl describe ingress monitoring-ingress -n monitoring
# May show missing TLS configuration or wrong certificate reference

# Verify certificate secret
kubectl get secret grafana-tls -n monitoring
# Should show: kubernetes.io/tls type with 2 data entries
```

**Root Cause Analysis:**
1. **Missing TLS Configuration**: Grafana ingress lacked TLS section despite certificate being issued
2. **Certificate Reference**: Ingress not referencing the correct certificate secret
3. **Browser Cache**: Browser cached invalid certificate from previous failed attempts
4. **Cloudflare Interference**: DNS proxy settings interfering with certificate validation

**Solutions Applied:**

**Option A: Add TLS Configuration to Existing Ingress**
```bash
# Patch existing ingress to add TLS configuration
kubectl patch ingress monitoring-ingress -n monitoring --type merge -p '{"spec":{"tls":[{"hosts":["grafana.chat.canepro.me"],"secretName":"grafana-tls"}]}}'

# Add SSL redirect annotations
kubectl patch ingress monitoring-ingress -n monitoring --type merge -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/ssl-redirect":"true","nginx.ingress.kubernetes.io/force-ssl-redirect":"true"}}}'

# Add cert-manager issuer annotation
kubectl patch ingress monitoring-ingress -n monitoring --type merge -p '{"metadata":{"annotations":{"cert-manager.io/cluster-issuer":"production-cert-issuer"}}}'
```

**Option B: Browser Cache Clearing**
- Clear SSL state in browser settings
- Try incognito/private browsing mode
- Use different browser (Chrome vs Firefox vs Edge)
- Hard refresh with Ctrl+F5

**Option C: Cloudflare DNS Configuration**
```bash
# Set DNS record to "DNS only" (grey cloud) during certificate issuance
# Cloudflare DNS Settings:
# Type: A
# Name: grafana.chat.canepro.me
# Value: 4.250.169.133
# Proxy Status: DNS only (grey cloud)

# After certificate issues, change back to:
# Proxy Status: Proxied (orange cloud)
# SSL: Full (strict)
# Always Use HTTPS: On
```

**Verification:**
```bash
# Test HTTPS connectivity
curl -I https://grafana.chat.canepro.me
# Should return: HTTP/2 200 (not HTTP/2 302 redirect)

# Check ingress TLS configuration
kubectl get ingress monitoring-ingress -n monitoring
# Should show: PORTS 80, 443
```

**Prevention:**
- Always verify ingress TLS configuration after certificate issuance
- Test SSL certificate with multiple browsers before production use
- Monitor certificate expiry and reissue process
- Temporarily disable Cloudflare proxy during certificate troubleshooting
- Keep backup certificates ready for emergency rollback

**Expected Resolution Time:** 5-10 minutes after TLS configuration fix

### Issue: Prometheus Not Discovering Rocket.Chat After Patch (September 18, 2025)

Symptoms:
- Prometheus UI shows no targets for Rocket.Chat
- PodMonitor exists but targets list is empty

Diagnosis:
```bash
kubectl get podmonitor -A | grep rocketchat
kubectl -n monitoring get prometheus monitoring-kube-prometheus-prometheus -o yaml | grep -A6 serviceMonitorNamespaceSelector
```

Root Cause:
- Namespace selectors limited to a single namespace; fixed to include both `monitoring` and `rocketchat` via matchExpressions.

Resolution:
```bash
kubectl apply -f aks/monitoring/prometheus-patch.yaml
kubectl -n monitoring rollout restart statefulset/monitoring-kube-prometheus-prometheus
```

Prevention:
- Prefer `matchExpressions` + In operator for cross-namespace scraping.
- Keep `release: monitoring` label consistent on PodMonitor/PrometheusRule.

---

## 🔐 **Authentication Issues - RESOLVED (September 6, 2025)**

### **Issue: Grafana Authentication Temporarily Blocked**

**Symptoms:**
- All passwords fail when logging into Grafana
- Browser shows "Invalid login credentials" for all attempts
- Grafana logs show: `[password-auth.failed] too many consecutive incorrect login attempts for user - login for user temporarily blocked`
- Account becomes completely inaccessible
- Issue persists across browser sessions and devices

**Diagnosis:**
```bash
# Check Grafana pod logs for authentication errors
kubectl logs grafana-deployment-699c8d585-xxxxx -n monitoring --tail=20
# Shows: "too many consecutive incorrect login attempts for user - login for user temporarily blocked"

# Verify current admin credentials from Kubernetes secret
kubectl get secret grafana-admin-credentials -n monitoring -o yaml
# Decode password: kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
# Should return: admin

# Check if multiple Grafana instances exist
kubectl get pods -n monitoring | grep grafana
# May show multiple Grafana pods with different configurations
```

**Root Cause Analysis:**
1. **Security Lockout**: Grafana's built-in security feature blocks accounts after multiple failed login attempts
2. **Multiple Instances**: Two Grafana deployments running simultaneously causing confusion
3. **Credential Mismatch**: Using incorrect password from documentation vs actual Kubernetes secret
4. **Browser Cache**: Browser remembering old failed login attempts
5. **Pod Persistence**: Authentication block stored in persistent volume survives pod restarts

**Solutions Applied:**

**Option A: Clear Authentication Block via Pod Restart + PVC Deletion**
```bash
# Delete the Grafana pod (temporary fix)
kubectl delete pod grafana-deployment-699c8d585-xxxxx -n monitoring

# If block persists, delete the persistent volume claim to clear all authentication state
kubectl delete pvc grafana-pvc -n monitoring

# Wait for new pod to start with fresh PVC
kubectl wait --for=condition=ready pod/grafana-deployment-xxxxx -n monitoring --timeout=120s
```

**Option B: Verify Correct Credentials**
```bash
# Get actual admin credentials from Kubernetes secret
kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d
# Returns: admin

kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
# Returns: admin

# Login with: admin / admin
```

**Option C: Check for Multiple Grafana Instances**
```bash
# Identify all Grafana deployments
kubectl get deployments -n monitoring | grep grafana
# May show: grafana-deployment, monitoring-grafana

# Check which ingress points to which service
kubectl get ingress -n monitoring -o yaml | grep -A 5 "backend:"
# Shows which service the ingress routes to

# Verify service configurations
kubectl get svc -n monitoring | grep grafana
kubectl describe svc grafana-service -n monitoring
```

**Verification:**
```bash
# Test Grafana accessibility after fix
curl -I https://grafana.chat.canepro.me
# Should return: HTTP/2 200

# Check Grafana logs for successful authentication
kubectl logs grafana-deployment-xxxxx -n monitoring --tail=10
# Should show successful login: "userId=1 orgId=1 uname=admin"
```

**Prevention:**
- **Document Actual Credentials**: Always verify credentials from Kubernetes secrets, not documentation
- **Single Source of Truth**: Use `kubectl get secret` to check actual admin credentials
- **Monitor Failed Attempts**: Watch Grafana logs for authentication failures
- **Update Documentation**: Immediately update README with correct credentials after deployment
- **Browser Testing**: Test login with incognito mode to avoid cached failures
- **PVC Management**: Consider PVC deletion as emergency reset option for authentication issues

**Expected Resolution Time:** 2-5 minutes for pod restart, 5-10 minutes for PVC recreation

---

## 📊 **Grafana Dashboard & Loki Integration Issues**

### **Issue: Loki Data Source Not Appearing in Grafana**

**Symptoms:**
- Loki data source is not available in Grafana Explore
- "No data sources available" message in Grafana
- Console errors: `"Datasource dex7bydz86h34d was not found"`
- Log queries fail with data source connection errors
- `kubectl get configmap -n monitoring` shows Loki datasource ConfigMap exists

**Diagnosis:**
```bash
# Check ConfigMap labels (CRITICAL)
kubectl get configmap -n monitoring -l grafana_dashboard=1
# Should show: monitoring-grafana-loki-datasource

# Verify Grafana sidecar configuration
kubectl describe deployment monitoring-grafana -n monitoring | grep "LABEL:"
# Should show: LABEL: grafana_dashboard, LABEL_VALUE: 1

# Check Grafana status
kubectl describe grafana grafana -n monitoring
# Check Datasources section - should include Loki
```

**Root Cause Analysis:**
1. **Incorrect ConfigMap Labels**: Loki datasource ConfigMap uses `grafana_datasource: "1"` instead of `grafana_dashboard: "1"`
2. **Sidecar Label Mismatch**: kube-prometheus-stack sidecar expects `grafana_dashboard` label but ConfigMap uses different label
3. **Mount Failure**: ConfigMap not mounted to Grafana pod due to label mismatch
4. **Service Name Issues**: Promtail configuration may use incorrect Loki service URL

**Solutions Applied:**

**Option A: Fix ConfigMap Labels**
```yaml
# Update monitoring/grafana-datasource-loki.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # ✅ Correct label for sidecar
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      uid: loki
      url: http://loki-stack.loki-stack.svc.cluster.local:3100
      access: proxy
      jsonData:
        maxLines: 1000
```

**Option B: Fix Promtail Loki URL**
```yaml
# Update monitoring/loki-values.yaml
promtail:
  config:
    clients:
      - url: http://loki-stack.loki-stack.svc.cluster.local:3100/loki/api/v1/push
        # Changed from: http://loki.loki-stack.svc.cluster.local:3100/loki/api/v1/push
```

**Option C: Restart Grafana Deployment**
```bash
# Apply ConfigMap changes
kubectl apply -f monitoring/grafana-datasource-loki.yaml

# Restart Grafana to reload data sources
kubectl rollout restart deployment monitoring-grafana -n monitoring

# Verify Loki appears in Grafana Explore
# Access: https://grafana.chat.canepro.me/explore
```

**Verification:**
```bash
# Test Loki connectivity from Grafana pod
kubectl exec -n monitoring monitoring-grafana-xxxxx -c grafana -- \
  curl -s http://loki-stack.loki-stack.svc.cluster.local:3100/ready

# Check Grafana data sources API
kubectl run test-grafana-ds --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
  curl -s -u admin:admin http://monitoring-grafana:80/api/datasources | jq length
# Should return: 2 (Prometheus + Loki)
```

**Prevention:**
- Always use `grafana_dashboard: "1"` for both data sources and dashboards in kube-prometheus-stack
- Verify sidecar configuration matches ConfigMap labels
- Test data source connectivity before deploying
- Use consistent service naming conventions
- Monitor Grafana logs for data source errors

**Expected Resolution Time:** 2-5 minutes after configuration fixes

---

### **Issue: Rocket.Chat Logs Not Appearing in Loki**

**Symptoms:**
- No Rocket.Chat application logs in Grafana Explore
- Promtail pods running but not collecting logs
- Loki queries return empty results for Rocket.Chat
- `kubectl logs loki-stack-promtail` shows no Rocket.Chat log entries

**Diagnosis:**
```bash
# Check Promtail configuration
kubectl get configmap -n loki-stack loki-stack -o yaml
# Verify scrape_configs for Rocket.Chat logs

# Check log file paths
kubectl exec -n loki-stack loki-stack-promtail-xxxxx -- ls -la /var/log/containers/
# Should show Rocket.Chat log files

# Test Loki query
kubectl run test-loki-query --image=curlimages/curl --rm -i --restart=Never --namespace loki-stack -- \
  curl -G "http://loki-stack:3100/loki/api/v1/query_range" --data-urlencode 'query={app="rocketchat"}' --data-urlencode 'limit=5'
```

**Root Cause Analysis:**
1. **Incorrect Log Paths**: Promtail configured for wrong container log paths
2. **Service Name Mismatch**: Promtail sending logs to wrong Loki service URL
3. **RBAC Issues**: Promtail lacks permissions to read log files
4. **Volume Mount Issues**: Promtail cannot access container log directory

**Solutions Applied:**

**Option A: Update Promtail Scrape Configuration**
```yaml
# Update monitoring/loki-values.yaml
promtail:
  config:
    scrape_configs:
      - job_name: rocketchat-app
        static_configs:
          - targets: [localhost]
            labels:
              job: rocketchat
              app: rocketchat
              __path__: /var/log/containers/*rocketchat*.log  # ✅ Correct path
        pipeline_stages:
          - docker: {}
          - json:
              expressions:
                level: level
                message: message
          - labels:
              level:
              service:
```

**Option B: Verify Log File Access**
```bash
# Check Promtail can access log files
kubectl exec -n loki-stack loki-stack-promtail-xxxxx -- \
  find /var/log/containers -name "*rocketchat*" -type f | head -5

# Test log parsing
kubectl exec -n loki-stack loki-stack-promtail-xxxxx -- \
  tail -n 10 /var/log/containers/*rocketchat*.log
```

**Option C: RBAC Configuration**
```yaml
# Ensure Promtail has proper permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail-clusterrole
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

**Verification:**
```bash
# Test log collection
kubectl logs -n loki-stack loki-stack-promtail-xxxxx | grep rocketchat

# Query logs in Loki
kubectl run test-loki-logs --image=curlimages/curl --rm -i --restart=Never --namespace loki-stack -- \
  curl -G "http://loki-stack:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={app="rocketchat"}' \
    --data-urlencode 'limit=10'

# Should return Rocket.Chat log entries
```

**Prevention:**
- Verify log file paths match actual container log locations
- Test Promtail configuration before deployment
- Ensure proper RBAC permissions for log access
- Use correct Loki service URLs in Promtail configuration
- Monitor Promtail logs for collection errors

**Expected Resolution Time:** 2-3 minutes after configuration updates

---

### Issue: Bitnami MongoDB Brownout - Images Unavailable (September 17-19, 2025)

**Date:** September 18, 2025
**Severity:** Critical
**Component:** MongoDB (Bitnami subchart)

#### **Symptoms**
- MongoDB pods showing `ImagePullBackOff` or `ErrImagePull`
- Events show errors like:
  - `ghcr.io/bitnami/mongodb:6.0: not found`
  - `docker.io/bitnami/mongodb:6.0.10-debian-11-r4: not found`
  - `docker.io/bitnami/mongodb:6.0.18: not found`
  - `docker.io/bitnami/mongodb:latest: not found`
- All Rocket.Chat services in `CrashLoopBackOff` due to MongoDB unavailable

#### **Root Cause**
- **Bitnami Brownout Period**: September 17-19, 2025, MongoDB images temporarily unavailable
- Part of Bitnami's transition to Bitnami Secure Images (BSI)
- MongoDB is one of 24 images affected in Brownout 3
- During brownout, only `latest` tag available for community-tier images, but even that may fail

#### **Solutions**

**Solution 1: Deploy Standalone MongoDB with Official Image**
```bash
# 1. Apply standalone MongoDB deployment
kubectl apply -f aks/config/mongodb-standalone.yaml

# 2. Update Rocket.Chat values to use external MongoDB
# In values-official.yaml:
mongodb:
  enabled: false  # Disable Bitnami subchart
  auth:
    # Required by Helm chart even when disabled
    passwords:
      - "rocketchat"
    rootPassword: "rocketchatroot"
    database: "rocketchat"

extraEnv:
  - name: MONGO_URL
    value: "mongodb://mongodb-0.mongodb-headless:27017,mongodb-1.mongodb-headless:27017,mongodb-2.mongodb-headless:27017/rocketchat?replicaSet=rs0"
  - name: MONGO_OPLOG_URL
    value: "mongodb://mongodb-0.mongodb-headless:27017,mongodb-1.mongodb-headless:27017,mongodb-2.mongodb-headless:27017/local?replicaSet=rs0"

# 3. Upgrade Rocket.Chat release
helm upgrade rocketchat rocketchat/rocketchat -f values-official.yaml --namespace rocketchat
```

**Solution 2: Use Bitnami Legacy Repository (if available)**
```yaml
# Note: May not have all versions
mongodb:
  image:
    registry: docker.io
    repository: bitnamilegacy/mongodb
    tag: "8.0.13"  # Only 8.0 versions available
```

**Solution 3: Wait Until Brownout Ends**
- Brownout ends: September 19, 2025 at 08:00 UTC
- Images will be restored after this time

#### **Prevention**
- **Long-term**: Consider migrating to:
  - Bitnami Secure Images (commercial)
  - Official MongoDB Kubernetes Operator
  - MongoDB Atlas (managed service)
- **Monitor**: Check [Bitnami announcements](https://github.com/bitnami/containers/issues/83267)
- **Plan**: Have external MongoDB deployment ready as backup

#### **Verification**
```bash
# Check MongoDB pods status
kubectl get pods -n rocketchat -l app=mongodb

# Verify MongoDB connectivity
kubectl exec -n rocketchat mongodb-0 -- mongosh --eval "db.adminCommand('ping')"

# Check Rocket.Chat connection
kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat --tail=20
```

#### **Files Created**
- `aks/config/mongodb-standalone.yaml` - Standalone MongoDB deployment
- `aks/scripts/deploy-mongodb-standalone.sh` - Deployment automation script
- `aks/config/helm-values/mongodb-values.yaml` - Alternative values for external MongoDB

---

### Issue: MongoDB Pod Init ImagePullBackOff (bitnami/os-shell) (September 18, 2025)

Symptoms:
- `Init:ImagePullBackOff` on `rocketchat-mongodb-0` init container `volume-permissions`
- Events show `docker.io/bitnami/os-shell:11-debian-11-r72: not found`

Root Cause:
- The Bitnami `os-shell` tag used by the init `volumePermissions` container is unavailable.

Resolutions:
1) Disable volumePermissions in Helm values (preferred):
```yaml
mongodb:
  volumePermissions:
    enabled: false
```
Apply via:
```bash
helm upgrade --install rocketchat rocketchat/rocketchat -n rocketchat -f aks/config/helm-values/values-official.yaml
```

2) Alternatively, override init image (if permissions are needed):
```yaml
mongodb:
  volumePermissions:
    enabled: true
    image:
      registry: docker.io
      repository: bitnami/bitnami-shell
      tag: 11-debian-11-r110
```

Verification:
```bash
kubectl describe pod -n rocketchat rocketchat-mongodb-0 | sed -n '1,120p'
kubectl get pods -n rocketchat
```

Prevention:
- Pin supported Bitnami init image tags or keep volumePermissions disabled when not required.

---

### **Issue: Grafana Dashboard Metrics Not Updating**

**Symptoms:**
- Dashboard panels show "No data" or stale metrics
- Prometheus queries fail in Grafana
- Service discovery issues in dashboards
- Alert rules not firing correctly

**Diagnosis:**
```bash
# Check Prometheus service status
kubectl get svc -n monitoring | grep prometheus
kubectl describe svc monitoring-kube-prometheus-prometheus -n monitoring

# Test Prometheus query
kubectl run test-prometheus --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
  curl -s "http://monitoring-kube-prometheus-prometheus:9090/api/v1/query?query=up"

# Check ServiceMonitor status
kubectl get servicemonitor -n rocketchat
kubectl describe servicemonitor rocketchat-servicemonitor -n rocketchat

# Verify Grafana data source
kubectl describe grafana grafana -n monitoring
# Check Datasources section
```

**Root Cause Analysis:**
1. **Service Discovery Issues**: ServiceMonitor not finding Rocket.Chat pods
2. **Label Mismatches**: Prometheus selectors don't match pod labels
3. **Network Policies**: Blocking communication between namespaces
4. **Resource Limits**: Prometheus hitting memory/CPU limits

**Solutions Applied:**

**Option A: Fix ServiceMonitor Configuration**
```yaml
# Ensure correct ServiceMonitor labels
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rocketchat-servicemonitor
  namespace: rocketchat  # ✅ Must be in same namespace as service
  labels:
    release: monitoring  # ✅ Matches Prometheus selector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: rocketchat  # ✅ Matches service labels
  namespaceSelector:
    matchNames:
      - rocketchat
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

**Option B: Update Service Labels**
```yaml
# Ensure Rocket.Chat service has correct labels
apiVersion: v1
kind: Service
metadata:
  name: rocketchat-rocketchat
  namespace: rocketchat
  labels:
    app.kubernetes.io/instance: rocketchat  # ✅ Required for ServiceMonitor
    app.kubernetes.io/name: rocketchat
spec:
  selector:
    app: rocketchat
  ports:
  - name: http
    port: 80
    targetPort: 3000
```

**Option C: Cross-Namespace Monitoring**
```yaml
# Configure Prometheus for cross-namespace monitoring
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: monitoring-kube-prometheus-prometheus
  namespace: monitoring
spec:
  serviceMonitorNamespaceSelector: {}  # ✅ Monitor all namespaces
  serviceMonitorSelector:
    matchLabels:
      release: monitoring
  ruleNamespaceSelector: {}
  ruleSelector:
    matchLabels:
      release: monitoring
```

**Verification:**
```bash
# Test Prometheus targets
kubectl run test-prom-targets --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
  curl -s "http://monitoring-kube-prometheus-prometheus:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.job=="rocketchat")'

# Check Grafana dashboard
# Access: https://grafana.chat.canepro.me/d/rocket-chat-metrics
# Should show: UP status and current metrics
```

**Prevention:**
- Ensure ServiceMonitor is in same namespace as monitored service
- Use consistent labeling across services and ServiceMonitors
- Configure cross-namespace monitoring when needed
- Test Prometheus queries before creating dashboards
- Monitor ServiceMonitor status regularly

**Expected Resolution Time:** 1-2 minutes after configuration fixes

---

## 📝 **Issue Reporting Template**

When encountering a new issue, use this template:

### **Issue Summary**
**Date:** YYYY-MM-DD
**Severity:** Critical/High/Medium/Low
**Component:** Rocket.Chat/MongoDB/Monitoring/Ingress/etc.

### **Symptoms**
- Describe what you're observing
- Include error messages
- Note affected functionality

### **Environment**
- AKS version: `kubectl version`
- Helm version: `helm version`
- Rocket.Chat version: Check in values-official.yaml
- Cluster size: Number of nodes

### **Troubleshooting Steps Taken**
- Commands run
- Logs checked
- Configuration verified

### **Resolution**
- Solution implemented
- Files modified
- Commands that resolved the issue

### **Prevention/Follow-up**
- How to prevent this issue
- Monitoring to add
- Documentation updates needed

---

## 🔗 **Useful Resources**

### **Official Documentation**
- [Rocket.Chat Kubernetes Deploy](https://docs.rocket.chat/docs/deploy-with-kubernetes)
- [Helm Charts Repository](https://github.com/RocketChat/helm-charts)
- [AKS Troubleshooting](https://docs.microsoft.com/en-us/azure/aks/troubleshoot)

### **Community Support**
- [Rocket.Chat Forums](https://forums.rocket.chat/)
- [Kubernetes Slack](https://kubernetes.slack.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/rocket.chat)

### **Monitoring Tools**
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)

---

## 📝 **Documented Issues from Current Deployment**

### **Issue: Helm Segmentation Fault (September 4, 2025)**

**Symptoms:**
- `helm version` returns "Segmentation fault"
- `helm repo add` fails with segfault
- Any Helm command crashes immediately

**Root Cause:**
- Corrupted Helm binary installation
- WSL/Windows integration issues
- Version conflicts or missing dependencies

**Resolution Applied:**
```bash
# Remove old Helm installation
sudo rm /usr/local/bin/helm

# Install fresh Helm using official script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version  # Should show v3.18.6
```

**Prevention:**
- Use official Helm installation scripts
- Avoid manual binary downloads
- Regularly check Helm version compatibility

---

### **Issue: Kubernetes Cluster Unreachable (September 4, 2025)**

**Symptoms:**
- `helm install` fails with "Kubernetes cluster unreachable: Get http://localhost:8080/version"
- kubectl works but Helm cannot connect to cluster
- Error shows wrong API server endpoint (localhost:8080 instead of AKS)

**Root Cause:**
- Helm using different kubeconfig than kubectl
- KUBECONFIG environment variable not set
- WSL/Windows kubeconfig path mismatch

**Resolution Applied:**
```bash
# Set KUBECONFIG explicitly
export KUBECONFIG=/mnt/c/Users/i/.kube/config

# Verify kubectl works
kubectl config current-context  # Should show canepro_aks
kubectl cluster-info           # Should connect to AKS

# Test Helm connection
helm list --all-namespaces      # Should work now
```

**Prevention:**
- Always set KUBECONFIG environment variable explicitly
- Use `kubectl config view --minify` to verify correct context
- Ensure consistent kubeconfig paths between kubectl and Helm

---

### **Issue: Missing CRDs for Monitoring Stack (September 4, 2025)**

**Symptoms:**
- `helm install monitoring` fails with "resource mapping not found"
- Errors about missing `monitoring.coreos.com/v1` CRDs
- Grafana CRDs from `grafana.integreatly.org/v1beta1` not found

**Root Cause:**
- Rocket.Chat monitoring chart requires Prometheus Operator CRDs
- kube-prometheus-stack CRDs not installed
- Chart assumes CRDs are pre-installed

**Resolution Applied:**
- Identified CRD requirements from error messages
- Attempted multiple CRD installation methods
- Decided to deploy Rocket.Chat first, add monitoring later

**Alternative Solutions:**
```bash
# Option 1: Install Prometheus Operator CRDs manually
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/

# Option 2: Use Helm to install CRDs
helm install prometheus-operator prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set installCRDs=true

# Option 3: Deploy Rocket.Chat first, monitoring second
helm install rocketchat rocketchat/rocketchat --namespace rocketchat --create-namespace
# Then add monitoring later
```

**Prevention:**
- Always check CRD requirements before chart installation
- Use `--set installCRDs=true` when available
- Deploy core applications before complex monitoring stacks
- Test with `--dry-run` first to identify missing dependencies

---

### **Issue: Chart Repository Connection Issues (September 4, 2025)**

**Symptoms:**
- `helm repo add` works but subsequent commands fail
- Repository becomes unavailable after initial add
- `helm search repo` shows empty results

**Root Cause:**
- Network connectivity issues to GitHub
- Repository cache corruption
- DNS resolution problems in WSL environment

**Resolution Applied:**
- Repository was successfully added and updated
- Chart downloads worked after KUBECONFIG fix
- Connection stabilized after cluster connectivity resolved

**Prevention:**
- Verify network connectivity before Helm operations
- Use `helm repo update` after adding repositories
- Clear Helm cache if repository issues persist: `helm repo remove <name> && helm repo add <name> <url>`

---

### **Issue: Deployment Script Environment Issues (September 4, 2025)**

**Symptoms:**
- Bash scripts fail with path issues
- Environment variables not propagated correctly
- Commands work individually but fail in scripts

**Root Cause:**
- WSL environment variable handling
- Script execution context differences
- Path resolution issues between Windows and WSL

**Resolution Applied:**
- Set KUBECONFIG explicitly in commands
- Use full paths in scripts
- Test commands individually before script execution

**Prevention:**
- Always use explicit environment variables in scripts
- Test commands in interactive shell before scripting
- Use absolute paths for critical operations

---

### **Issue: Resource Quota and Limit Issues (Ongoing)**

**Symptoms:**
- Pods fail with insufficient CPU/memory errors
- Resource quota exceeded messages
- Horizontal scaling failures

**Root Cause:**
- Default AKS resource limits
- Application resource requests too high
- No resource quotas configured

**Prevention Strategies:**
```yaml
# In values-official.yaml, optimize resources:
resources:
  requests:
    cpu: 200m      # Reduced from 500m
    memory: 512Mi  # Reduced from 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

# Monitor resource usage
kubectl top pods -n rocketchat
kubectl top nodes
```

---

### **Issue: SSL Certificate Challenges with Cloudflare (September 4, 2025)**

**Symptoms:**
- Certificate status: `False` (not ready)
- CertificateRequest status: `Waiting on certificate issuance... "pending"`
- Browser shows: `net::ERR_CERT_AUTHORITY_INVALID`
- Let's Encrypt unable to validate domain ownership

**Root Cause:**
- Cloudflare's proxy/CDN interferes with HTTP-01 ACME challenges
- Cloudflare security features block challenge requests
- Domain needs DNS-only mode during certificate issuance

**Resolution Applied:**
```bash
# Cloudflare Configuration Required:
# 1. Set DNS record to "DNS only" (not proxied)
# 2. Disable Cloudflare security features temporarily
# 3. Wait for certificate issuance (5-10 minutes)
# 4. Re-enable proxy and security features
```

**Cloudflare DNS Settings:**
```
Type: A
Name: chat.canepro.me
Value: 4.250.169.133
Proxy Status: DNS only (grey cloud)
TTL: Auto
```

**After Certificate Issues:**
```
Proxy Status: Proxied (orange cloud)
SSL: Full (strict)
Always Use HTTPS: On
```

**Prevention:**
- Temporarily disable Cloudflare proxy during certificate issuance
- Use DNS-only mode for the domain during initial setup
- Monitor certificate expiry and re-issue process
- Keep backup certificates ready

---

### **Issue: ERR_CERT_AUTHORITY_INVALID with Valid Certificate (September 6, 2025)**

**Symptoms:**
- Browser shows: `net::ERR_CERT_AUTHORITY_INVALID`
- Certificate status shows `READY: True` in Kubernetes
- `kubectl describe certificate` shows valid expiry dates
- Error appears consistently across page reloads

**Root Cause:**
- Browser SSL cache contains old/invalid certificate data
- Cloudflare proxy interfering with certificate chain validation
- Certificate chain trust issue on client side

**Resolution Applied:**
```bash
# Certificate is actually valid - confirmed:
kubectl get certificates -n monitoring
# NAME          READY   SECRET        AGE
# grafana-tls   True    grafana-tls   27h

# Certificate details show valid Let's Encrypt chain:
kubectl describe certificate grafana-tls -n monitoring
# Not After: 2025-12-04T16:41:48Z (valid until December)
```

**Browser Solutions:**
1. **Clear SSL State**: Chrome Settings → Privacy → Clear browsing data (include SSL certificates)
2. **Try Incognito Mode**: Test if works in private/incognito browsing
3. **Different Browser**: Test with Firefox/Edge to isolate Chrome-specific issue
4. **Hard Refresh**: Ctrl+F5 or Cmd+Shift+R to bypass cache

**Cloudflare Solutions:**
1. **Disable Proxy Temporarily**: Set DNS record to "DNS only" (grey cloud)
2. **SSL Mode**: Ensure Cloudflare SSL is set to "Full (strict)"
3. **Wait for Propagation**: 5-10 minutes after DNS changes

**Expected Resolution Time:** Immediate for browser cache fixes, 5-10 minutes for DNS changes

---

### **Issue: Grafana Login Password Incorrect (September 6, 2025)**

**Symptoms:**
- Grafana login fails with correct-looking credentials
- Password from README.md doesn't work: `GrafanaAdmin2024!`
- Username `admin` is correct but password is rejected
- Issue occurs after successful SSL certificate resolution

**Root Cause:**
- Current deployment uses default Grafana credentials: `admin/admin`
- README.md contains outdated password from previous configuration
- Grafana operator creates secret with default credentials during deployment

**Diagnosis:**
```bash
# Check actual Grafana credentials in Kubernetes secret
kubectl get secret grafana-admin-credentials -n monitoring -o yaml

# Decode the password (both username and password are base64 encoded)
kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
# Output: admin

kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d  
# Output: admin
```

**Current Working Credentials:**
- **Username**: `admin`
- **Password**: `admin`

**Resolution Applied:**
1. **Updated README.md**: Changed password from `GrafanaAdmin2024!` to `admin`
2. **Verified Access**: Confirmed login works with correct credentials
3. **Documentation**: Added this issue to troubleshooting guide

**Prevention:**
- Always verify credentials from Kubernetes secrets rather than documentation
- Update README.md immediately after deployment with actual credentials
- Consider changing default password after first login for security
- Document credential verification commands for future reference

**Security Recommendation:**
After successful login, change the default password:
1. Login to Grafana with `admin/admin`
2. Go to Configuration → Users
3. Click on admin user and change password
4. Update documentation with new password

**Expected Resolution Time:** Immediate with correct credentials

---

### **Issue: Grafana 404 Not Found Error (September 4, 2025)**

**Symptoms:**
- `https://grafana.chat.canepro.me` returns "404 Not Found nginx error"
- Error appears only in incognito browser mode
- Port forwarding to Grafana pod fails or doesn't connect
- Grafana service exists and is running but not accessible via domain

**Diagnosis Steps Taken:**
```bash
# Check ingress configuration
kubectl get ingress monitoring-ingress -n monitoring -o yaml | grep -A 5 "paths:"
# Shows: path: /grafana, backend service: grafana-service

# Check Grafana pod environment variables
kubectl describe pod grafana-deployment-774dff4b6c-rrsdd -n monitoring
# Shows:
# GF_SERVER_SERVE_FROM_SUB_PATH: true
# GF_SERVER_ROOT_URL: https://grafana.chat.canepro.me/grafana/

# Check ingress path configuration
kubectl get ingress monitoring-ingress -n monitoring -o yaml | grep -A 20 "paths:"
# Shows: path: /grafana, pathType: Prefix

# Attempt port forwarding (multiple attempts)
kubectl port-forward svc/grafana-service -n monitoring 3001:3000 --address 0.0.0.0
curl -I http://localhost:3001/grafana  # Connection refused
curl -I http://4.250.169.133:3001/grafana  # Connection timeout
```

**Current Configuration:**
```yaml
# Ingress configuration (values-monitoring.yaml)
ingress:
  enabled: true
  ingressClassName: "nginx"
  tls: true
  grafana:
    enabled: true
    host: "grafana.chat.canepro.me"
    path: "/grafana"

# Grafana deployment environment
GF_SERVER_SERVE_FROM_SUB_PATH: true
GF_SERVER_ROOT_URL: https://grafana.chat.canepro.me/grafana/
POD_IP: (v1:status.podIP)
```

**Root Cause Analysis:**
- Ingress is correctly configured with path `/grafana`
- Grafana is configured to serve from subpath `/grafana`
- Grafana pod is running and healthy
- Port forwarding attempts are failing, indicating service connectivity issues
- The 404 error suggests the request is reaching nginx but not being routed correctly

**Potential Issues:**
1. **Service Configuration**: `grafana-service` might not be properly configured
2. **Port Mapping**: Service port mapping might be incorrect
3. **Network Policies**: Network policies might be blocking traffic
4. **Endpoint Issues**: Service endpoints might not be properly registered
5. **Browser Cache**: Incognito mode behavior suggests cache-related issues

**Next Steps to Investigate:**
```bash
# Check service endpoints
kubectl get endpoints -n monitoring grafana-service

# Check service detailed configuration
kubectl describe svc grafana-service -n monitoring

# Check network policies
kubectl get networkpolicies -n monitoring

# Test direct pod access
kubectl exec -n monitoring grafana-deployment-774dff4b6c-rrsdd -- curl -I http://localhost:3000

# Check Grafana logs for errors
kubectl logs -n monitoring grafana-deployment-774dff4b6c-rrsdd --tail=50
```

**Latest Findings (September 5, 2025):**
- Service endpoints are properly registered: `10.244.0.72:3000`
- Ingress configuration is correct with path `/grafana`
- Port forwarding attempts are failing, suggesting network connectivity issues
- Both incognito and regular browsers show different behaviors, indicating potential caching or certificate-related issues

**Next Steps:**
```bash
# Test direct pod connectivity
kubectl exec -n monitoring grafana-deployment-774dff4b6c-rrsdd -- curl -I http://localhost:3000

# Check for network policies blocking traffic
kubectl get networkpolicies -n monitoring

# Verify ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50 | grep grafana
```

**Status:** Service endpoints confirmed working - investigating ingress routing and SSL certificate issues

**SSL Certificate Issues - RESOLVED (September 5, 2025):**
- **✅ SUCCESS**: Rocket.Chat SSL certificate issued successfully
- **Order Status**: `valid` (112m)
- **Certificate Status**: `True` (ready)
- **Rocket.Chat Access**: ✅ HTTPS working with valid SSL certificate
- **Grafana Status**: Certificate created, TLS configuration added to ingress
- **Next Steps**: Test Grafana access and perform DNS migration

### **Additional SSL Certificate Resolution Notes:**

**Issue: Grafana Certificate Still Pending**
- **Symptom**: Grafana certificate shows `False` status 20+ minutes after creation
- **Root Cause**: Normal behavior for newly created certificates - Let's Encrypt needs time to issue
- **Resolution**: Wait 5-10 minutes for certificate to be issued
- **Prevention**: Monitor certificate status with `kubectl get certificates -n monitoring -w`

**Issue: Clean URL Configuration**
- **Symptom**: Grafana accessible at `https://grafana.chat.canepro.me/grafana` (unwanted path)
- **Root Cause**: Ingress configured with `/grafana` path instead of root `/`
- **Resolution**: Updated ingress path and restarted Grafana deployment
- **Result**: Now accessible at clean URL `https://grafana.chat.canepro.me`
- **Prevention**: Plan URL structure during initial configuration

---

## 🎯 **Deployment Best Practices Learned**

### **1. Environment Setup**
- Always set `KUBECONFIG` explicitly
- Verify cluster connectivity before Helm operations
- Use official installation methods for tools

### **2. Chart Installation Order**
- Install CRDs before charts that require them
- Deploy core applications before monitoring
- Use `--dry-run` to validate configurations

### **3. Troubleshooting Approach**
- Start with basic connectivity tests
- Check kubeconfig consistency
- Verify resource availability
- Use `--debug` flag for detailed error information

### **4. Documentation Importance**
- Document every issue encountered and resolution
- Update troubleshooting guide with new findings
- Maintain deployment logs for future reference

---

**Document Version:** 1.2
**Last Updated:** September 6, 2025
**Next Review:** September 20, 2025 (post-deployment)
**Owner:** Vincent Mogah
**Contact:** your-email@example.com

---

---

## 📊 **Enhanced Monitoring Troubleshooting**

### **Issue: Azure Monitor Integration Problems**

**Symptoms:**
- Azure Monitor not collecting AKS metrics
- Azure Monitor workspace showing no data
- AKS monitoring addon installation failures

**Diagnosis:**
```bash
# Check Azure Monitor addon status
kubectl get pods -n kube-system | grep ama

# Verify Azure Monitor workspace connection
az monitor diagnostic-settings list --resource /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerService/managedClusters/<aks-name>

# Check Azure Monitor agent logs
kubectl logs -n kube-system deployment/ama-metrics
```

**Solutions:**

**Option A: Reinstall Azure Monitor Addon**
```bash
# Remove and reinstall the monitoring addon
az aks disable-addons --resource-group <rg> --name <aks-name> --addons monitoring
az aks enable-addons --resource-group <rg> --name <aks-name> --addons monitoring --workspace-resource-id <workspace-id>
```

**Option B: Verify Permissions**
```bash
# Check Azure CLI authentication
az account show

# Verify AKS permissions
az aks show --resource-group <rg> --name <aks-name> --query "identity"
```

**Prevention:**
- Ensure Azure CLI is properly authenticated
- Verify workspace resource ID is correct
- Check Azure subscription permissions before installation

### **Issue: Loki Stack Deployment Failures**

**Symptoms:**
- Loki pods failing to start
- Persistent volume creation errors
- Grafana datasource connection issues

**Diagnosis:**
```bash
# Check Loki pod status
kubectl get pods -n loki-stack

# Verify persistent volume claims
kubectl get pvc -n loki-stack

# Check Loki logs
kubectl logs -n loki-stack deployment/loki

# Test Loki connectivity
kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- curl http://loki.loki-stack.svc.cluster.local:3100/ready
```

**Solutions:**

**Option A: Fix Storage Issues**
```yaml
# Update loki-values.yaml with correct storage class
loki:
  persistence:
    enabled: true
    storageClass: "azurefile-premium"  # or your available storage class
    size: 50Gi
```

**Option B: Resource Constraints**
```yaml
# Increase resource limits in loki-values.yaml
loki:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
```

**Prevention:**
- Verify storage class availability before deployment
- Ensure sufficient cluster resources
- Test storage provisioning separately

### **Issue: Rocket.Chat Log Collection Issues**

**Symptoms:**
- No Rocket.Chat logs appearing in Loki/Grafana
- Promtail pods showing errors
- Log queries returning empty results

**Diagnosis:**
```bash
# Check Promtail pod status
kubectl get pods -n loki-stack | grep promtail

# Verify Promtail configuration
kubectl get configmap promtail-config -n loki-stack -o yaml

# Check Promtail logs
kubectl logs -n loki-stack deployment/promtail

# Test log file access
kubectl exec -n loki-stack deployment/promtail -- ls -la /var/log/containers/
```

**Solutions:**

**Option A: Update Promtail Configuration**
```yaml
# Fix log path configuration in promtail config
scrape_configs:
  - job_name: rocket-chat
    static_configs:
      - targets:
          - localhost
        labels:
          job: rocket-chat
          __path__: /var/log/containers/*rocketchat*.log  # Ensure correct path
```

**Option B: RBAC Permissions**
```yaml
# Create proper RBAC for Promtail
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail-clusterrole
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

**Prevention:**
- Test log file paths before configuration
- Ensure Promtail has proper RBAC permissions
- Verify Loki connectivity before log shipping

### **Issue: Grafana Dashboard Import Failures**

**Symptoms:**
- Custom dashboards not appearing in Grafana
- Dashboard JSON import errors
- Data sources not connecting

**Diagnosis:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana

# Verify dashboard ConfigMap
kubectl get configmap -n monitoring -l grafana_dashboard

# Check Grafana logs
kubectl logs -n monitoring deployment/grafana

# Test data source connectivity
kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- curl http://prometheus.monitoring.svc.cluster.local:9090/api/v1/status/buildinfo
```

**Solutions:**

**Option A: Fix Dashboard Labels**
```yaml
# Ensure ConfigMap has correct labels
apiVersion: v1
kind: ConfigMap
metadata:
  name: rocket-chat-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # Required for auto-import
data:
  dashboard.json: |
    # Dashboard JSON content
```

**Option B: Data Source Configuration**
```yaml
# Verify Prometheus data source
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  datasource.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus.monitoring.svc.cluster.local:9090
      access: proxy
      isDefault: true
```

**Prevention:**
- Use correct ConfigMap labels for auto-import
- Test data source connectivity before dashboard creation
- Validate JSON syntax before applying

#### **RESOLVED CASE: Missing grafana_dashboard=1 Label (September 21, 2025)**

**Specific Incident:**
Dashboard ConfigMap `rocket-chat-dashboard-comprehensive` with 28 comprehensive monitoring panels failed to appear in Grafana UI despite valid JSON content and proper namespace.

**Investigation Process:**
```bash
# 1. Verified ConfigMap existence but found missing critical label
kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring --show-labels
# Output: LABELS <none> ❌

# 2. Applied required label immediately 
kubectl label configmap rocket-chat-dashboard-comprehensive -n monitoring grafana_dashboard=1
# Output: configmap/rocket-chat-dashboard-comprehensive labeled ✅

# 3. Monitored sidecar processing logs
kubectl logs -n monitoring monitoring-grafana-7c767f8d44-5lgmd -c grafana-sc-dashboard --tail=20
# Success: "Writing /tmp/dashboards/rocket-chat-dashboard-comprehensive.json (ascii)"

# 4. Verified dashboard file creation (22,947 bytes)
kubectl exec -n monitoring monitoring-grafana-7c767f8d44-5lgmd -c grafana-sc-dashboard -- ls -la /tmp/dashboards/
```

**Key Technical Insights:**
- **Silent Failure Mode**: Missing label causes complete silence - no error logs, no warnings
- **Immediate Processing**: Once labeled, sidecar processes within 10-20 seconds  
- **Label Specificity**: Must be exactly `grafana_dashboard=1` (not `grafana-dashboard` or other variants)
- **File Verification**: Dashboard successfully created with correct size confirms processing

**Resolution Timeline:**
- **Problem Identification**: 2 minutes via systematic label checking
- **Fix Application**: 30 seconds for label addition
- **Dashboard Processing**: 10 seconds sidecar processing time
- **Total Resolution**: Under 3 minutes with structured troubleshooting

**Root Cause Analysis:**
The ConfigMap creation process missed the essential discovery label:
```yaml
# ❌ PROBLEMATIC - Missing discovery label
apiVersion: v1
kind: ConfigMap
metadata:
  name: rocket-chat-dashboard-comprehensive  
  namespace: monitoring
  # labels: {} <- Empty - sidecar ignores completely

# ✅ CORRECT - With required discovery label
apiVersion: v1
kind: ConfigMap  
metadata:
  name: rocket-chat-dashboard-comprehensive
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # CRITICAL for sidecar discovery
```

**Status:** ✅ **FULLY RESOLVED** - Dashboard immediately visible in Grafana with all 28 monitoring panels operational

**Prevention for Future Deployments:**
Always verify ConfigMap labels before expecting dashboard import:
```bash
kubectl get configmap <dashboard-name> -n monitoring --show-labels | grep grafana_dashboard=1
```

#### **RESOLVED CASE: JSON Syntax Errors Preventing Dashboard Import (September 21, 2025)**

**Specific Incident:**
Dashboard ConfigMap existed with proper `grafana_dashboard=1` label, sidecar created the dashboard file, but dashboard still not appearing in Grafana UI due to JSON parsing failures.

**Symptoms:**
- ConfigMap properly labeled and processed by sidecar
- Dashboard file created in `/tmp/dashboards/` directory  
- Dashboard not visible in Grafana UI
- Grafana logs showing JSON parsing errors

**Investigation Process:**
```bash
# 1. Check Grafana main container logs for import errors
kubectl logs -n monitoring <grafana-pod> -c grafana --tail=20 | grep -i error

# Sample error output:
# logger=provisioning.dashboard level=error msg="failed to load dashboard from" 
# file=/tmp/dashboards/dashboard.json error="invalid character '\\r' in string literal"

# 2. Validate JSON syntax locally
python3 -m json.tool aks/monitoring/dashboard.json
# Output: Invalid control character at: line 465 column 21 (char 13713)

# 3. Examine problematic lines
sed -n '460,470p' aks/monitoring/dashboard.json
```

**Root Causes Identified:**

1. **Windows Line Endings Issue**:
   - Dashboard JSON created on Windows with `\r\n` line endings
   - Linux containers expect Unix `\n` line endings
   - Error: `"invalid character '\\r' in string literal"`

2. **Multi-line String Literals in JSON**:
   - Prometheus queries formatted across multiple lines within JSON strings
   - JSON doesn't support literal newlines in string values
   - Error: `"invalid character '\\n' in string literal"`

**Resolution Steps:**
```bash
# Step 1: Fix line endings (Windows to Unix)
sed -i 's/\r$//' aks/monitoring/dashboard.json

# Step 2: Validate JSON syntax
python3 -m json.tool aks/monitoring/dashboard.json
# If errors found, fix multi-line strings

# Step 3: Convert multi-line Prometheus expressions to single line
# WRONG (causes JSON parsing error):
"expr": "(
  sum(metric1) + 
  sum(metric2)
) * 100"

# CORRECT (valid JSON):
"expr": "(sum(metric1) + sum(metric2)) * 100"

# Step 4: Validate corrected JSON
python3 -m json.tool aks/monitoring/dashboard.json > /dev/null && echo "Valid"

# Step 5: Update ConfigMap with corrected JSON
kubectl create configmap dashboard-name --from-file=dashboard.json -n monitoring --dry-run=client -o yaml | kubectl apply -f -

# Step 6: Verify successful import
kubectl logs -n monitoring <grafana-pod> -c grafana --tail=10 | grep dashboard
# Should show: "finished to provision dashboards" without errors
```

**Key Technical Insights:**
- **Silent Failure**: JSON syntax errors cause dashboard import failure without obvious ConfigMap issues
- **Container Environment**: Windows line endings incompatible with Linux containers
- **JSON Specification**: Multi-line strings must be escaped or single-line in JSON
- **Error Location**: Grafana main container logs (not sidecar) show JSON parsing errors

**Verification Commands:**
```bash
# Check dashboard file exists and updated
kubectl exec -n monitoring <grafana-pod> -c grafana-sc-dashboard -- ls -la /tmp/dashboards/ | grep dashboard

# Verify no JSON errors in recent logs
kubectl logs -n monitoring <grafana-pod> -c grafana --tail=20 | grep -i "error.*dashboard"

# Confirm dashboard appears in Grafana UI
# Navigate to Grafana -> Dashboards -> Browse
```

**Prevention Strategies:**
1. **JSON Validation**: Always validate JSON syntax before applying ConfigMaps:
   ```bash
   python3 -m json.tool dashboard.json > /dev/null && echo "Valid" || echo "Invalid"
   ```

2. **Line Ending Consistency**: Use Unix line endings for container-deployed JSON:
   ```bash
   sed -i 's/\r$//' dashboard.json  # Convert Windows to Unix
   ```

3. **Single-line Expressions**: Keep Prometheus queries in single-line format within JSON strings:
   ```json
   "expr": "sum(rate(metric[5m])) * 100"  // Good
   ```

4. **Development Environment**: Configure IDE to use Unix line endings for Kubernetes manifests

5. **CI/CD Pipeline**: Add JSON validation steps to prevent deployment of invalid dashboards

**Status:** ✅ **FULLY RESOLVED** - Dashboard successfully imported and visible in Grafana UI

**Resolution Timeline:**
- **Problem Identification**: 15 minutes via log analysis
- **JSON Syntax Fix**: 5 minutes for line endings + multi-line strings  
- **Validation & Deployment**: 5 minutes
- **Total Resolution**: Under 25 minutes with systematic troubleshooting

**Impact:** This issue prevented comprehensive monitoring dashboard deployment, affecting visibility into Kubernetes workload health and desired vs actual state monitoring.

### **Issue: Alerting Configuration Problems**

**Symptoms:**
- Alerts not firing as expected
- Notification delivery failures
- Alertmanager pod errors

**Diagnosis:**
```bash
# Check Alertmanager status
kubectl get pods -n monitoring | grep alertmanager

# Verify alert rules
kubectl get prometheusrules -n monitoring

# Check Alertmanager configuration
kubectl get secret alertmanager-main -n monitoring -o yaml

# Test alert delivery
kubectl port-forward -n monitoring svc/alertmanager-main 9093:9093
# Then access http://localhost:9093 and check status
```

**Solutions:**

**Option A: Fix Alert Rules**
```yaml
# Correct PrometheusRule syntax
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: rocket-chat-alerts
  namespace: monitoring
spec:
  groups:
  - name: rocket-chat
    rules:
    - alert: RocketChatDown
      expr: up{job="rocketchat"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Rocket.Chat is down"
        description: "Rocket.Chat has been down for more than 5 minutes"
```

**Option B: SMTP Configuration**
```yaml
# Fix email configuration in alertmanager secret
alertmanager.yaml: |
  global:
    smtp_smarthost: 'smtp.gmail.com:587'
    smtp_from: 'alerts@yourdomain.com'
    smtp_auth_username: 'alerts@yourdomain.com'
    smtp_auth_password: 'your-app-password'
    smtp_require_tls: true
```

**Prevention:**
- Test SMTP configuration before deployment
- Validate Prometheus rule syntax
- Use alert grouping to reduce noise

---

---

## ✅ **Phase 1 Enhanced Monitoring - SUCCESSFULLY COMPLETED**

### **Implementation Results: September 5, 2025**

**✅ Rocket.Chat ServiceMonitor**: Successfully deployed and collecting metrics
**✅ Prometheus Alerts**: 5 custom Rocket.Chat alerts configured and active
**✅ Grafana Dashboard**: "Rocket.Chat Production Monitoring" automatically imported and working
**✅ Cross-namespace Monitoring**: Prometheus configured for rocketchat namespace
**✅ Real-time Metrics**: CPU, memory, pod status, MongoDB status all displaying correctly

### **Dashboard Features Verified:**
- ✅ **Service Status Panel**: Shows Rocket.Chat UP/DOWN status
- ✅ **Pod Count Panel**: Displays active Rocket.Chat pod count
- ✅ **CPU Usage Graph**: Real-time CPU metrics for all pods
- ✅ **Memory Usage Graph**: Real-time memory metrics for all pods
- ✅ **Pod Restarts Graph**: Tracks container restart events
- ✅ **MongoDB Status Panel**: Database connectivity monitoring
- ✅ **HTTP Requests Graph**: Application traffic monitoring
- ✅ **Alerts Table**: Active Rocket.Chat alert status

### **Configuration Summary:**
- **API Version**: `azmonitoring.coreos.com/v1` (AKS compatible)
- **ServiceMonitor**: `rocketchat-servicemonitor` in rocketchat namespace
- **PrometheusRule**: `rocketchat-alerts` with 5 alert rules
- **ConfigMap**: `rocket-chat-dashboard` with auto-import label
- **Grafana Access**: `http://4.250.192.85` (LoadBalancer external IP)

### **Key Success Factors:**
1. **Correct API Version**: Used AKS-compatible CRD version
2. **Proper Namespacing**: ServiceMonitor in correct namespace with cross-namespace monitoring
3. **Sidecar Configuration**: Grafana sidecar properly configured for dashboard import
4. **Label Matching**: All resources have correct Prometheus selector labels
5. **JSON Validation**: Dashboard JSON properly formatted for Grafana v12.1.1

---

**Phase 1 Enhanced Monitoring**: ✅ **FULLY OPERATIONAL**
**Documentation Updated**: September 5, 2025
**Next Phase**: Phase 2 - Loki Stack Deployment

*This troubleshooting guide now includes successful Phase 1 implementation results. Phase 1 enhanced monitoring is complete and fully operational.*

---

### **Issue: Grafana Loki Data Source Configuration Problems (September 6, 2025)** ⭐ **Recently Resolved**

**Symptoms:**
- Console errors: `"Datasource dex7bydz86h34d was not found"`
- Console errors: `"Datasource dex7eokbu33swf was not found"`
- Browser errors: `GET /api/datasources/uid/dex7eokbu33swf/health 400 (Bad Request)`
- Grafana Explore interface showing "No data sources available"
- Loki queries failing with data source connection errors
- Grafana data source health checks returning 400 status codes

**Diagnosis:**
```bash
# Check Grafana data source ConfigMaps
kubectl get configmap -n monitoring | grep grafana
# Shows: monitoring-grafana-loki-datasource

# Verify ConfigMap labels (CRITICAL ISSUE)
kubectl get configmap monitoring-grafana-loki-datasource -n monitoring -o yaml | grep labels
# PROBLEM: Shows "grafana_datasource: 1" instead of "grafana_dashboard: 1"

# Check sidecar configuration
kubectl describe deployment monitoring-grafana -n monitoring | grep -A 10 "grafana-sc-datasources"
# Shows: LABEL: grafana_dashboard, LABEL_VALUE: 1

# Verify data source file location
kubectl exec -n monitoring monitoring-grafana-<pod> -c grafana -- ls -la /etc/grafana/provisioning/datasources/
# PROBLEM: Directory empty - ConfigMap not mounted

# Check Grafana logs for data source errors
kubectl logs -n monitoring monitoring-grafana-<pod> --tail=20
# Shows authentication failures preventing data source reload
```

**Root Cause Analysis:**
1. **Label Mismatch**: Loki data source ConfigMap used `grafana_datasource: "1"` label but kube-prometheus-stack sidecar expects `grafana_dashboard: "1"`
2. **Sidecar Configuration**: Grafana sidecar was configured to watch for dashboard labels, not data source labels
3. **Mount Failure**: ConfigMap not mounted to `/etc/grafana/provisioning/datasources/` due to label mismatch
4. **Authentication Issues**: Previous failed login attempts caused rate limiting, preventing data source reload
5. **Cached References**: Grafana retained references to old/non-existent data source UIDs from previous configurations

**Solutions Applied:**

**Option A: Fix ConfigMap Labels**
```yaml
# Update monitoring/grafana-datasource-loki.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # ✅ Corrected from grafana_datasource
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      uid: loki
      url: http://loki-stack.loki-stack.svc.cluster.local:3100
      access: proxy
      jsonData:
        maxLines: 1000
```

**Option B: Manual Data Source File Deployment**
```bash
# Copy Loki configuration to Grafana pod
kubectl exec -n monitoring monitoring-grafana-<pod> -c grafana -- \
  cp /tmp/dashboards/loki.yaml /etc/grafana/provisioning/datasources/

# Verify file placement
kubectl exec -n monitoring monitoring-grafana-<pod> -c grafana -- \
  ls -la /etc/grafana/provisioning/datasources/
# Should show: loki.yaml file present
```

**Option C: Restart Grafana Deployment**
```bash
# Restart to reload data sources
kubectl rollout restart deployment monitoring-grafana -n monitoring

# Wait for restart completion
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
# Should show: 3/3 Running
```

**Verification Steps:**
```bash
# Test Loki data source connectivity
kubectl run test-loki-ds --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
  curl -s "http://loki-stack.loki-stack.svc.cluster.local:3100/loki/api/v1/query?query={app=\"rocketchat\"}&limit=5"

# Check Grafana data source API
kubectl run test-grafana-ds --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
  sh -c 'curl -s -u admin:prom-operator http://monitoring-grafana:80/api/datasources | jq length'
# Should return: 3 (Prometheus, Alertmanager, Loki)
```

**Prevention Measures:**
- **Correct Labels**: Always use `grafana_dashboard: "1"` for both data sources and dashboards in kube-prometheus-stack
- **Label Consistency**: Verify sidecar configuration matches ConfigMap labels:
  ```bash
  kubectl describe deployment monitoring-grafana | grep "LABEL:"
  ```
- **Pre-deployment Testing**: Test ConfigMap mounting before full deployment:
  ```bash
  kubectl get configmap -n monitoring -l grafana_dashboard=1
  ```
- **Authentication Management**: Monitor Grafana authentication failures:
  ```bash
  kubectl logs -n monitoring deployment/grafana | grep "password-auth.failed"
  ```
- **Data Source Validation**: Always verify data source connectivity:
  ```bash
  kubectl run test-ds --image=curlimages/curl --rm -i --restart=Never --namespace monitoring -- \
    curl -s http://<datasource-url>/api/v1/status/buildinfo
  ```

**Configuration Reference:**
```yaml
# Correct ConfigMap structure for kube-prometheus-stack
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # ✅ Required for sidecar mounting
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      uid: loki  # ✅ Use consistent UID
      url: http://loki-stack.loki-stack.svc.cluster.local:3100
      access: proxy
      jsonData:
        maxLines: 1000
```

**Expected Resolution Time:** 2-3 minutes after fix application

**Post-Resolution Testing:**
- ✅ Grafana Explore shows Loki data source
- ✅ Loki queries return data successfully
- ✅ Console errors eliminated
- ✅ Data source health checks pass (200 OK)

**Status:** ✅ **RESOLVED** - Grafana Loki data source now properly configured and functional

---

### **Issue: Promtail Position File Write Errors (September 6, 2025)** ⭐ **Recently Resolved**

**Symptoms:**
- Promtail logs showing: `error writing positions file" error="open /tmp/.positions.yaml...: read-only file system"`
- Promtail pods running but unable to track log positions
- Log collection working but position tracking failing
- Potential log duplication on pod restarts

**Diagnosis:**
```bash
# Check Promtail logs
kubectl logs -n loki-stack -l app.kubernetes.io/name=promtail --tail=10
# Shows: read-only file system errors for /tmp/.positions.yaml

# Verify volume mounts
kubectl get deployment loki-stack-promtail -n loki-stack -o yaml | grep -A 10 "volumes:"
# Shows: emptyDir mount at /tmp (read-only in some environments)

# Check Promtail configuration
kubectl get configmap loki-stack-promtail -n loki-stack -o yaml | grep positions
# Shows: filename: /tmp/positions.yaml
```

**Root Cause:**
- Promtail configured to write position files to `/tmp` directory
- `/tmp` mounted as read-only emptyDir in Kubernetes environment
- Position tracking requires writable storage for persistence

**Solutions Applied:**

**Option A: Update Promtail Configuration**
```yaml
# Update monitoring/loki-values.yaml
promtail:
  config:
    positions:
      filename: /run/promtail/positions.yaml  # ✅ Changed from /tmp
```

**Option B: Volume Mount Configuration**
```yaml
# Ensure Promtail has writable directory
promtail:
  extraVolumeMounts:
  - name: positions
    mountPath: /run/promtail
    readOnly: false
  extraVolumes:
  - name: positions
    emptyDir: {}
```

**Prevention:**
- Use `/run` or `/var/run` directories for temporary writable files
- Avoid `/tmp` for persistent state in Kubernetes
- Test volume mounts before production deployment

**Status:** ✅ **RESOLVED** - Promtail position tracking now working correctly

---

**Phase 2 Enhanced Monitoring (Loki)**: ✅ **FULLY OPERATIONAL**
**Documentation Updated**: September 6, 2025
**Grafana Loki Integration**: ✅ **SUCCESSFUL**
**Log Collection**: ✅ **WORKING**
**Dashboard Visualization**: ✅ **FUNCTIONAL**

*Phase 2 Loki Stack deployment and Grafana integration now complete. All data source configuration issues resolved.*

---

## 🚀 **Repository Cleanup and Organization - COMPLETED** ⭐ **September 6, 2025**

### **Major Repository Reorganization**

**Issue Context:**
The repository had accumulated 25+ files scattered in the root directory including various scripts, configuration files, and documentation without clear organization. This made navigation difficult and maintenance challenging.

**Reorganization Results:**

**✅ New Directory Structure:**
```
c:\Users\i\rocketchat-k8s-deployment\
├── config/
│   ├── certificates/         # SSL/TLS certificate configurations
│   │   └── clusterissuer.yaml
│   └── helm-values/         # Centralized Helm chart values
│       ├── values-monitoring.yaml
│       ├── values-official.yaml
│       ├── values-production.yaml
│       └── values.yaml
├── deployment/              # Deployment scripts and guides
│   ├── cleanup-aks.sh
│   ├── deploy-aks-official.sh
│   ├── deploy-rocketchat.sh
│   └── README.md           # Step-by-step deployment guide
├── docs/                   # Comprehensive documentation
│   ├── DNS_MIGRATION_GUIDE.md
│   ├── ENHANCED_MONITORING_PLAN.md
│   ├── FUTURE_IMPROVEMENTS.md
│   ├── PROJECT_HISTORY.md
│   ├── PROJECT_STATUS.md
│   ├── README.md
│   └── TROUBLESHOOTING_GUIDE.md
├── monitoring/             # Monitoring configurations
│   ├── grafana-datasource-loki.yaml
│   ├── grafana-dashboard-rocketchat.yaml
│   ├── loki-values.yaml
│   ├── prometheus-current.yaml
│   ├── rocket-chat-alerts.yaml
│   └── [other monitoring configs]
└── scripts/               # Utility scripts
    ├── aks-shell.sh
    ├── migrate-to-aks.sh
    └── setup-kubeconfig.sh
```

**✅ Files Organized:**
- **Moved to config/certificates/**: `clusterissuer.yaml`
- **Moved to config/helm-values/**: All `values-*.yaml` files
- **Moved to deployment/**: All deployment scripts
- **Moved to monitoring/**: All monitoring-related configurations
- **Moved to scripts/**: Utility and setup scripts

**✅ Files Removed (9+ unnecessary files):**
- `apply-observability-fixes.sh` - Temporary fix script no longer needed
- `monitoring-ingress-backup.yaml` - Old backup file
- Various PowerShell scripts - Not used in current deployment
- Duplicate configuration files - Consolidated versions kept

**✅ New Documentation:**
- **STRUCTURE.md**: Complete directory layout documentation
- **CLEANUP_SUMMARY.md**: Record of all reorganization activities
- **deployment/README.md**: Step-by-step deployment guide
- **Updated main README.md**: Reflects new structure and current status

**Path Updates Required:**

**Deployment Scripts Updated:**
```bash
# OLD PATH: ./values-official.yaml
# NEW PATH: ./config/helm-values/values-official.yaml

# Updated in deploy-aks-official.sh:
helm install rocketchat rocketchat/rocketchat \
  -f ./config/helm-values/values-official.yaml \  # ✅ Updated path
  --namespace rocketchat --create-namespace
```

**Configuration References Updated:**
```yaml
# Monitoring configurations now reference correct paths
# All helm values centralized in config/helm-values/
# Certificate configurations in config/certificates/
```

**Quick Reference - New File Locations:**

| **Old Location** | **New Location** | **Purpose** |
|------------------|------------------|-------------|
| `./values-official.yaml` | `./config/helm-values/values-official.yaml` | Main Rocket.Chat Helm values |
| `./values-monitoring.yaml` | `./config/helm-values/values-monitoring.yaml` | Monitoring stack values |
| `./clusterissuer.yaml` | `./config/certificates/clusterissuer.yaml` | SSL certificate issuer |
| `./grafana-dashboard-rocketchat.yaml` | `./monitoring/grafana-dashboard-rocketchat.yaml` | Grafana dashboard |
| `./deploy-aks-official.sh` | `./deployment/deploy-aks-official.sh` | Main deployment script |

**Benefits Achieved:**
- ✅ **Clear Navigation**: Logical directory structure with purpose-specific folders
- ✅ **Easier Maintenance**: Related files grouped together
- ✅ **Better Documentation**: Comprehensive guides in dedicated docs/ folder
- ✅ **Simplified Root**: Root directory clean with only essential top-level files
- ✅ **Version Control**: Better tracking of changes with organized structure
- ✅ **Onboarding**: New team members can quickly understand project layout

**Migration Commands for Users:**
```bash
# If you have local scripts/aliases that reference old paths:

# UPDATE THESE PATHS:
# OLD: ./values-official.yaml
# NEW: ./config/helm-values/values-official.yaml

# OLD: ./deploy-aks-official.sh
# NEW: ./deployment/deploy-aks-official.sh

# OLD: ./grafana-dashboard-rocketchat.yaml
# NEW: ./monitoring/grafana-dashboard-rocketchat.yaml
```

**Verification:**
```bash
# Verify new structure
ls -la  # Should show only 10 organized directories + README/docs

# Check deployment script paths
cat deployment/deploy-aks-official.sh | grep "values-"
# Should show: config/helm-values/values-official.yaml

# Verify all configs present
find . -name "*.yaml" | wc -l
# Should match previous count (all files preserved, just organized)
```

**Status:** ✅ **COMPLETED** - Repository successfully reorganized and cleaned up
**Documentation:** ✅ **UPDATED** - All guides reflect new structure
**Deployment Scripts:** ✅ **UPDATED** - All paths corrected
**Validation:** ✅ **VERIFIED** - All functionality preserved with improved organization

---

**Repository Organization**: ✅ **PROFESSIONALLY STRUCTURED**
**File Management**: ✅ **OPTIMIZED**
**Documentation**: ✅ **COMPREHENSIVE**
**Maintenance**: ✅ **SIMPLIFIED**

*Repository cleanup and reorganization completed September 6, 2025. Project now has professional directory structure with clear separation of concerns and comprehensive documentation.*

## AKS: PodMonitor/ServiceMonitor disappear or Prometheus not scraping

Symptoms:
- `kubectl get podmonitors -A` shows none or they appear/disappear
- Prometheus `podMonitorSelector` / `serviceMonitorSelector` require `release: monitoring`
- Helm upgrade fails with "invalid ownership metadata" for PodMonitors

Fix:
1) Confirm Prometheus selectors and namespaces
```bash
kubectl -n monitoring get prometheus monitoring-kube-prometheus-prometheus -o yaml | \
  grep -E "(podMonitorSelector|serviceMonitorSelector|NamespaceSelector)" -A3
```
Should allow namespaces `monitoring` and `rocketchat`, and either match `release: monitoring` or `{}`.

2) Adopt PodMonitors into Helm (prevents pruning and ownership errors)
```bash
kubectl apply -f aks/monitoring/rocketchat-podmonitor.yaml
for n in rocketchat-metrics rocketchat-microservices mongodb-metrics; do
  kubectl -n monitoring annotate podmonitor.monitoring.coreos.com $n \
    meta.helm.sh/release-name=monitoring \
    meta.helm.sh/release-namespace=monitoring --overwrite=true
  kubectl -n monitoring label podmonitor.monitoring.coreos.com $n \
    app.kubernetes.io/managed-by=Helm --overwrite=true
done
kubectl get podmonitor.monitoring.coreos.com -n monitoring -L app.kubernetes.io/managed-by
```

3) If Grafana ingress conflicts, disable it during install/upgrade
```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f aks/config/helm-values/monitoring-values.yaml \
  --set grafana.ingress.enabled=false --wait --timeout 5m
```

4) Verify targets (use alternate local port if 9090 busy)
```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9091:9090
# Visit http://localhost:9091/targets → Rocket.Chat 9458, microservices 9459 should be UP
```

Notes:
- Standardize on `monitoring.coreos.com/v1` CRDs; avoid mixing with `azmonitoring.coreos.com/v1` for the same resources.
- In `aks/config/helm-values/monitoring-values.yaml`, define PodMonitors under `prometheus.additionalPodMonitors` with a `spec:` block so Helm renders them natively.

---

## 🐛 **ReadWriteOnce Multi-Attach Issue (September 21, 2025)**

### **Issue: Rocket.Chat Pod Stuck in ContainerCreating - ReadWriteOnce Multi-Attach**

**Date Added:** September 21, 2025

**Symptoms:**
- One Rocket.Chat pod runs successfully while another is stuck in `ContainerCreating` status for hours
- Pod description shows it's scheduled but container never starts
- `kubectl get pods` shows one pod `Running` and another `0/1 ContainerCreating`
- Both pods trying to use the same PersistentVolumeClaim (PVC)
- PVC has `ReadWriteOnce` access mode
- Pods scheduled on different nodes
- No recent events visible (events may have expired after hours)

**Example Output:**
```bash
$ kubectl get pods -n rocketchat | grep rocketchat-9f5d5c7f6
rocketchat-rocketchat-9f5d5c7f6-bdzdc      1/1     Running             3 (41h ago)     41h
rocketchat-rocketchat-9f5d5c7f6-sbrzv      0/1     ContainerCreating   0               10h

$ kubectl describe pvc rocketchat-rocketchat -n rocketchat
Access Modes:  RWO
Used By:       rocketchat-rocketchat-9f5d5c7f6-bdzdc
               rocketchat-rocketchat-9f5d5c7f6-sbrzv
```

**Root Cause:**
- Deployment configured for multiple replicas (e.g., `replicas: 2`) but using ReadWriteOnce storage
- ReadWriteOnce PVCs can only be mounted by pods on the same node
- Kubernetes scheduler placed pods on different nodes, causing volume attachment conflict
- First pod successfully attached the PVC, second pod cannot mount the same volume from different node

**Solutions:**

**Option A: Scale to Single Replica (Recommended)**
```bash
# Scale deployment to 1 replica
kubectl scale deployment rocketchat-rocketchat -n rocketchat --replicas=1

# Verify fix
kubectl get pods -n rocketchat | grep rocketchat
```

**Option B: Delete Stuck Pod (Temporary)**
```bash
# Delete the stuck pod (will be rescheduled, possibly on same node)
kubectl delete pod <stuck-pod-name> -n rocketchat

# Monitor for rescheduling
kubectl get pods -n rocketchat -w
```

**Option C: Change Storage Class (Advanced)**
```bash
# Check available storage classes with ReadWriteMany support
kubectl get storageclass

# Update Helm values to use ReadWriteMany storage (if supported)
# This requires recreating the PVC and may cause data loss
```

**Prevention:**
- For applications requiring persistent storage, use single replica with ReadWriteOnce
- Use ReadWriteMany storage classes if multiple replicas are needed
- Monitor deployment replica count vs. storage access modes
- Consider StatefulSets for applications requiring persistent storage per replica

**Expected Resolution Time:** Immediate (seconds) after scaling to 1 replica

**Advanced Troubleshooting:**
```bash
# Check deployment replica configuration
kubectl get deployment rocketchat-rocketchat -n rocketchat -o jsonpath='{.spec.replicas}'

# Verify PVC access mode
kubectl get pvc rocketchat-rocketchat -n rocketchat -o jsonpath='{.spec.accessModes[0]}'

# Check which nodes pods are scheduled on
kubectl get pods -n rocketchat -o wide | grep rocketchat-9f5d5c7f6

# Inspect volume attachments
kubectl get volumeattachments.storage.k8s.io | grep $(kubectl get pvc rocketchat-rocketchat -n rocketchat -o jsonpath='{.spec.volumeName}')
```

**Success Indicators:**
- ✅ Only one Rocket.Chat pod remains in `Running` status
- ✅ No pods stuck in `ContainerCreating` 
- ✅ Rocket.Chat accessible at configured URL
- ✅ Application functions normally with single replica

**Related Issues:**
- **PVC Terminating Deadlock**: Can occur when trying to delete PVCs while pods are using them
- **Multi-Attach Errors in Grafana**: Similar RWO issues during rolling updates
- **MongoDB Replica Set Issues**: Also uses RWO storage, same principles apply

---

## Issue 8.7: Comprehensive Rocket.Chat Dashboard Implementation (RESOLVED - January 2025)

### Problem Description
The basic dashboard was missing comprehensive monitoring capabilities and didn't follow Rocket.Chat monitoring best practices. Need for a complete observability solution with all available metrics and log integration.

### Root Cause Analysis
- **Limited Metrics Coverage**: Basic dashboard only showed basic pod status and CPU/memory
- **Missing Business Metrics**: No user engagement, message statistics, or performance indicators
- **Incomplete Log Integration**: Loki logs not properly integrated into dashboard
- **No Official Dashboard Integration**: Not using Rocket.Chat's official monitoring dashboards

### Solution Implemented

#### 1. **Comprehensive Dashboard Creation**
Created `rocketchat-dashboard-comprehensive.json` with 28 panels covering:

**User Engagement Metrics:**
- Active Users (real-time count)
- Total Users (cumulative)
- User Status Distribution (Online/Away/Offline)
- Messages per Second (rate)

**Performance Metrics:**
- API Response Time (average + 95th percentile)
- API Request Rate (requests/second)
- DDP Sessions (total + authenticated)
- Meteor Methods Performance (execution time + rate)

**Business Metrics:**
- Message Types Distribution (channels, direct, private groups, livechat)
- Room Statistics (channels, private groups, direct messages, livechat)
- Livechat Performance (agents, visitors, webhook success/failures)
- Apps & Integrations (installed, enabled, failed, hooks)

**Infrastructure Metrics:**
- CPU Usage by Pod
- Memory Usage by Pod
- Pod Status and Restarts
- MongoDB Status

**Log Integration (Loki):**
- Rocket.Chat Application Logs (full-width log viewer)
- Error Logs (filtered for errors, exceptions, failures)
- MongoDB Logs (database-specific logs)
- Log Volume by Service (timeseries)
- Log Level Distribution (debug, info, warn, error, fatal)
- Recent Alerts & Warnings (filtered alert logs)
- Performance Logs (slow queries, timeouts, latency issues)

#### 2. **Official Dashboard Integration**
Updated monitoring values to include Rocket.Chat's official dashboards:

```yaml
grafana:
  dashboards:
    rocketchat:
      - name: "rocketchat-metrics"
        folder: "rocketchat"
        id: "23428"
        revision: latest
      - name: "rocketchat-microservices"
        folder: "rocketchat"
        id: "23427"
        revision: latest
```

#### 3. **Available Rocket.Chat Metrics**
Verified 50+ available metrics including:
- `rocketchat_users_*` (active, total, online, away, offline)
- `rocketchat_messages_*` (total, channel, direct, private_group, livechat)
- `rocketchat_rest_api_*` (count, sum for response time calculation)
- `rocketchat_ddp_*` (connected_users, sessions_count, sessions_auth)
- `rocketchat_meteor_methods_*` (count, sum for performance)
- `rocketchat_livechat_*` (agents, visitors, webhooks, messages)
- `rocketchat_apps_*` (installed, enabled, failed)
- `rocketchat_*_total` (channels, rooms, notifications, etc.)

### Implementation Steps

#### 1. **Deploy Comprehensive Dashboard**
```bash
# Apply the comprehensive dashboard
kubectl create configmap rocket-chat-dashboard-comprehensive \
  --from-file=rocket-chat-dashboard-comprehensive.json=aks/monitoring/rocketchat-dashboard-comprehensive.json \
  -n monitoring

# Label for Grafana auto-import
kubectl label configmap rocket-chat-dashboard-comprehensive grafana_dashboard=1 -n monitoring
```

#### 2. **Update Monitoring Values**
```bash
# Update monitoring values to include official dashboards
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -f aks/config/helm-values/monitoring-values.yaml \
  -n monitoring
```

#### 3. **Verify Dashboard Access**
```bash
# Check dashboard is imported
kubectl get configmap -n monitoring | grep dashboard

# Access Grafana
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Navigate to: http://localhost:3000
# Look for "Rocket.Chat Comprehensive Production Monitoring"
```

### Dashboard Features

#### **Real-time Monitoring**
- **Uptime SLO**: 99%+ uptime tracking with color-coded thresholds
- **Active Users**: Live count of currently active users
- **Messages/sec**: Real-time message throughput
- **API Performance**: Response times and request rates

#### **Business Intelligence**
- **User Engagement**: Online/away/offline distribution over time
- **Message Analytics**: Breakdown by channel type (public, private, direct, livechat)
- **Room Statistics**: Total channels, private groups, direct messages
- **Livechat Metrics**: Agent count, visitor count, webhook performance

#### **Performance Monitoring**
- **DDP Sessions**: WebSocket connection monitoring
- **Meteor Methods**: Server-side method execution performance
- **API Response Times**: Average and 95th percentile response times
- **Infrastructure Health**: CPU, memory, pod status, restarts

#### **Log Analysis**
- **Application Logs**: Full Rocket.Chat application logs with filtering
- **Error Tracking**: Automated error log filtering and display
- **Performance Logs**: Slow queries, timeouts, and performance issues
- **Log Volume**: Log ingestion rates by service
- **Log Levels**: Distribution of debug, info, warn, error, fatal logs

### Verification Steps

#### 1. **Dashboard Functionality**
```bash
# Check all panels are loading data
# Navigate to Grafana dashboard
# Verify each panel shows data (not "No data")
# Check log panels show recent logs
```

#### 2. **Metrics Validation**
```bash
# Verify Rocket.Chat metrics are being collected
kubectl exec -n monitoring deployment/monitoring-grafana -- \
  curl -s "http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/label/__name__/values" | \
  jq -r '.data[]' | grep rocketchat | wc -l
# Should show 50+ metrics
```

#### 3. **Log Integration**
```bash
# Check Loki is receiving logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=10 | grep rocketchat

# Verify log queries work
# In Grafana, go to Explore → Loki
# Query: {namespace="rocketchat"}
# Should return recent logs
```

### Best Practices Implemented

#### **Dashboard Design**
- **3-Column Layout**: Optimized for different screen sizes
- **Color Coding**: Consistent color scheme for different metric types
- **Time Ranges**: Appropriate time ranges for different metrics
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

### Prevention Tips

#### **Regular Maintenance**
- **Dashboard Updates**: Keep dashboard queries updated with new metrics
- **Log Retention**: Monitor Loki storage usage and retention policies
- **Performance Tuning**: Adjust refresh rates based on system load
- **User Training**: Train team on dashboard navigation and log analysis

#### **Monitoring Best Practices**
- **Baseline Establishment**: Document normal operating ranges
- **Alert Thresholds**: Set appropriate alert thresholds based on baselines
- **Log Analysis**: Regular review of error and performance logs
- **Capacity Planning**: Use historical data for resource planning

### Related Documentation
- **Official Rocket.Chat Monitoring**: [Rocket.Chat Monitoring Guide](https://docs.rocket.chat/docs/monitoring)
- **Grafana Dashboard Management**: [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- **Loki Log Queries**: [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- **Prometheus Metrics**: [Prometheus Querying](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

## Issue 8.8: Comprehensive Dashboard Not Appearing in Grafana (IN PROGRESS - January 2025)

### Problem Description
The comprehensive dashboard "Rocket Chat Comprehensive Production Monitoring" was created and ConfigMap updated, but it's not appearing in the Grafana dashboard list after restart.

### Current Status
- ✅ **Dashboard JSON Created**: `rocketchat-dashboard-comprehensive.json` with 28 panels
- ✅ **ConfigMap Updated**: `rocket-chat-dashboard-comprehensive` with correct label
- ✅ **Grafana Restarted**: Deployment restarted successfully
- ❌ **Dashboard Missing**: Not visible in Grafana dashboard list
- ✅ **Other Dashboards Working**: Standard Kubernetes dashboards visible

### Investigation Steps

#### 1. **Check Dashboard Sidecar Processing**
```bash
# Get current Grafana pod
kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana"

# Check dashboard sidecar logs
kubectl logs -n monitoring <grafana-pod> -c grafana-sc-dashboard --tail=20

# Look for processing of rocket-chat-dashboard-comprehensive.json
kubectl logs -n monitoring <grafana-pod> -c grafana-sc-dashboard | grep -i "rocket-chat-dashboard-comprehensive"
```

#### 2. **Verify ConfigMap Status**
```bash
# Check ConfigMap exists and is labeled correctly
kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring -o yaml

# Verify label is present
kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring --show-labels
```

#### 3. **Check Dashboard Files in Container**
```bash
# List all dashboard files being processed
kubectl exec -n monitoring <grafana-pod> -c grafana-sc-dashboard -- ls -la /tmp/dashboards/

# Check if our dashboard file exists
kubectl exec -n monitoring <grafana-pod> -c grafana-sc-dashboard -- ls -la /tmp/dashboards/ | grep rocket
```

#### 4. **Check for UID Conflicts**
```bash
# Check Grafana main container logs for UID conflicts
kubectl logs -n monitoring <grafana-pod> -c grafana --tail=20 | grep -i "uid\|dashboard"
```

### Potential Root Causes

#### **Dashboard Sidecar Not Processing**
- ConfigMap not being watched by sidecar
- Label mismatch preventing detection
- Sidecar container not running properly

#### **UID Conflicts**
- Dashboard UID `rocketchat-comprehensive` conflicts with existing dashboard
- Multiple dashboards with same UID causing import failure

#### **JSON Format Issues**
- Invalid JSON in dashboard file
- Missing required fields in dashboard definition
- Grafana version compatibility issues

### Troubleshooting Commands

#### **Force Dashboard Reload**
```bash
# Restart dashboard sidecar specifically
kubectl delete pod <grafana-pod> -n monitoring

# Or restart entire Grafana deployment
kubectl rollout restart deployment/monitoring-grafana -n monitoring
```

#### **Manual Dashboard Import Test**
```bash
# Test dashboard JSON validity
kubectl exec -n monitoring <grafana-pod> -c grafana -- curl -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/dashboards/rocket-chat-dashboard-comprehensive.json \
  http://localhost:3000/api/dashboards/db
```

#### **Check Dashboard UIDs**
```bash
# List all existing dashboard UIDs
kubectl exec -n monitoring <grafana-pod> -c grafana -- curl -s \
  http://localhost:3000/api/search?type=dash-db | jq -r '.[].uid'
```

### Expected Resolution
The comprehensive dashboard should appear in the Grafana dashboard list with:
- **Title**: "Rocket Chat Comprehensive Production Monitoring"
- **UID**: `rocketchat-comprehensive`
- **28 Panels**: Including the new "Total Rocket.Chat Pods" panel
- **All Metrics Working**: CPU, memory, logs, user metrics

### Next Steps
1. **Investigate sidecar processing** - Check if ConfigMap is being detected
2. **Verify UID uniqueness** - Ensure no conflicts with existing dashboards
3. **Test manual import** - If sidecar fails, try manual import
4. **Update dashboard UID** - If conflicts exist, change UID and redeploy

---