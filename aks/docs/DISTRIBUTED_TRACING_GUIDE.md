# 🚀 Distributed Tracing Implementation Guide

## Overview

This guide implements **distributed tracing** for your Rocket.Chat AKS deployment, completing your observability stack with **Metrics + Logs + Traces**.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Rocket.Chat   │───▶│ OpenTelemetry    │───▶│   Grafana       │
│   (Traced)      │    │   Collector      │    │   Tempo         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Grafana        │
                       │   (Visualization)│
                       └──────────────────┘
```

## Components

### 1. **Grafana Tempo** - Distributed Tracing Backend
- **Purpose**: Stores and queries distributed traces
- **Features**: High-performance trace storage, OTLP support, Grafana integration
- **Resources**: 500m CPU, 1Gi memory, 20Gi storage

### 2. **OpenTelemetry Collector** - Trace Collection
- **Purpose**: Collects traces from Rocket.Chat and forwards to Tempo
- **Protocols**: OTLP, Jaeger, Zipkin, OpenCensus
- **Features**: Batch processing, resource attribution, filtering

### 3. **Rocket.Chat Instrumentation** - Trace Generation
- **Method**: OpenTelemetry auto-instrumentation
- **Coverage**: HTTP requests, database queries, internal operations
- **Integration**: Seamless with existing Rocket.Chat deployment

## Deployment

### Quick Start

```bash
# Ensure KUBECONFIG is set (auto-detected for WSL/Windows)
export KUBECONFIG=/mnt/c/Users/i/.kube/config  # Adjust path if needed

# Deploy the complete tracing stack
./aks/scripts/deploy-tracing-stack.sh
```

### Manual Deployment

```bash
# 1. Deploy Tempo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install tempo grafana/tempo \
  -f aks/monitoring/tempo-values.yaml \
  --namespace monitoring \
  --create-namespace \
  --wait

# 2. Deploy OpenTelemetry Collector
kubectl apply -f aks/monitoring/opentelemetry-collector.yaml

# 3. Configure Grafana datasource
kubectl apply -f aks/monitoring/grafana-tempo-datasource.yaml

# 4. Deploy tracing dashboard
kubectl apply -f aks/monitoring/grafana-tracing-dashboard.yaml

# 5. Restart Grafana to pick up datasource
kubectl rollout restart deployment monitoring-grafana -n monitoring

# 6. Instrument Rocket.Chat (requires patch)
kubectl apply -f aks/monitoring/rocketchat-otel-config.yaml
kubectl patch deployment rocketchat-rocketchat -n rocketchat \
  --patch-file aks/monitoring/rocketchat-otel-patch.yaml
```

## Configuration Files

### Tempo Configuration (`tempo-values.yaml`)
- **Storage**: Uses emptyDir (local storage, no persistence configured)
- **Version**: Tempo 2.3.0 (via Helm chart)
- **Receivers**: OTLP (gRPC/HTTP), Jaeger, Zipkin protocols
- **Resources**: 500m CPU, 1Gi memory (cost-optimized)
- **Security**: Running as root (UID 0) for directory creation permissions
- **URL**: `http://tempo.monitoring.svc.cluster.local:3200`

### OpenTelemetry Collector (`opentelemetry-collector.yaml`)
- **Image**: `otel/opentelemetry-collector-contrib:0.88.0`
- **Receivers**: OTLP (gRPC:4317, HTTP:4318), Jaeger, Zipkin
- **Processors**: 
  - Memory limiter (512MiB limit, 1s check interval)
  - Batch processing (1s timeout, 1024 batch size)
  - Resource attribution
- **Exporters**: Tempo (OTLP), Prometheus metrics, logging
- **Health Check**: Port 13133 (enabled via extensions)
- **Resources**: 500m CPU, 1Gi memory

### Rocket.Chat Instrumentation (`rocketchat-otel-patch.yaml`)
- **Method**: OpenTelemetry auto-instrumentation via init container
- **Init Container**: Installs OpenTelemetry packages to shared volume
- **Auto-instrumentation**: HTTP, Express, MongoDB, DNS (disabled)
- **OTLP Endpoint**: `http://otel-collector.monitoring.svc.cluster.local:4318`
- **Resource Attributes**: Set via environment variables (OTEL_RESOURCE_ATTRIBUTES)
- **Configuration**: `rocketchat-otel-config.yaml` ConfigMap

## Grafana Integration

### Data Source Configuration
- **Tempo**: Primary tracing backend
- **Traces to Logs**: Correlate traces with Loki logs
- **Traces to Metrics**: Correlate traces with Prometheus metrics
- **Service Map**: Visualize service dependencies

### Dashboard Features
- **Trace Search**: Find traces by service, operation, duration
- **Trace Search (All Services)**: View all traces with empty query `{}`
- **Rocket.Chat Traces**: Filtered view for `{ resource.service.name = "rocket-chat" }`
- **Access URL**: `https://grafana.canepro.me/d/rocket-chat-tracing`

### Data Source Configuration
- **Tempo URL**: `http://tempo.monitoring.svc.cluster.local:3200`
- **UID**: `tempo`
- **Correlation**: 
  - Traces to Logs (Loki UID: `loki`)
  - Traces to Metrics (Prometheus UID: `prometheus`)

## Key Benefits

### 🔍 **Request Tracing**
- **End-to-end visibility** across Rocket.Chat microservices
- **Request flow mapping** from user action to database query
- **Performance bottleneck identification** at service level

### 🐛 **Error Debugging**
- **Error correlation** between services
- **Root cause analysis** across distributed systems
- **Context propagation** for debugging complex issues

### 📊 **Performance Monitoring**
- **Latency analysis** by service and operation
- **Throughput monitoring** across service boundaries
- **Resource utilization** correlation with traces

### 🎯 **Operational Excellence**
- **SLA monitoring** with trace-based metrics
- **Capacity planning** based on trace patterns
- **Incident response** with complete request context

## Monitoring Integration

### Prometheus Integration
- **Trace metrics**: Request rates, error rates, latency
- **Service metrics**: Health checks, resource usage
- **Custom metrics**: Business logic instrumentation

### Loki Integration
- **Trace correlation**: Link traces with log entries
- **Context enrichment**: Add trace context to logs
- **Error investigation**: Correlate errors with traces

### Alerting
- **High error rates**: Alert on trace error percentages
- **Latency spikes**: Alert on trace duration anomalies
- **Service degradation**: Alert on trace success rates

## Cost Optimization

### Resource Allocation
- **Tempo**: 500m CPU, 1Gi memory (cost-optimized)
- **Collector**: 500m CPU, 1Gi memory (efficient processing)
- **Storage**: 20Gi for 7-day trace retention

### Sampling Strategy
- **Head-based sampling**: Sample traces at collection time
- **Tail-based sampling**: Sample based on trace characteristics
- **Rate limiting**: Control trace volume for cost management

## Troubleshooting

### Common Issues

#### Traces Not Appearing
```bash
# Check Tempo connectivity
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo

# Check OpenTelemetry Collector
kubectl logs -n monitoring -l app=otel-collector

# Check Rocket.Chat instrumentation
kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat | grep -i "opentelemetry"

# Verify OpenTelemetry is initialized
kubectl logs -n rocketchat -l app.kubernetes.io/name=rocketchat | head -10
# Should see: "[OpenTelemetry] Auto-instrumentation started successfully! ✅"

# Generate test traffic to create traces
# Visit https://chat.canepro.me and navigate around
```

#### OpenTelemetry Collector Issues

**Issue: "checkInterval must be greater than zero"**
```bash
# Fix: Ensure memory_limiter processor has check_interval
# Check config in opentelemetry-collector.yaml
kubectl get configmap otel-collector-config -n monitoring -o yaml | grep check_interval
# Should show: check_interval: 1s
```

**Issue: "GOMEMLIMIT malformed"**
```bash
# Fix: Use "512MiB" format (not "512Mi")
# Check environment variable
kubectl get deployment otel-collector -n monitoring -o yaml | grep GOMEMLIMIT
```

**Issue: Health check failing**
```bash
# Ensure extensions section includes health_check
kubectl get configmap otel-collector-config -n monitoring -o yaml | grep health_check
```

#### Rocket.Chat Instrumentation Issues

**Issue: "Resource is not a constructor"**
```bash
# Fix: Remove Resource import, use environment variables instead
# The updated rocketchat-otel-config.yaml should not use Resource
kubectl exec -n rocketchat <pod-name> -- cat /otel-auto-instrumentation/tracing.js | head -20
# Should NOT see: new Resource({...})
```

**Issue: Init container npm permission errors**
```bash
# Fix: Set npm cache to writable directory
# Ensure init container sets: export npm_config_cache=/otel-temp/.npm
kubectl logs -n rocketchat <pod-name> -c otel-instrumentation
```

**Issue: Read-only filesystem when mounting ConfigMap**
```bash
# Fix: Copy ConfigMap file during init instead of mounting directly
# The init container should copy tracing.js to the emptyDir volume
```

#### Grafana Integration Issues

**Issue: "empty ring" error in Grafana TraceQL queries**
```bash
# This error occurs when using TraceQL metrics queries
# Use simple trace search queries instead:
# - {} (all traces)
# - { resource.service.name = "rocket-chat" }

# Check Tempo datasource configuration
kubectl get configmap grafana-tempo-datasource -n monitoring -o yaml

# Restart Grafana to pick up datasource
kubectl rollout restart deployment monitoring-grafana -n monitoring
```

**Issue: Datasource not appearing in Grafana**
```bash
# Check ConfigMap labels
kubectl get configmap grafana-tempo-datasource -n monitoring --show-labels
# Should have: grafana_datasource: "1"

# Restart Grafana
kubectl rollout restart deployment monitoring-grafana -n monitoring

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i "tempo\|datasource"
```

#### Performance Issues
```bash
# Check resource usage
kubectl top pods -n monitoring

# Check Tempo storage usage
kubectl exec -n monitoring tempo-0 -- df -h /var/tempo

# Check OpenTelemetry Collector metrics
kubectl port-forward -n monitoring svc/otel-collector 8888:8888
# Then visit: http://localhost:8888/metrics
```

#### KUBECONFIG Issues (WSL/Windows)
```bash
# Auto-detected by deploy script, but manual setup:
export KUBECONFIG=/mnt/c/Users/i/.kube/config

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

## Advanced Configuration

### Custom Instrumentation
```javascript
// Add custom spans to Rocket.Chat
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('rocket-chat-custom');

// Custom span for business logic
const span = tracer.startSpan('user-message-processing');
span.setAttributes({
  'user.id': userId,
  'message.type': messageType,
  'channel.id': channelId
});
// ... business logic ...
span.end();
```

### Sampling Configuration
```yaml
# Adjust sampling rates in OpenTelemetry Collector
processors:
  probabilistic_sampler:
    sampling_percentage: 10.0  # 10% sampling rate
```

### Retention Policies
```yaml
# Configure trace retention in Tempo
overrides:
  defaults:
    max_traces_per_user: 10000
    max_bytes_per_trace: 5000000
```

## Production Considerations

### Security
- **Network policies**: Restrict trace data flow
- **RBAC**: Limit access to trace data
- **Encryption**: Secure trace data in transit and at rest

### Scalability
- **Horizontal scaling**: Multiple Tempo instances
- **Storage optimization**: Compress trace data
- **Load balancing**: Distribute trace collection

### Monitoring
- **Trace volume**: Monitor trace ingestion rates
- **Storage usage**: Monitor trace storage consumption
- **Performance**: Monitor trace query performance

## Current Status (October 30, 2025)

### ✅ **Fully Operational - All Issues Resolved**
- **Tempo**: Running with metrics-generator enabled (1.8MB traces, 124KB metrics)
- **OpenTelemetry Collector**: Running and processing traces successfully
- **Grafana Tempo Datasource**: Configured and available
- **Tracing Dashboard**: Deployed (`rocket-chat-tracing`)
- **Rocket.Chat Instrumentation**: Active and exporting traces correctly
- **Trace Pipeline**: End-to-end verified and working
- **Metrics Generation**: Service graphs and span metrics operational

### 📊 **Access Points**
- **Grafana URL**: `https://grafana.canepro.me`
- **Tracing Dashboard**: `https://grafana.canepro.me/d/rocket-chat-tracing`
- **Explore (Tempo)**: `https://grafana.canepro.me/explore` → Select "Tempo" datasource

### 🔍 **Trace Queries**
```traceql
# All traces
{}

# Rocket.Chat traces
{ resource.service.name = "rocket-chat" }

# By service name
{ service.name = "rocket-chat" }
```

### 📝 **TraceQL Metrics - NOW WORKING**
TraceQL metric queries (`rate()`, `histogram_over_time()`) are now fully operational with the metrics-generator enabled. Span metrics and service graphs are being generated automatically from traces.

## Investigation & Fixes (October 30, 2025)

### Issues Resolved
1. **✅ Traces not exporting**: Fixed deprecated OpenTelemetry exporter package
   - Changed from `@opentelemetry/exporter-otlp-http` (deprecated)
   - To: `@opentelemetry/exporter-trace-otlp-http` (correct)

2. **✅ "Empty ring" errors**: Enabled Tempo metrics-generator
   - Added service-graphs processor
   - Added span-metrics processor
   - Configured remote write to Prometheus

### Verification Results
- **Traces stored**: 1.8MB in Tempo WAL
- **Metrics generated**: 124KB in metrics-generator
- **Pipeline status**: End-to-end operational
- **Grafana queries**: All TraceQL queries working

For detailed investigation report, see: [`TRACING_INVESTIGATION_SUMMARY.md`](./TRACING_INVESTIGATION_SUMMARY.md)

## Next Steps

1. **✅ DONE**: Traces are being generated and stored
2. **✅ DONE**: Grafana datasource configured and working
3. **✅ DONE**: Metrics-generator enabled for TraceQL queries
4. **Recommended**: Set up alerting based on span metrics
5. **Optional**: Configure persistent storage for Tempo
6. **Optional**: Implement sampling strategy for cost optimization

## Support

For issues or questions:
- **Check logs**: `kubectl logs -n monitoring -l app.kubernetes.io/name=tempo`
- **Verify connectivity**: Test OTLP endpoints
- **Review configuration**: Validate YAML syntax
- **Monitor resources**: Check CPU/memory usage
- **Troubleshooting**: See detailed troubleshooting section above

---

**🎉 Congratulations!** Your Rocket.Chat deployment now has **complete observability** with Metrics, Logs, and Traces integrated into a single, powerful monitoring platform.

**Implementation Date**: October 30, 2025  
**Status**: ✅ Fully Operational
