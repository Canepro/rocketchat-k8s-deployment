# 🔍 Loki Log Queries for Rocket.Chat Monitoring
# Updated: September 6, 2025
# Access: Grafana → Explore → Loki Data Source

## 📋 **Basic Log Queries**

### **1. All Rocket.Chat Logs**
```logql
{namespace="rocketchat"}
```

### **2. Logs by Specific App Component**
```logql
{app="rocketchat"}
```

### **3. Logs from Specific Pods**
```logql
{pod=~"rocketchat-rocketchat.*"}
```

### **4. DDP Streamer Logs (WebSocket connections)**
```logql
{pod=~"rocketchat-rocketchat-ddp-streamer.*"}
```

### **5. Stream Hub Logs (Real-time messaging)**
```logql
{pod=~"rocketchat-rocketchat-stream-hub.*"}
```

### **6. MongoDB Logs**
```logql
{pod=~"rocketchat-mongodb.*"}
```

## 🔍 **Advanced Queries**

### **7. Error Logs Only**
```logql
{namespace="rocketchat"} |= "error" or "ERROR" or "Error"
```

### **8. Login/Authentication Logs**
```logql
{namespace="rocketchat"} |= "login" or "auth" or "authentication"
```

### **9. API Request Logs**
```logql
{namespace="rocketchat"} |= "POST" or "GET" or "PUT" or "DELETE"
```

### **10. WebSocket Connection Logs**
```logql
{namespace="rocketchat"} |= "websocket" or "socket.io" or "ddp"
```

### **11. Database Connection Logs**
```logql
{namespace="rocketchat"} |= "mongodb" or "database" or "db"
```

### **12. Recent Logs (Last 1 Hour)**
```logql
{namespace="rocketchat"} [1h]
```

## ⚠️ **Troubleshooting Queries**

### **13. Application Startup Logs**
```logql
{namespace="rocketchat"} |= "startup" or "starting" or "ready"
```

### **14. Memory/Performance Issues**
```logql
{namespace="rocketchat"} |= "memory" or "cpu" or "performance" or "slow"
```

### **15. SSL/Certificate Logs**
```logql
{namespace="rocketchat"} |= "ssl" or "certificate" or "https" or "tls"
```

### **16. Failed Requests**
```logql
{namespace="rocketchat"} |= "failed" or "timeout" or "500" or "error"
```

## 📊 **Metrics from Logs**

### **17. Count Errors per Minute**
```logql
sum by (pod) (count_over_time({namespace="rocketchat"} |= "error" [1m]))
```

### **18. Request Rate by Component**
```logql
sum by (app) (rate({namespace="rocketchat"} |= "request" [5m]))
```

### **19. Log Volume by Pod**
```logql
sum by (pod) (count_over_time({namespace="rocketchat"} [1m]))
```

## 🎯 **Quick Health Checks**

### **20. Check if All Components are Logging**
```logql
{namespace="rocketchat"} | logfmt | count by (pod) > 0
```

### **21. Latest Log Entry per Component**
```logql
{namespace="rocketchat"} | limit 1
```

### **22. Logs with Timestamps (Last 5 minutes)**
```logql
{namespace="rocketchat"} [5m]
```

## 💡 **Pro Tips**

1. **Use Time Range**: Always set appropriate time range (top-right in Grafana)
2. **Filter by Level**: Add `|= "INFO"` or `|= "DEBUG"` to filter log levels
3. **Combine Filters**: `{namespace="rocketchat"} |= "error" |~ "user.*login"`
4. **Live Tail**: Enable "Live" toggle for real-time log streaming
5. **Export**: Use "Split" view to compare different queries side-by-side

## 🚀 **Verification Commands**

```bash
# Check if Loki is receiving logs
kubectl logs -n monitoring loki-0 --tail=10

# Check Promtail log collection
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=10

# Verify Loki has logs
kubectl exec -n monitoring loki-0 -- wget -qO- 'http://localhost:3100/loki/api/v1/labels' | head -20

# Verify Rocket.Chat pods are producing logs
kubectl logs -n rocketchat <rocketchat-pod-name> --tail=10
```

## 📱 **Mobile-Friendly Queries**
For quick mobile access, bookmark these simplified queries:
- All logs: `{namespace="rocketchat"}`
- Errors only: `{namespace="rocketchat"} |= "error"`
- Last hour: `{namespace="rocketchat"} [1h]`
