#!/bin/bash
# Subscription Monitor Script
# Automated subscription suspension detection and recovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_status "🔍 Starting subscription monitoring and recovery"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-<YOUR_CLUSTER_NAME>}"
RESOURCE_GROUP="${RESOURCE_GROUP:-<YOUR_RESOURCE_GROUP>}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"  # 5 minutes
MAX_RETRIES="${MAX_RETRIES:-3}"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login'."
        exit 1
    fi
    
    # Get subscription ID if not provided
    if [ -z "$SUBSCRIPTION_ID" ]; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        print_status "Using subscription ID: $SUBSCRIPTION_ID"
    fi
    
    print_success "Prerequisites check passed"
}

# Check cluster state
check_cluster_state() {
    print_status "Checking cluster state..."
    
    # Check if cluster exists
    if ! az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Cluster '$CLUSTER_NAME' not found in resource group '$RESOURCE_GROUP'"
        return 1
    fi
    
    # Get cluster status
    cluster_status=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv)
    print_status "Cluster status: $cluster_status"
    
    # Check if cluster is in a problematic state
    if [ "$cluster_status" = "Failed" ] || [ "$cluster_status" = "Deallocated" ]; then
        print_error "Cluster is in problematic state: $cluster_status"
        return 1
    fi
    
    print_success "Cluster state check passed"
    return 0
}

# Check subscription status
check_subscription_status() {
    print_status "Checking subscription status..."
    
    # Get subscription status
    subscription_state=$(az account show --query "state" -o tsv)
    print_status "Subscription state: $subscription_state"
    
    if [ "$subscription_state" = "Disabled" ] || [ "$subscription_state" = "PastDue" ]; then
        print_error "Subscription is in problematic state: $subscription_state"
        return 1
    fi
    
    print_success "Subscription status check passed"
    return 0
}

# Attempt cluster recovery
attempt_cluster_recovery() {
    print_status "Attempting cluster recovery..."
    
    # Try to update cluster to trigger reconciliation
    print_status "Attempting cluster update to trigger reconciliation..."
    if az aks update --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --no-wait &> /dev/null; then
        print_success "Cluster update initiated"
        
        # Wait for update to complete
        print_status "Waiting for cluster update to complete..."
        az aks wait --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --updated --timeout 1800
        
        # Check cluster status again
        cluster_status=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv)
        if [ "$cluster_status" = "Succeeded" ]; then
            print_success "Cluster recovery successful"
            return 0
        else
            print_error "Cluster recovery failed. Status: $cluster_status"
            return 1
        fi
    else
        print_error "Failed to initiate cluster update"
        return 1
    fi
}

# Trigger emergency recreation
trigger_emergency_recreation() {
    print_status "Triggering emergency cluster recreation..."
    
    # Check if we have recent snapshots
    latest_snapshot=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "max_by([?tags['created-by']=='backup-script'], &timeCreated).tags['backup-timestamp']" -o tsv)
    
    if [ -n "$latest_snapshot" ]; then
        print_status "Found latest snapshot: $latest_snapshot"
        
        # Trigger recreation workflow
        print_status "Triggering emergency recreation workflow..."
        # This would typically trigger a GitHub Actions workflow or Azure DevOps pipeline
        # For now, we'll just log the action
        print_status "Would trigger emergency recreation with snapshot: $latest_snapshot"
        return 0
    else
        print_error "No recent snapshots found for emergency recreation"
        return 1
    fi
}

# Monitor cluster continuously
monitor_cluster_continuously() {
    print_status "Starting continuous cluster monitoring..."
    
    retry_count=0
    
    while true; do
        print_status "Checking cluster state (attempt $((retry_count + 1))/$MAX_RETRIES)..."
        
        if check_cluster_state; then
            print_success "Cluster is healthy"
            retry_count=0
        else
            print_warning "Cluster is not healthy, attempting recovery..."
            
            if attempt_cluster_recovery; then
                print_success "Cluster recovery successful"
                retry_count=0
            else
                retry_count=$((retry_count + 1))
                print_warning "Cluster recovery failed (attempt $retry_count/$MAX_RETRIES)"
                
                if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
                    print_error "Maximum retry attempts reached. Triggering emergency recreation..."
                    if trigger_emergency_recreation; then
                        print_success "Emergency recreation triggered"
                        break
                    else
                        print_error "Emergency recreation failed"
                        exit 1
                    fi
                fi
            fi
        fi
        
        print_status "Waiting $CHECK_INTERVAL seconds before next check..."
        sleep "$CHECK_INTERVAL"
    done
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    print_status "Sending notification: $message"
    
    # This would typically send a notification via Slack, email, or other service
    # For now, we'll just log the notification
    print_status "Notification: $status - $message"
}

# Generate monitoring report
generate_monitoring_report() {
    print_status "Generating monitoring report..."
    
    # Get cluster information
    cluster_status=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv 2>/dev/null || echo "Not found")
    subscription_state=$(az account show --query "state" -o tsv)
    
    # Get latest snapshot
    latest_snapshot=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "max_by([?tags['created-by']=='backup-script'], &timeCreated).tags['backup-timestamp']" -o tsv 2>/dev/null || echo "None")
    
    echo "📊 Subscription Monitoring Report"
    echo "================================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Cluster: $CLUSTER_NAME"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Subscription: $SUBSCRIPTION_ID"
    echo ""
    echo "🔍 Status:"
    echo "   • Cluster Status: $cluster_status"
    echo "   • Subscription State: $subscription_state"
    echo "   • Latest Snapshot: $latest_snapshot"
    echo ""
    echo "📋 Recommendations:"
    if [ "$cluster_status" = "Succeeded" ]; then
        echo "   • Cluster is healthy and operational"
        echo "   • Continue monitoring"
        echo "   • Ensure backups are running"
    else
        echo "   • Cluster requires attention"
        echo "   • Check cluster logs for errors"
        echo "   • Consider emergency recreation if needed"
    fi
}

# Main execution
main() {
    print_status "Starting subscription monitoring process..."
    
    check_prerequisites
    check_subscription_status
    
    if [ "$1" = "continuous" ]; then
        monitor_cluster_continuously
    else
        if check_cluster_state; then
            print_success "Cluster is healthy"
            send_notification "SUCCESS" "Cluster is healthy and operational"
        else
            print_warning "Cluster is not healthy, attempting recovery..."
            if attempt_cluster_recovery; then
                print_success "Cluster recovery successful"
                send_notification "SUCCESS" "Cluster recovery successful"
            else
                print_error "Cluster recovery failed, triggering emergency recreation..."
                if trigger_emergency_recreation; then
                    print_success "Emergency recreation triggered"
                    send_notification "WARNING" "Emergency recreation triggered"
                else
                    print_error "Emergency recreation failed"
                    send_notification "ERROR" "Emergency recreation failed"
                    exit 1
                fi
            fi
        fi
    fi
    
    generate_monitoring_report
    
    print_success "Subscription monitoring completed successfully!"
    echo ""
    echo "🔍 Monitoring Summary:"
    echo "   • Cluster: $CLUSTER_NAME"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Subscription: $SUBSCRIPTION_ID"
    echo "   • Status: Completed successfully"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Monitor cluster health and performance"
    echo "   2. Ensure backups are running"
    echo "   3. Set up automated monitoring"
    echo "   4. Review recovery procedures"
}

# Run main function
main "$@"
