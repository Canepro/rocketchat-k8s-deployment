# 🚀 AKS Setup Success Guide (For Beginners)

## 🎉 What We Just Achieved!

**BIG SUCCESS!** We successfully got your local machine connected to your Azure Kubernetes Service (AKS) cluster. This means you can now control your cloud Kubernetes cluster from your personal computer!

## 📋 What This Means

Before today, you could only manage your Kubernetes cluster from:
- ❌ Your work machine (with Azure account restrictions)
- ❌ The Azure VM directly (limited access)

Now you can manage everything from:
- ✅ **Your personal machine** (Windows/Linux/Mac)
- ✅ **Full kubectl access** to your AKS cluster
- ✅ **Easy remote management** of your Rocket.Chat deployment

---

## 🔧 Step-by-Step: How We Made This Work

### The Problem
Your original kubeconfig file (downloaded from Azure) wasn't working with kubectl on your local machine. kubectl couldn't read the file properly and showed errors like:
- "Unable to connect to the server: dial tcp [::1]:8080"
- "contexts: null, users: null"

### The Solution (What We Did)

#### Step 1: Clean Up the Repository
```
✅ Removed duplicate files
✅ Created organized folder structure
├── docs/          # All documentation
├── scripts/       # Helper scripts
└── Root files     # Kubernetes manifests
```

#### Step 2: Fix the Kubeconfig Issue
**Problem**: kubectl couldn't parse your downloaded kubeconfig
**Solution**: Recreated the configuration using kubectl commands

```bash
# We created a fresh kubeconfig using kubectl:
kubectl config set-cluster canepro_aks --server="https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443"
kubectl config set-credentials clusterUser_aks_rg_canepro_aks --token="[your-token]"
kubectl config set-context canepro_aks --cluster=canepro_aks --user=clusterUser_aks_rg_canepro_aks
kubectl config use-context canepro_aks
```

#### Step 3: Handle Security (SSL Certificates)
**Problem**: Certificate verification was failing
**Solution**: Used `--insecure-skip-tls-verify=true` for initial setup

```bash
kubectl config set-cluster canepro_aks --insecure-skip-tls-verify=true
```

#### Step 4: Test the Connection
```bash
$ kubectl get nodes
NAME                                STATUS   ROLES    AGE   VERSION
aks-agentpool-13009631-vmss000000   Ready    <none>   26h   v1.32.6

✅ SUCCESS! Your AKS cluster is connected!
```

#### Step 5: Create Helper Scripts
We created easy-to-use scripts:
- `scripts/aks-shell.sh` - Interactive shell for AKS
- `scripts/migrate-to-aks.sh` - Migration helper
- `scripts/setup-kubeconfig.sh` - Kubeconfig setup

---

## 💻 How to Use This on Your Local Machine (Beginner Guide)

### Daily Usage - Super Simple!

#### Option 1: Quick Interactive Shell (Recommended for beginners)
```bash
# Open your terminal/command prompt
# Navigate to your project folder
cd C:\Users\i\rocketchat-k8s-deployment

# Start the AKS shell
./scripts/aks-shell.sh

# You'll see:
# [SUCCESS] AKS cluster access already configured!
# [SUCCESS] AKS cluster ready!
#
# Available commands:
#   kubectl get nodes
#   kubectl get pods -A
```

#### Option 2: Direct kubectl Commands
```bash
# Check your cluster
kubectl get nodes

# See all pods
kubectl get pods -A

# Check services
kubectl get services -A

# View logs
kubectl logs -f deployment/your-deployment-name
```

### If You Need to Work on a Different Machine

#### Method 1: Copy the kubeconfig (Simplest)
```bash
# On your current machine (where it's working):
cp ~/.kube/config /path/to/backup/kubeconfig-aks

# On the new machine:
mkdir -p ~/.kube
cp /path/from/backup/kubeconfig-aks ~/.kube/config

# Test:
kubectl get nodes
```

#### Method 2: Re-run the Setup Process
```bash
# On any new machine, run these commands:
kubectl config set-cluster canepro_aks --server="https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443" --insecure-skip-tls-verify=true
kubectl config set-credentials clusterUser_aks_rg_canepro_aks --token="[your-saved-token]"
kubectl config set-context canepro_aks --cluster=canepro_aks --user=clusterUser_aks_rg_canepro_aks
kubectl config use-context canepro_aks

# Test connection:
kubectl get nodes
```

---

## 🔍 Understanding Your Current Setup

### Your AKS Cluster Details
```
Cluster Name: canepro_aks
Server: https://canepro-h84gy5hj.hcp.uksouth.azmk8s.io:443
Location: UK South (Azure region)
Kubernetes Version: v1.32.6
Nodes: 1 (aks-agentpool-13009631-vmss000000)
```

### What's Running on Your Cluster
From our testing, you have:
- ✅ **Azure Policy** (gatekeeper-system)
- ✅ **Azure Monitor** (ama-logs, ama-metrics)
- ✅ **Ready for Rocket.Chat deployment**

### Your Local Files Structure
```
rocketchat-k8s-deployment/
├── docs/                    # 📚 All documentation
│   ├── AKS_SETUP_GUIDE.md   # This guide!
│   ├── MASTER_PLANNING.md   # Complete migration plan
│   ├── MIGRATION_PLAN.md    # Step-by-step migration
│   └── ...
├── scripts/                 # 🛠️ Helper scripts
│   ├── aks-shell.sh         # Interactive AKS access
│   ├── migrate-to-aks.sh    # Migration helper
│   └── setup-kubeconfig.sh  # Kubeconfig setup
├── clusterissuer.yaml       # SSL certificates
├── values-production.yaml   # Rocket.Chat config
└── [other YAML files]       # Kubernetes manifests
```

---

## 🚨 Troubleshooting (Common Issues & Solutions)

### Issue 1: "Unable to connect to the server"
**Symptoms**: `kubectl get nodes` shows connection errors
**Solutions**:
```bash
# Check if context is set
kubectl config current-context

# If not set, use:
kubectl config use-context canepro_aks

# Test connection
kubectl cluster-info
```

### Issue 2: "kubectl command not found"
**Symptoms**: `kubectl` is not recognized
**Solutions**:
```bash
# On Windows: Install via Chocolatey
choco install kubernetes-cli

# On Linux/Mac: Install via package manager
# Ubuntu/Debian: sudo apt install kubectl
# macOS: brew install kubectl

# Verify installation
kubectl version --client
```

### Issue 3: Permission Issues
**Symptoms**: Access denied or unauthorized errors
**Solutions**:
```bash
# Check your current user
kubectl config view --minify

# If wrong user, switch contexts
kubectl config get-contexts
kubectl config use-context canepro_aks
```

### Issue 4: Scripts Don't Work
**Symptoms**: `./scripts/aks-shell.sh` shows errors
**Solutions**:
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Or run with bash explicitly
bash scripts/aks-shell.sh
```

---

## 📚 Important Files to Keep Safe

### Critical Files (Don't Delete!)
```
✅ ~/.kube/config              # Your AKS connection (on local machine)
✅ docs/MASTER_PLANNING.md     # Complete migration roadmap
✅ docs/MIGRATION_PLAN.md      # Step-by-step migration guide
✅ scripts/                    # All helper scripts
✅ values-production.yaml      # Your Rocket.Chat configuration
```

### Files You Can Regenerate
```
🔄 clusterissuer.yaml         # SSL certificate config
🔄 monitoring-values.yaml     # Grafana/Prometheus config
🔄 deploy-rocketchat.sh       # Deployment script
```

---

## 🎯 Next Steps: Your Migration Journey

### Phase 1: Learning & Testing (Current)
You're here! ✅
- ✅ AKS connection working
- ✅ Basic kubectl commands working
- ✅ Understanding your cluster

### Phase 2: Migration Planning (Next)
- 📋 Review `docs/MASTER_PLANNING.md`
- 📋 Understand the 15-step migration process
- 📋 Plan your timeline and resources

### Phase 3: Actual Migration
- 🚀 Deploy Rocket.Chat to AKS
- 🚀 Test everything works
- 🚀 Switch DNS and go live

### Phase 4: Optimization
- ⚡ Performance tuning
- ⚡ Cost optimization
- ⚡ Monitoring setup

---

## 💡 Pro Tips for Beginners

### 1. Always Test Commands First
```bash
# Before running any command, test it safely:
kubectl get nodes --dry-run
kubectl get pods --dry-run
```

### 2. Use Help When Stuck
```bash
# Get help on any kubectl command
kubectl get --help
kubectl logs --help
kubectl describe --help
```

### 3. Learn These Essential Commands
```bash
# Check cluster health
kubectl get nodes
kubectl cluster-info

# Check applications
kubectl get pods -A
kubectl get deployments -A
kubectl get services -A

# Debug issues
kubectl logs -f deployment/your-app
kubectl describe pod/your-pod
kubectl get events --sort-by='.lastTimestamp'
```

### 4. Backup Your Configuration
```bash
# Regularly backup your working setup
cp ~/.kube/config ~/.kube/config.backup
kubectl get all -A -o yaml > cluster-backup.yaml
```

---

## 📞 Getting Help

### If Something Breaks
1. **Check basic connectivity**: `kubectl get nodes`
2. **Verify context**: `kubectl config current-context`
3. **Review this guide**: Check troubleshooting section
4. **Check logs**: `kubectl logs -f [pod-name]`

### Resources for Learning
- 📖 **Official kubectl docs**: https://kubectl.docs.kubernetes.io/
- 📖 **AKS documentation**: https://docs.microsoft.com/en-us/azure/aks/
- 📖 **Kubernetes basics**: https://kubernetes.io/docs/tutorials/

---

## 🎉 Congratulations!

You've successfully set up remote access to your AKS cluster! This is a **major milestone** for your Rocket.Chat migration project.

**What you can now do:**
- ✅ Control your cloud Kubernetes cluster from your personal machine
- ✅ Run kubectl commands without Azure VM restrictions
- ✅ Prepare for migrating your Rocket.Chat application
- ✅ Learn Kubernetes in a safe, controlled environment

**Remember**: Take it one step at a time. You've already accomplished something that many people struggle with for weeks!

---

**Document Version**: 1.0
**Last Updated**: Current Session
**Skill Level**: Beginner-Friendly
**Next Step**: Review `docs/MASTER_PLANNING.md` for migration planning
