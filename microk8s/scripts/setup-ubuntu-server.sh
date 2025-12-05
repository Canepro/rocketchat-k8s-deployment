#!/bin/bash

# Ubuntu Server Setup Script for Rocket.Chat Kubernetes Deployment
# Designed for Azure Ubuntu VM

set -e

echo "🚀 Setting up Ubuntu server for Rocket.Chat Kubernetes deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

print_success "System updated successfully"

# Install required packages
print_status "Installing required packages..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    htop \
    unzip \
    wget \
    git

print_success "Required packages installed"

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

print_success "Docker installed successfully"

# Install kubectl
print_status "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

print_success "kubectl installed successfully"

# Install Helm
print_status "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

print_success "Helm installed successfully"

# Install MicroK8s (lightweight Kubernetes for single-node deployment)
print_status "Installing MicroK8s..."
sudo snap install microk8s --classic

# Add user to microk8s group
sudo usermod -aG microk8s $USER

# Enable required addons
sudo microk8s enable dns storage ingress

print_success "MicroK8s installed and configured"

# Configure firewall
print_status "Configuring firewall..."
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 6443/tcp # Kubernetes API
sudo ufw allow 10250/tcp # Kubelet
sudo ufw allow 30000:32767/tcp # NodePort services

# Enable firewall
sudo ufw --force enable

print_success "Firewall configured successfully"

# Configure kubeconfig to use MicroK8s
print_status "Configuring kubeconfig for MicroK8s..."
mkdir -p ~/.kube
sudo microk8s config > ~/.kube/config

print_success "kubeconfig configured"

# Display system information
echo ""
print_success "🎉 Ubuntu server setup completed!"
echo ""
echo "📋 System Information:"
echo "======================"
echo "Server IP: 20.68.53.249"
echo "Domain: <YOUR_DOMAIN>"
echo "OS: Ubuntu"
echo "Kubernetes: MicroK8s"
echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Logout and login again to apply group changes"
echo "2. Verify MicroK8s is running: microk8s status"
echo "3. Run the Rocket.Chat deployment script: ./deploy-rocketchat.sh"
echo ""
echo "📊 Useful Commands:"
echo "==================="
echo "Check MicroK8s status: microk8s status"
echo "Check kubectl: kubectl get nodes"
echo "Check Docker: docker --version"
echo "Check Helm: helm version"
echo ""
print_warning "Please logout and login again to apply group changes!"
