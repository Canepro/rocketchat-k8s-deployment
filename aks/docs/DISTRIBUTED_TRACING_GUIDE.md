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
# Deploy the complete tracing stack
./aks/scripts/deploy-tracing-stack.sh
```

### Manual Deployment

```bash
# 1. Deploy Tempo
helm install tempo grafana/tempo \
  -f aks/monitoring/tempo-values.yaml \
  --namespace monitoring

# 2. Deploy OpenTelemetry Collector
kubectl apply -f aks/monitoring/opentelemetry-collector.yaml

# 3. Configure Grafana datasource
kubectl apply -f aks/monitoring/grafana-tempo-datasource.yaml

# 4. Deploy tracing dashboard
kubectl apply -f aks/monitoring/grafana-tracing-dashboard.yaml

# 5. Instrument Rocket.Chat
kubectl apply -f aks/monitoring/rocketchat-tracing-instrumentation.yaml
```

## Configuration Files

### Tempo Configuration (`tempo-values.yaml`)
- **Storage**: 20Gi persistent volume for trace retention
- **Receivers**: OTLP, Jaeger, Zipkin protocols
- **Resources**: Optimized for AKS cost efficiency

### OpenTelemetry Collector (`opentelemetry-collector.yaml`)
- **Receivers**: Multiple protocol support
- **Processors**: Batch processing, memory limiting
- **Exporters**: Tempo backend, logging

### Rocket.Chat Instrumentation
- **Auto-instrumentation**: HTTP, database, internal operations
- **Resource attribution**: Service name, version, environment
- **Trace sampling**: Configurable sampling rates

## Grafana Integration

### Data Source Configuration
- **Tempo**: Primary tracing backend
- **Traces to Logs**: Correlate traces with Loki logs
- **Traces to Metrics**: Correlate traces with Prometheus metrics
- **Service Map**: Visualize service dependencies

### Dashboard Features
- **Trace Search**: Find traces by service, operation, duration
- **Trace Statistics**: Request counts, success rates, error rates
- **Performance Analysis**: Latency percentiles, bottleneck identification
- **Error Correlation**: Link errors across service boundaries

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
kubectl logs -n rocketchat -l app=rocketchat
```

#### Performance Issues
```bash
# Check resource usage
kubectl top pods -n monitoring

# Check trace volume
kubectl exec -n monitoring -l app.kubernetes.io/name=tempo -- wc -l /var/tempo/traces/*
```

#### Grafana Integration
```bash
# Check datasource configuration
kubectl get configmap -n monitoring grafana-tempo-datasource

# Check dashboard deployment
kubectl get configmap -n monitoring grafana-tracing-dashboard
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

## Next Steps

1. **Deploy the tracing stack** using the provided script
2. **Verify trace collection** in Grafana Tempo
3. **Configure custom dashboards** for your specific needs
4. **Set up alerting** based on trace metrics
5. **Train your team** on trace analysis and debugging

## Support

For issues or questions:
- **Check logs**: `kubectl logs -n monitoring -l app.kubernetes.io/name=tempo`
- **Verify connectivity**: Test OTLP endpoints
- **Review configuration**: Validate YAML syntax
- **Monitor resources**: Check CPU/memory usage

---

**🎉 Congratulations!** Your Rocket.Chat deployment now has **complete observability** with Metrics, Logs, and Traces integrated into a single, powerful monitoring platform.
