# 🌐 DNS Migration Guide: MicroK8s to AKS

**Created**: September 4, 2025
**Purpose**: Step-by-step guide for migrating DNS from MicroK8s to AKS
**Critical**: Follow this sequence precisely to avoid downtime

---

## 🎯 **Migration Overview**

### **Domains to Migrate:**
1. **chat.canepro.me** - Rocket.Chat application
2. **grafana.chat.canepro.me** - Monitoring dashboards

### **IP Addresses:**
- **Current (MicroK8s):** `20.68.53.249`
- **Target (AKS):** `4.250.169.133`

### **Timeline:**
- **DNS Propagation:** 5-10 minutes
- **Rollback Window:** 3-5 days (keep MicroK8s VM)
- **Total Downtime:** 0 minutes (if done correctly)

---

## 📋 **Pre-Migration Checklist**

### **✅ AKS Deployment Requirements**
- [ ] Official Rocket.Chat deployed successfully
- [ ] MongoDB replica set running
- [ ] SSL certificates issued by cert-manager
- [ ] Rocket.Chat accessible at `http://4.250.169.133`
- [ ] Grafana accessible via port-forward
- [ ] Data migration completed

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
curl -I http://4.250.169.133

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
2. **Update chat.canepro.me:**
   ```
   Type: A
   Name: chat
   Value: 4.250.169.133
   TTL: 300 (5 minutes)
   ```
3. **Update grafana.chat.canepro.me:**
   ```
   Type: A
   Name: grafana.chat
   Value: 4.250.169.133
   TTL: 300 (5 minutes)
   ```
4. **Save Changes**

### **Step 3: DNS Propagation Verification (10 minutes)**

**Monitor DNS propagation:**
```bash
# Check multiple DNS servers
nslookup chat.canepro.me 8.8.8.8
nslookup chat.canepro.me 1.1.1.1
nslookup grafana.chat.canepro.me 8.8.8.8

# Should return: 4.250.169.133
```

**Test production access:**
```bash
# Test HTTPS access
curl -I https://chat.canepro.me
curl -I https://grafana.chat.canepro.me

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
- [ ] Access Grafana at `https://grafana.chat.canepro.me`
- [ ] View Rocket.Chat dashboards
- [ ] Check Prometheus metrics
- [ ] Verify alerting setup

---

## 🚨 **Emergency Rollback Plan**

### **If Issues Occur Within 3-5 Days:**

**Immediate Action (2 minutes):**
1. **Update DNS back to MicroK8s:**
   ```
   chat.canepro.me → 20.68.53.249
   grafana.chat.canepro.me → 20.68.53.249
   ```

2. **Verify rollback:**
   ```bash
   nslookup chat.canepro.me
   # Should return: 20.68.53.249

   curl -I https://chat.canepro.me
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
- [ ] DNS resolves to `4.250.169.133`
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

**Document Version:** 1.0
**Last Updated:** September 4, 2025
**Next Review:** September 18, 2025 (post-migration)
**Prepared By:** Vincent Mogah
