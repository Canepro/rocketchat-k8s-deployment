#!/bin/bash
# Backup Restore Test Script
# Full end-to-end backup and restore validation with real data

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

print_status "🧪 Starting full end-to-end backup and restore validation"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-<YOUR_CLUSTER_NAME>}"
RESOURCE_GROUP="${RESOURCE_GROUP:-<YOUR_RESOURCE_GROUP>}"
NAMESPACE="${NAMESPACE:-rocketchat}"
TEST_NAMESPACE="${TEST_NAMESPACE:-rocketchat-test}"
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
TEST_RESULTS_DIR="/tmp/backup-restore-test-results-$(date +%Y%m%d_%H%M%S)"

# Create test results directory
create_test_results_directory() {
    print_status "Creating test results directory..."
    mkdir -p "$TEST_RESULTS_DIR"
    print_success "Test results directory created: $TEST_RESULTS_DIR"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login'."
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl get nodes &> /dev/null; then
        print_error "Cannot connect to cluster. Check kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create test data
create_test_data() {
    print_status "Creating test data..."
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create test MongoDB deployment
    print_status "Creating test MongoDB deployment..."
    cat > "$TEST_RESULTS_DIR/test-mongodb.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-mongodb
  namespace: $TEST_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-mongodb
  template:
    metadata:
      labels:
        app: test-mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:6.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "testuser"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "testpass"
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      volumes:
      - name: mongodb-data
        emptyDir: {}
EOF
    
    kubectl apply -f "$TEST_RESULTS_DIR/test-mongodb.yaml"
    
    # Wait for MongoDB to be ready
    kubectl wait --for=condition=ready pod -l app=test-mongodb -n "$TEST_NAMESPACE" --timeout=300s
    
    # Create test data
    print_status "Creating test data in MongoDB..."
    kubectl exec -it $(kubectl get pod -l app=test-mongodb -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].metadata.name}') -n "$TEST_NAMESPACE" -- mongosh --eval "
      use testdb;
      db.testcollection.insertOne({name: 'test-document', value: 'test-value', timestamp: new Date()});
      db.testcollection.insertOne({name: 'test-document-2', value: 'test-value-2', timestamp: new Date()});
      db.testcollection.find().pretty();
    "
    
    print_success "Test data created"
}

# Test MongoDB backup
test_mongodb_backup() {
    print_status "Testing MongoDB backup..."
    
    # Create MongoDB backup
    print_status "Creating MongoDB backup..."
    if [ -f "scripts/backup/mongodb-backup.sh" ]; then
        # Modify script for test environment
        sed 's/NAMESPACE="${NAMESPACE:-rocketchat}"/NAMESPACE="'$TEST_NAMESPACE'"/' scripts/backup/mongodb-backup.sh > "$TEST_RESULTS_DIR/test-mongodb-backup.sh"
        sed -i 's/MONGODB_POD="${MONGODB_POD:-mongodb-0}"/MONGODB_POD="test-mongodb-0"/' "$TEST_RESULTS_DIR/test-mongodb-backup.sh"
        chmod +x "$TEST_RESULTS_DIR/test-mongodb-backup.sh"
        
        if ./scripts/backup/mongodb-backup.sh &> "$TEST_RESULTS_DIR/mongodb-backup-test.log"; then
            print_success "MongoDB backup test passed"
        else
            print_error "MongoDB backup test failed"
            return 1
        fi
    else
        print_error "MongoDB backup script not found"
        return 1
    fi
}

# Test MongoDB restore
test_mongodb_restore() {
    print_status "Testing MongoDB restore..."
    
    # Delete test data
    print_status "Deleting test data..."
    kubectl exec -it $(kubectl get pod -l app=test-mongodb -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].metadata.name}') -n "$TEST_NAMESPACE" -- mongosh --eval "
      use testdb;
      db.testcollection.drop();
    "
    
    # Verify data is deleted
    print_status "Verifying data is deleted..."
    kubectl exec -it $(kubectl get pod -l app=test-mongodb -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].metadata.name}') -n "$TEST_NAMESPACE" -- mongosh --eval "
      use testdb;
      db.testcollection.find().pretty();
    "
    
    # Restore from backup
    print_status "Restoring from backup..."
    if [ -f "scripts/backup/mongodb-restore.sh" ]; then
        # Modify script for test environment
        sed 's/NAMESPACE="${NAMESPACE:-rocketchat}"/NAMESPACE="'$TEST_NAMESPACE'"/' scripts/backup/mongodb-restore.sh > "$TEST_RESULTS_DIR/test-mongodb-restore.sh"
        sed -i 's/MONGODB_POD="${MONGODB_POD:-mongodb-0}"/MONGODB_POD="test-mongodb-0"/' "$TEST_RESULTS_DIR/test-mongodb-restore.sh"
        chmod +x "$TEST_RESULTS_DIR/test-mongodb-restore.sh"
        
        if ./scripts/backup/mongodb-restore.sh &> "$TEST_RESULTS_DIR/mongodb-restore-test.log"; then
            print_success "MongoDB restore test passed"
        else
            print_error "MongoDB restore test failed"
            return 1
        fi
    else
        print_error "MongoDB restore script not found"
        return 1
    fi
}

# Verify data integrity
verify_data_integrity() {
    print_status "Verifying data integrity..."
    
    # Check if test data was restored
    print_status "Checking if test data was restored..."
    kubectl exec -it $(kubectl get pod -l app=test-mongodb -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].metadata.name}') -n "$TEST_NAMESPACE" -- mongosh --eval "
      use testdb;
      db.testcollection.find().pretty();
    " > "$TEST_RESULTS_DIR/restored-data.log"
    
    # Check if both test documents are present
    if grep -q "test-document" "$TEST_RESULTS_DIR/restored-data.log" && grep -q "test-document-2" "$TEST_RESULTS_DIR/restored-data.log"; then
        print_success "Data integrity verification passed"
    else
        print_error "Data integrity verification failed"
        return 1
    fi
}

# Test PVC backup and restore
test_pvc_backup_restore() {
    print_status "Testing PVC backup and restore..."
    
    # Create test PVC
    print_status "Creating test PVC..."
    cat > "$TEST_RESULTS_DIR/test-pvc.yaml" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard-ssd
EOF
    
    kubectl apply -f "$TEST_RESULTS_DIR/test-pvc.yaml"
    
    # Wait for PVC to be bound
    kubectl wait --for=condition=bound pvc test-pvc -n "$TEST_NAMESPACE" --timeout=300s
    
    # Create test data in PVC
    print_status "Creating test data in PVC..."
    kubectl run test-pod --image=busybox --rm -i --restart=Never --overrides='
    {
      "spec": {
        "containers": [{
          "name": "test-pod",
          "image": "busybox",
          "command": ["sh"],
          "stdin": true,
          "volumeMounts": [{
            "name": "test-volume",
            "mountPath": "/data"
          }]
        }],
        "volumes": [{
          "name": "test-volume",
          "persistentVolumeClaim": {
            "claimName": "test-pvc"
          }
        }]
      }
    }' -- echo "test-data" > /data/test-file.txt
    
    # Test PVC snapshot
    print_status "Testing PVC snapshot..."
    if [ -f "scripts/backup/create-pvc-snapshots.sh" ]; then
        if ./scripts/backup/create-pvc-snapshots.sh &> "$TEST_RESULTS_DIR/pvc-snapshot-test.log"; then
            print_success "PVC snapshot test passed"
        else
            print_error "PVC snapshot test failed"
            return 1
        fi
    else
        print_error "PVC snapshot script not found"
        return 1
    fi
    
    # Test PVC restore
    print_status "Testing PVC restore..."
    if [ -f "scripts/backup/restore-from-snapshots.sh" ]; then
        if ./scripts/backup/restore-from-snapshots.sh &> "$TEST_RESULTS_DIR/pvc-restore-test.log"; then
            print_success "PVC restore test passed"
        else
            print_error "PVC restore test failed"
            return 1
        fi
    else
        print_error "PVC restore script not found"
        return 1
    fi
}

# Test cluster state backup and restore
test_cluster_state_backup_restore() {
    print_status "Testing cluster state backup and restore..."
    
    # Test cluster state backup
    print_status "Testing cluster state backup..."
    if [ -f "scripts/backup/backup-cluster-state.sh" ]; then
        if ./scripts/backup/backup-cluster-state.sh &> "$TEST_RESULTS_DIR/cluster-state-backup-test.log"; then
            print_success "Cluster state backup test passed"
        else
            print_error "Cluster state backup test failed"
            return 1
        fi
    else
        print_error "Cluster state backup script not found"
        return 1
    fi
}

# Test backup validation
test_backup_validation() {
    print_status "Testing backup validation..."
    
    # Test backup integrity check
    print_status "Testing backup integrity check..."
    if [ -f "scripts/backup/backup-integrity-check.sh" ]; then
        if ./scripts/backup/backup-integrity-check.sh &> "$TEST_RESULTS_DIR/backup-integrity-test.log"; then
            print_success "Backup integrity check test passed"
        else
            print_error "Backup integrity check test failed"
            return 1
        fi
    else
        print_error "Backup integrity check script not found"
        return 1
    fi
}

# Clean up test resources
cleanup_test_resources() {
    print_status "Cleaning up test resources..."
    
    # Delete test namespace
    kubectl delete namespace "$TEST_NAMESPACE" --grace-period=300 &> /dev/null || true
    
    # Clean up test results directory
    print_status "Test results saved in: $TEST_RESULTS_DIR"
    print_status "Review test logs for detailed results"
    
    print_success "Test resources cleaned up"
}

# Generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    # Count test results
    total_tests=0
    passed_tests=0
    failed_tests=0
    
    for log_file in "$TEST_RESULTS_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            total_tests=$((total_tests + 1))
            if grep -q "SUCCESS\|PASS" "$log_file"; then
                passed_tests=$((passed_tests + 1))
            else
                failed_tests=$((failed_tests + 1))
            fi
        fi
    done
    
    echo "📊 Backup Restore Test Report"
    echo "============================"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Test Results Directory: $TEST_RESULTS_DIR"
    echo ""
    echo "📈 Test Summary:"
    echo "   • Total Tests: $total_tests"
    echo "   • Passed: $passed_tests"
    echo "   • Failed: $failed_tests"
    echo "   • Success Rate: $((passed_tests * 100 / total_tests))%"
    echo ""
    echo "📋 Test Categories:"
    echo "   • MongoDB Backup: $(if [ -f "$TEST_RESULTS_DIR/mongodb-backup-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo "   • MongoDB Restore: $(if [ -f "$TEST_RESULTS_DIR/mongodb-restore-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo "   • PVC Backup: $(if [ -f "$TEST_RESULTS_DIR/pvc-snapshot-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo "   • PVC Restore: $(if [ -f "$TEST_RESULTS_DIR/pvc-restore-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo "   • Cluster State Backup: $(if [ -f "$TEST_RESULTS_DIR/cluster-state-backup-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo "   • Backup Validation: $(if [ -f "$TEST_RESULTS_DIR/backup-integrity-test.log" ]; then echo "TESTED"; else echo "NOT TESTED"; fi)"
    echo ""
    echo "📁 Test Logs:"
    ls -la "$TEST_RESULTS_DIR"/*.log | while read -r line; do
        echo "   • $line"
    done
    echo ""
    echo "📋 Recommendations:"
    if [ "$failed_tests" -eq 0 ]; then
        echo "   • All tests passed successfully"
        echo "   • Backup and restore system is working correctly"
        echo "   • Ready for production deployment"
    else
        echo "   • Some tests failed - review logs"
        echo "   • Fix issues before production deployment"
        echo "   • Re-run tests after fixes"
    fi
}

# Main execution
main() {
    print_status "Starting backup restore test process..."
    
    create_test_results_directory
    check_prerequisites
    create_test_data
    test_mongodb_backup
    test_mongodb_restore
    verify_data_integrity
    test_pvc_backup_restore
    test_cluster_state_backup_restore
    test_backup_validation
    cleanup_test_resources
    generate_test_report
    
    print_success "Backup restore test completed successfully!"
    echo ""
    echo "🧪 Test Summary:"
    echo "   • Test Results Directory: $TEST_RESULTS_DIR"
    echo "   • Status: Completed successfully"
    echo "   • Ready for production deployment"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review test results and logs"
    echo "   2. Fix any issues found"
    echo "   3. Proceed with staged rollout"
    echo "   4. Monitor production deployment"
}

# Run main function
main "$@"
