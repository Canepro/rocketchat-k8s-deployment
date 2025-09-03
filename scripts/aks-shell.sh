#!/bin/bash
# Quick access to AKS cluster

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup kubeconfig
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up AKS cluster access..."

# Check if kubectl is already configured and working
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "AKS cluster access already configured!"
else
    # Try to setup kubeconfig if needed
    if ! ./scripts/setup-kubeconfig.sh; then
        print_error "Failed to setup kubeconfig"
        exit 1
    fi
    print_success "AKS cluster configured!"
fi

print_success "AKS cluster ready!"
echo ""
echo "Available commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get services -A"
echo "  helm list -A"
echo "  kubectl logs -f deployment/rocketchat"
echo ""
echo "Quick checks:"
echo "  kubectl get ingress -A"
echo "  kubectl get certificates -A"
echo "  kubectl top nodes"
echo "  kubectl top pods"
echo ""

# Start interactive shell with kubectl context
print_status "Starting interactive AKS shell..."
print_status "Type 'exit' to quit"
echo ""

# Set a custom prompt for the AKS shell
export PS1='\[\033[1;34m\]AKS\[\033[0m\] \[\033[1;32m\]\w\[\033[0m\] \$ '

# Execute interactive bash shell
exec bash --rcfile <(echo "echo 'AKS Shell Ready - Type commands or exit to quit'")
