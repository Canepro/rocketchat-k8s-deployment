# 🌐 DNS Migration Guide: MicroK8s to AKS

**Created**: September 4, 2025
**Last Updated**: September 5, 2025
**Purpose**: Step-by-step guide for migrating DNS from MicroK8s to AKS
**Status**: ✅ MIGRATION COMPLETE - Both domains successfully migrated

---

## 🎯 **Migration Overview**

### **Domains to Migrate:**
1. **<YOUR_DOMAIN>** - Rocket.Chat application
2. **grafana.<YOUR_DOMAIN>** - Monitoring dashboards

### **IP Addresses:**
- **Current (MicroK8s):** `20.68.53.249`
- **Target (AKS):** `<YOUR_STATIC_IP>`

### **Timeline:**
- **DNS Propagation:** 5-10 minutes
- **Rollback Window:** 3-5 days (keep MicroK8s VM)
- **Total Downtime:** 0 minutes (if done correctly)

---

## 📋 **Pre-Migration Checklist**

### **✅ AKS Deployment Requirements**
- [x] Official Rocket.Chat deployed successfully
- [x] MongoDB replica set running
- [x] SSL certificates issued by cert-manager ✅ **RESOLVED**
- [x] Rocket.Chat accessible at `https://<YOUR_STATIC_IP>` (SSL working)
- [x] Grafana accessible at `https://grafana.<YOUR_DOMAIN>` (SSL working)
- [x] DNS migration completed ✅ **SUCCESSFUL**
- [x] Production testing completed ✅ **VALIDATED**

### **✅ DNS Provider Access**
- [ ] Access to DNS management console
- [ ] Both domains currently pointing to `20.68.53.249`
- [ ] DNS TTL settings checked
- [ ] Backup of current DNS records

### **✅ Team Communication**
- [ ] Maintenance window scheduled
- [ ] Team notified of potential brief interruption
- [ ] Rollback plan communicated
- [ ] Contact information for urgent issues

---

## 🚀 **Migration Execution**

### **Step 1: Final AKS Testing (15 minutes)**

**Test Rocket.Chat:**
```bash
# Test direct IP access
curl -I http://<YOUR_STATIC_IP>

# Should return: HTTP/1.1 200 OK
```

**Test Grafana:**
```bash
# Port forward for testing
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Access in browser: http://localhost:3000
# Login: admin / GrafanaAdmin2024!
```

**Test SSL:**
```bash
# Check certificate status
kubectl get certificaterequests -n rocketchat
kubectl get certificates -n rocketchat

# Should show: READY=True
```

### **Step 2: DNS Update (2 minutes)**

**Update BOTH domains simultaneously:**

1. **Log into DNS Provider**
2. **Update <YOUR_DOMAIN>:**
   ```
   Type: A
   Name: chat
   Value: <YOUR_STATIC_IP>
   TTL: 300 (5 minutes)
   ```
3. **Update grafana.<YOUR_DOMAIN>:**
   ```
   Type: A
   Name: grafana.chat
   Value: <YOUR_STATIC_IP>
   TTL: 300 (5 minutes)
   ```
4. **Save Changes**

### **Step 3: DNS Propagation Verification (10 minutes)**

**Monitor DNS propagation:**
```bash
# Check multiple DNS servers
nslookup <YOUR_DOMAIN> 8.8.8.8
nslookup <YOUR_DOMAIN> 1.1.1.1
nslookup grafana.<YOUR_DOMAIN> 8.8.8.8

# Should return: <YOUR_STATIC_IP>
```

**Test production access:**
```bash
# Test HTTPS access
curl -I https://<YOUR_DOMAIN>
curl -I https://grafana.<YOUR_DOMAIN>

# Should return: HTTP/2 200
```

### **Step 4: Production Verification (20 minutes)**

**Monitor application logs:**
```bash
# Watch ingress logs
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx

# Watch Rocket.Chat logs
kubectl logs -f deployment/rocketchat -n rocketchat
```

**Test user functionality:**
- [ ] Login to Rocket.Chat
- [ ] Send test messages
- [ ] Access channels/teams
- [ ] File uploads working
- [ ] Search functionality

**Test monitoring:**
- [ ] Access Grafana at `https://grafana.<YOUR_DOMAIN>`
- [ ] View Rocket.Chat dashboards
- [ ] Check Prometheus metrics
- [ ] Verify alerting setup

---

## 🚨 **Emergency Rollback Plan**

### **If Issues Occur Within 3-5 Days:**

**Immediate Action (2 minutes):**
1. **Update DNS back to MicroK8s:**
   ```
   <YOUR_DOMAIN> → 20.68.53.249
   grafana.<YOUR_DOMAIN> → 20.68.53.249
   ```

2. **Verify rollback:**
   ```bash
   nslookup <YOUR_DOMAIN>
   # Should return: 20.68.53.249

   curl -I https://<YOUR_DOMAIN>
   # Should return: HTTP/2 200
   ```

**Investigation (30 minutes):**
1. **Check AKS logs:**
   ```bash
   kubectl get pods -n rocketchat
   kubectl get pods -n monitoring
   kubectl logs -f deployment/rocketchat -n rocketchat
   ```

2. **Common issues:**
   - SSL certificate problems
   - MongoDB connection issues
   - Ingress configuration errors
   - Resource constraints

**Resolution Options:**
- Fix issues and retry DNS migration
- Keep MicroK8s as production for now
- Schedule another migration attempt

---

## 📊 **Success Metrics**

### **Immediate Success Criteria:**
- [ ] DNS resolves to `<YOUR_STATIC_IP>`
- [ ] HTTPS access works for both domains
- [ ] SSL certificates valid
- [ ] Rocket.Chat login successful
- [ ] Grafana dashboards accessible
- [ ] No 5xx errors in logs

### **24-Hour Success Criteria:**
- [ ] All users can access Rocket.Chat
- [ ] File uploads working
- [ ] Performance acceptable (<2s response times)
- [ ] No critical errors in monitoring
- [ ] MicroK8s VM still available as backup

### **7-Day Success Criteria:**
- [ ] User adoption confirmed
- [ ] Performance stable
- [ ] Cost within Azure credit limits
- [ ] Monitoring alerts configured
- [ ] MicroK8s VM can be safely decommissioned

---

## 📞 **Support & Communication**

### **During Migration:**
- **Status Updates:** Every 5 minutes during DNS changes
- **Team Communication:** Slack/Teams channel for updates
- **Emergency Contact:** Direct phone number available

### **Post-Migration:**
- **Monitoring:** 24/7 for first 24 hours
- **Support:** Help desk ready for user issues
- **Documentation:** Updated with new access URLs

### **Key Contacts:**
- **Technical Lead:** Vincent Mogah
- **DNS Provider:** [Provider Contact Info]
- **Azure Support:** [Azure Subscription Details]
- **Team Lead:** [Team Contact Info]

---

## 📝 **Post-Migration Tasks**

### **Immediate (Within 1 hour):**
- [ ] Update internal documentation
- [ ] Update bookmark links
- [ ] Notify external partners
- [ ] Update monitoring dashboards

### **Short-term (Within 24 hours):**
- [ ] Configure enhanced monitoring
- [ ] Set up automated backups
- [ ] Review resource utilization
- [ ] Plan MicroK8s decommissioning

### **Long-term (Within 1 week):**
- [ ] Optimize AKS configuration
- [ ] Set up cost monitoring
- [ ] Plan disaster recovery testing
- [ ] Schedule security reviews

---

## 🏆 **Migration Success Checklist**

**Pre-Migration:**
- [x] AKS deployment tested and working
- [x] DNS provider access confirmed
- [x] Team communication completed
- [x] Rollback plan documented

**During Migration:**
- [ ] DNS updated for both domains
- [ ] Propagation verified
- [ ] Production access confirmed
- [ ] User functionality tested

**Post-Migration:**
- [ ] 24-hour monitoring completed
- [ ] User feedback collected
- [ ] Performance metrics reviewed
- [ ] Cost analysis completed

---

## ✅ **Migration Completion Summary**

**Migration Date**: September 5, 2025
**Status**: ✅ **SUCCESSFUL** - Zero downtime achieved
**Duration**: <5 minutes DNS propagation
**Domains Migrated**:
- `<YOUR_DOMAIN>` → <YOUR_STATIC_IP> ✅
- `grafana.<YOUR_DOMAIN>` → <YOUR_STATIC_IP> ✅

**Validation Results**:
- [x] DNS propagation confirmed
- [x] HTTPS access working for both domains
- [x] SSL certificates valid and functional
- [x] Rocket.Chat login and functionality verified
- [x] Grafana dashboards accessible
- [x] No service disruption detected

**Post-Migration Actions**:
- Monitor services for 24-48 hours
- Keep MicroK8s VM as rollback option for 3-5 days
- Plan MicroK8s decommissioning after validation period
- Consider enhanced monitoring setup

---

**Document Version:** 1.1
**Last Updated:** September 5, 2025
**Migration Status:** ✅ Complete - Production Active
**Prepared By:** Vincent Mogah
