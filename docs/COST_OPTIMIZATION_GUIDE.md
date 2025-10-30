# 💰 Cost Optimization Guide

**Last Updated:** October 30, 2025  
**Status:** ✅ Complete  
**Purpose:** Guide for reducing costs while maintaining functionality

---

## 📊 Summary

### **Completed Optimizations**

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| **MongoDB** | 3 replicas | 1 replica | **66% reduction** |
| **NATS** | 2 replicas | 1 replica | **50% reduction** |
| **DDP Streamer** | 2 replicas | 1 replica | **50% reduction** |

**Total Rocket.Chat Savings:** ~50-60% reduction in compute costs

**Estimated Monthly Savings:** ~£30-50/month (50-60% reduction on optimized components)

---

## 🚀 Quick Start

### **Automated Cost Optimization**

Use the interactive script:
```bash
./scripts/cost-optimization.sh
```

This script handles:
- MongoDB replica reduction with automatic replica set reconfiguration
- NATS replica reduction
- DDP Streamer replica reduction
- Verification and status reporting

---

## 📋 Detailed Optimization Steps

### **Step 1: Reduce MongoDB Replicas**

**Current:** 3 replicas (for high availability)  
**Recommended:** 1 replica for cost savings, or 2 for basic redundancy

**Impact:**
- **Storage Savings:** 33-66% reduction (from 3x to 1-2x 10Gi volumes)
- **Compute Savings:** 33-66% reduction (from 3x to 1-2x pods)
- **Trade-off:** Less redundancy (for dev/non-critical workloads this is acceptable)

**Commands:**
```bash
# Option A: Use automated script (handles replica set automatically)
./scripts/cost-optimization.sh

# Option B: Manual scaling (requires replica set fix)
kubectl scale statefulset mongodb --replicas=1 -n rocketchat

# Fix replica set after scaling
./scripts/fix-mongodb-replica-set.sh
```

**⚠️ Important:** When scaling down MongoDB, the replica set must be reconfigured. Use the automated script or fix manually.

**Verification:**
```bash
# Check replica count
kubectl get statefulset mongodb -n rocketchat

# Verify MongoDB is PRIMARY
kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr))"

# Check resource usage
kubectl top pods -n rocketchat | grep mongodb
```

### **Step 2: Reduce NATS Replicas**

**Current:** 2 replicas  
**Recommended:** 1 replica for cost savings

**Impact:**
- **Compute Savings:** 50% reduction
- **Trade-off:** Less redundancy (acceptable for most workloads)

**Commands:**
```bash
kubectl scale statefulset rocketchat-nats --replicas=1 -n rocketchat
```

**Verification:**
```bash
# Check replica count
kubectl get statefulset rocketchat-nats -n rocketchat

# Verify NATS is running
kubectl get pods -n rocketchat | grep nats
```

### **Step 3: Reduce DDP Streamer Replicas**

**Current:** 2 replicas  
**Recommended:** 1 replica for cost savings

**Impact:**
- **Compute Savings:** 50% reduction
- **Trade-off:** Less redundancy (acceptable for most workloads)

**Commands:**
```bash
kubectl scale deployment rocketchat-ddp-streamer --replicas=1 -n rocketchat
```

**Verification:**
```bash
# Check replica count
kubectl get deployment rocketchat-ddp-streamer -n rocketchat

# Verify DDP Streamer is running
kubectl get pods -n rocketchat | grep ddp-streamer
```

---

## 📊 Monitoring Stack Analysis

### **Current Monitoring Configuration**

| Component | Replicas | CPU Usage | Memory Usage | Storage |
|-----------|----------|-----------|--------------|---------|
| **Prometheus** | 1 | 26m | 472Mi | 10Gi (7d retention) |
| **Loki** | 1 | 4m | 143Mi | 50Gi (7d retention) |
| **Grafana** | 1 | 6m | 325Mi | N/A |
| **Alertmanager** | 1 | 10m | 49Mi | N/A |

**Status:** ✅ Monitoring stack is already optimized (all at 1 replica)

### **Optional Monitoring Optimizations**

If you want to reduce monitoring costs further:

#### **1. Reduce Retention Periods**

**Prometheus** (currently 7 days):
```bash
# Edit Prometheus configuration
kubectl edit prometheus monitoring-kube-prometheus-prometheus -n monitoring

# Change retention from 7d to 3d
# retention: 3d
```

**Loki** (currently 7 days / 168h):
```bash
# Edit Loki values
# Change reject_old_samples_max_age from 168h to 72h (3 days)
```

**Savings:** ~50% reduction in storage costs

#### **2. Reduce Storage Sizes**

**Loki** (currently 50Gi):
```bash
# Edit Loki StatefulSet
kubectl edit statefulset loki -n monitoring

# Reduce volumeClaimTemplate size from 50Gi to 25Gi
# Note: Requires PVC recreation (more complex)
```

**Savings:** ~50% reduction in Loki storage costs

---

## 🔍 Current Resource Usage

**After Optimization:**
- MongoDB: 98m CPU, 228Mi memory (well below limits)
- NATS: 3m CPU, 39Mi memory (very low)
- DDP Streamer: 2m CPU, 58Mi memory (very low)

**Overall:** Heavy over-provisioning eliminated, appropriate resource allocation achieved

---

## 📈 Cost Impact Analysis

### **Achieved Savings (Rocket.Chat):**
- **MongoDB**: 66% reduction (~£20-30/month savings)
- **NATS**: 50% reduction (~£5-10/month savings)
- **DDP Streamer**: 50% reduction (~£5-10/month savings)
- **Total**: ~£30-50/month savings (50-60% reduction on optimized components)

### **Potential Additional Savings (Monitoring):**
- **Retention Reduction**: ~£5-10/month (storage savings)
- **Storage Size Reduction**: ~£5-10/month (if reducing Loki storage)
- **Total Potential**: ~£10-20/month additional savings

---

## 🎯 Recommendations

### **Current Status: ✅ Excellent**

Your deployment is well-optimized:
- ✅ Rocket.Chat components minimized
- ✅ Monitoring stack already at 1 replica
- ✅ Resource usage is appropriate
- ✅ No functionality lost

### **Optional Next Steps:**

1. **Monitor for 1-2 weeks** to ensure stability with reduced replicas
2. **Consider retention reduction** if historical data isn't critical
3. **Review storage sizes** if storage costs are high

### **Risk Assessment:**

**Current Optimizations:**
- ✅ Low risk (all pods running, no errors)
- ✅ No data loss risk
- ✅ Easy to rollback if needed

**Potential Monitoring Optimizations:**
- ⚠️ Retention reduction: Medium risk (lose historical data)
- ⚠️ Storage reduction: High risk (requires data migration)

---

## 🔄 Rollback Procedures

If you need to restore previous configuration:

```bash
# Scale MongoDB back to 3 replicas
kubectl scale statefulset mongodb --replicas=3 -n rocketchat

# Wait for pods to start
kubectl wait --for=condition=ready pod/mongodb-0 -n rocketchat --timeout=300s
kubectl wait --for=condition=ready pod/mongodb-1 -n rocketchat --timeout=300s
kubectl wait --for=condition=ready pod/mongodb-2 -n rocketchat --timeout=300s

# MongoDB will automatically add them back to the replica set

# Scale NATS back to 2 replicas
kubectl scale statefulset rocketchat-nats --replicas=2 -n rocketchat

# Scale DDP Streamer back to 2 replicas
kubectl scale deployment rocketchat-ddp-streamer --replicas=2 -n rocketchat
```

---

## 📋 Maintenance Checklist

**Weekly:**
- [ ] Monitor pod health: `kubectl get pods -n rocketchat`
- [ ] Check resource usage: `kubectl top pods -n rocketchat`
- [ ] Verify MongoDB replica set: `kubectl exec mongodb-0 -n rocketchat -- mongosh --eval "rs.status()"`

**Monthly:**
- [ ] Review Azure cost reports
- [ ] Check storage growth (Prometheus, Loki)
- [ ] Review retention policies

**As Needed:**
- [ ] Scale up if workload increases
- [ ] Adjust retention based on needs
- [ ] Review resource limits based on actual usage

---

## 📚 Related Documentation

- **How-To Guide:** `docs/HOW_TO_GUIDE.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING_GUIDE.md` (Section 6.2: MongoDB Replica Set Issues)
- **Authentication:** `docs/DEPLOYMENT_AUTHENTICATION_GUIDE.md`

---

## ⚠️ Common Issues

### **MongoDB Replica Set After Scaling**

**Problem:** After scaling down MongoDB, you may see `ReplicaSetNoPrimary` errors.

**Solution:** The cost optimization script handles this automatically. If done manually:
```bash
./scripts/fix-mongodb-replica-set.sh
```

See `docs/TROUBLESHOOTING_GUIDE.md` Section 6.2 for detailed troubleshooting.

---

**Last Updated:** October 30, 2025  
**Optimization Status:** ✅ Complete  
**Estimated Monthly Savings:** ~£30-50/month (50-60% reduction)
