#!/bin/bash
# Setup script for kubeconfig access

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default paths for different machines
DEFAULT_KUBECONFIG_PATHS=(
    "$HOME/.kube/config"
    "$HOME/OneDrive/Documents/Dev_Stuff/config"
    "C:\\Users\\$USER\\OneDrive\\Documents\\Dev_Stuff\\config"
    "/mnt/c/Users/$USER/OneDrive/Documents/Dev_Stuff/config"
)

# Check if KUBECONFIG environment variable is set
if [ -n "$KUBECONFIG" ]; then
    if [ -f "$KUBECONFIG" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Using kubeconfig from KUBECONFIG env var: $KUBECONFIG"
        export KUBECONFIG="$KUBECONFIG"
        exit 0
    else
        echo -e "${YELLOW}[WARNING]${NC} KUBECONFIG path does not exist: $KUBECONFIG"
    fi
fi

# Try to find kubeconfig automatically
for path in "${DEFAULT_KUBECONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Found kubeconfig at: $path"
        export KUBECONFIG="$path"
        exit 0
    fi
done

# If not found, prompt user
echo -e "${RED}[ERROR]${NC} Kubeconfig not found automatically."
echo "Please set the KUBECONFIG environment variable:"
echo "export KUBECONFIG=/path/to/your/kubeconfig"
echo ""
echo "Or create a symlink:"
echo "ln -s /path/to/your/kubeconfig ~/.kube/config"
exit 1
