#!/bin/bash
# Migration script for moving from MicroK8s to AKS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Setup kubeconfig
print_status "Setting up kubeconfig access..."

# Check if kubectl is already configured and working
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "AKS cluster access already configured!"
else
    # Try to setup kubeconfig if needed
    if ! ./scripts/setup-kubeconfig.sh; then
        print_error "Failed to setup kubeconfig. Please ensure KUBECONFIG is set correctly."
        exit 1
    fi
    print_success "Kubeconfig configured successfully"
fi

# Verify cluster access
print_status "Verifying AKS cluster access..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot access AKS cluster. Please check your kubeconfig."
    exit 1
fi

print_success "AKS cluster access verified"
kubectl get nodes

# Continue with migration steps...
print_status "Starting migration process..."

# Add your migration logic here
echo "Migration steps would go here..."
echo ""
echo "Next steps:"
echo "1. Phase 1: Preparation & Assessment"
echo "2. Phase 2: Parallel Deployment"
echo "3. Phase 3: Cutover & Optimization"
echo ""
print_success "Migration script initialized successfully"
