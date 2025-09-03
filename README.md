# 🚀 Rocket.Chat AKS Migration Project

**📂 All documentation moved to [docs/](docs/) folder for clean organization**

## Quick Start

### 1. AKS Connection (Already Working!)
```bash
# Test your AKS connection
kubectl get nodes

# Use the interactive shell
./scripts/aks-shell.sh
```

### 2. Review Documentation
📖 **[Complete Documentation](docs/)** - All guides, plans, and instructions

### 3. Key Documents
- 🏁 **[AKS Setup Guide](docs/AKS_SETUP_GUIDE.md)** - What we achieved & how to use it
- 📋 **[Master Plan](docs/MASTER_PLANNING.md)** - Complete migration roadmap
- 🛠️ **[Migration Steps](docs/MIGRATION_PLAN.md)** - Detailed 15-step process

## Project Structure

```
├── 📁 docs/          # All documentation and guides
├── 📁 scripts/       # Helper scripts for AKS access
├── 📄 *.yaml         # Kubernetes manifests for Rocket.Chat
└── 📄 *.sh           # Deployment and setup scripts
```

## Current Status: ✅ AKS Connected & Ready

Your local machine can now control your Azure AKS cluster remotely!

**Next**: Review `docs/AKS_SETUP_GUIDE.md` to understand what we achieved and how to use it.

---

*For detailed documentation, see the [docs/](docs/) folder*
