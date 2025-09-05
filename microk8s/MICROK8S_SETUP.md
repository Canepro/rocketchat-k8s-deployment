# 🔧 Adding MicroK8s Context to Local Machine

## 🎯 Why We Need This

For Phase 1 assessment, we need to evaluate your **current MicroK8s environment**. Since you only have the AKS context locally, we need to add your MicroK8s context so you can assess both clusters from your local machine.

## 📋 Step-by-Step: Add MicroK8s Context

### **Step 1: Get MicroK8s Kubeconfig (On Your MicroK8s VM)**
```bash
# SSH to your MicroK8s VM
ssh azureuser@20.68.53.249

# Generate the kubeconfig
microk8s config > microk8s-config.yaml

# Exit back to your local machine
exit
```

### **Step 2: Transfer Kubeconfig to Local Machine**
```bash
# From your local machine, copy the file
scp azureuser@20.68.53.249:~/microk8s-config.yaml ~/microk8s-config.yaml
```

### **Step 3: Merge MicroK8s Config with Local Kubeconfig**
```bash
# Merge the MicroK8s config into your local kubeconfig
kubectl config view --raw > temp-config.yaml
KUBECONFIG=~/microk8s-config.yaml:temp-config.yaml kubectl config view --merge > ~/.kube/merged-config.yaml
cp ~/.kube/config ~/.kube/config.backup
cp ~/.kube/merged-config.yaml ~/.kube/config

# Clean up temp files
rm temp-config.yaml ~/microk8s-config.yaml
```

### **Step 4: Verify Contexts**
```bash
# List all available contexts
kubectl config get-contexts

# Expected output:
# CURRENT   NAME          CLUSTER       AUTHINFO                         NAMESPACE
# *         canepro_aks   canepro_aks   clusterUser_aks_rg_canepro_aks
#           microk8s      microk8s      admin@microk8s
```

### **Step 5: Test MicroK8s Context**
```bash
# Switch to MicroK8s context
kubectl config use-context microk8s

# Test connection
kubectl get nodes
kubectl get pods -A

# Check if you can see your Rocket.Chat deployment
kubectl get pods -n rocketchat
```

### **Step 6: Switch Back to AKS**
```bash
# Switch back to AKS for continued assessment
kubectl config use-context canepro_aks
kubectl get nodes  # Should show AKS nodes
```

## 🔍 Alternative: Direct Assessment on VM

If the above method doesn't work, you can run the assessment commands directly on your MicroK8s VM:

```bash
# SSH to your VM
ssh azureuser@20.68.53.249

# Run assessment commands
kubectl get nodes,pods,services -A
kubectl top nodes
kubectl top pods -A
kubectl describe nodes
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Helm inventory
helm list -A

# MongoDB assessment
kubectl exec -it mongodb-0 -n rocketchat -- mongo --eval "db.stats()"

# Copy results to local machine
# (results will be visible in your terminal)
```

## ✅ Verification Checklist

After setup, you should be able to:

- [ ] `kubectl config get-contexts` shows both `canepro_aks` and `microk8s`
- [ ] `kubectl config use-context microk8s` switches to MicroK8s
- [ ] `kubectl get nodes` shows your MicroK8s node
- [ ] `kubectl config use-context canepro_aks` switches back to AKS
- [ ] `kubectl get nodes` shows your AKS nodes

## 🚨 Important Notes

1. **Keep MicroK8s Running**: Don't shut down your MicroK8s VM during assessment
2. **Backup First**: Always backup before making kubeconfig changes
3. **Test Thoroughly**: Verify both contexts work before proceeding
4. **Security**: Never share your kubeconfig files

## 🎯 Next Steps

Once you have both contexts working:

1. **Assess MicroK8s**: Run all Phase 1 assessment commands
2. **Document Findings**: Update the Phase 1 status document
3. **Compare Environments**: Note differences between MicroK8s and AKS
4. **Plan Migration**: Use findings to refine migration strategy

**Ready to add the MicroK8s context?** 🚀
