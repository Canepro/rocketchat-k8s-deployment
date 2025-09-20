#!/bin/bash

# 📊 Azure Cost Monitoring Script for Rocket.Chat AKS
# Provides cost analysis and monitoring capabilities
# Date: September 19, 2025

set -e

echo "💰 Azure Cost Monitoring for Rocket.Chat AKS"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUDGET_LIMIT=80  # Monthly budget in GBP
DAILY_LIMIT=2.67 # Daily budget limit (80/30)

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

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "----------------------------------------"
}

# Check if Azure CLI is available
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI to use cost monitoring features."
        echo "Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return 1
    fi

    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first."
        return 1
    fi

    return 0
}

# Get current cost information
get_cost_info() {
    print_header "Current Cost Information"

    # Get subscription info
    SUBSCRIPTION=$(az account show --query 'name' -o tsv)
    print_status "Subscription: $SUBSCRIPTION"

    # Get current month's cost (simplified - in real implementation would use Azure Cost Management API)
    echo ""
    print_status "Cost Analysis (Azure Portal):"
    echo "1. Go to: https://portal.azure.com/#blade/Microsoft_Azure_Billing/ModernBillingMenuBlade/Overview"
    echo "2. Navigate to Cost Management + Billing > Cost analysis"
    echo "3. Filter by subscription and date range"
    echo ""

    # Show resource usage
    print_header "Current Resource Usage"
    echo "AKS Cluster:"
    kubectl get nodes --no-headers | wc -l | xargs echo "  Nodes: "
    kubectl get pods -n rocketchat --no-headers | wc -l | xargs echo "  Rocket.Chat pods: "
    kubectl get pods -n monitoring --no-headers | wc -l | xargs echo "  Monitoring pods: "

    echo ""
    print_header "Resource Utilization"
    echo "CPU and Memory usage:"
    kubectl top nodes 2>/dev/null || echo "  Metrics server not available - install for detailed metrics"
}

# Show cost optimization recommendations
show_recommendations() {
    print_header "Cost Optimization Recommendations"

    echo "✅ Recently Applied:"
    echo "  • Rocket.Chat CPU limit: 1000m → 500m (-50%)"
    echo "  • MongoDB CPU limit: 1000m → 300m (-70%)"
    echo "  • Memory optimizations: 25-75% reductions"
    echo ""

    echo "🔄 Next Steps:"
    echo "  • Monitor performance impact (24-48 hours)"
    echo "  • Review Azure Cost Management trends"
    echo "  • Consider storage optimization"
    echo "  • Evaluate reserved instances (future)"
    echo ""

    echo "📊 Cost Targets:"
    printf "  Current budget: £%.0f/month\n" $BUDGET_LIMIT
    printf "  Daily limit: £%.2f/day\n" $DAILY_LIMIT
    printf "  Target spend: £55-75/month (15-25%% savings)\n"
}

# Show budget status
show_budget_status() {
    print_header "Budget Status"

    # Calculate days in current month
    CURRENT_DAY=$(date +%d)
    DAYS_IN_MONTH=$(cal $(date +%m) $(date +%Y) | awk 'NF {DAYS = $NF}; END {print DAYS}')

    # Calculate expected spend
    EXPECTED_DAILY=$(( BUDGET_LIMIT / DAYS_IN_MONTH ))
    EXPECTED_MONTHLY=$(( EXPECTED_DAILY * CURRENT_DAY ))

    printf "  Month progress: Day %d of %d (%.0f%%)\n" $CURRENT_DAY $DAILY_LIMIT $(( CURRENT_DAY * 100 / DAYS_IN_MONTH ))
    printf "  Expected spend so far: £%d\n" $EXPECTED_MONTHLY
    printf "  Remaining budget: £%d\n" $(( BUDGET_LIMIT - EXPECTED_MONTHLY ))
    printf "  Remaining days: %d\n" $(( DAYS_IN_MONTH - CURRENT_DAY ))

    echo ""
    print_status "Budget Alerts:"
    echo "  • 50% threshold: £40 (warning)"
    echo "  • 80% threshold: £64 (critical)"
    echo "  • 100% threshold: £80 (action required)"
}

# Show Azure cost analysis tips
show_azure_tips() {
    print_header "Azure Cost Analysis Tips"

    echo "🔍 Daily Monitoring:"
    echo "  1. Check Cost Management dashboard daily"
    echo "  2. Review service costs (AKS > Storage > Network)"
    echo "  3. Monitor for unexpected spikes"
    echo ""

    echo "📈 Weekly Review:"
    echo "  1. Analyze cost trends over past 7 days"
    echo "  2. Compare with previous weeks"
    echo "  3. Identify optimization opportunities"
    echo ""

    echo "🛠️ Optimization Tools:"
    echo "  • Azure Advisor: Cost recommendations"
    echo "  • Azure Monitor: Usage analytics"
    echo "  • Pricing Calculator: What-if scenarios"
}

# Main execution
main() {
    echo ""

    # Show current date and time
    echo "Report generated: $(date)"
    echo ""

    # Check Azure CLI
    if check_azure_cli; then
        print_success "Azure CLI configured and ready"
        echo ""
    fi

    # Get cost information
    get_cost_info
    echo ""

    # Show budget status
    show_budget_status
    echo ""

    # Show recommendations
    show_recommendations
    echo ""

    # Show Azure tips
    show_azure_tips
    echo ""

    print_success "Cost monitoring report complete!"
    echo ""
    echo "💡 Pro tip: Set up Azure budget alerts in the portal for automatic notifications"
    echo "   Portal → Cost Management → Budgets → Create budget"
}

# Run main function
main "$@"
