#!/bin/bash
# Fix MongoDB Replica Set Configuration After Scaling Down
# This script reconfigures the replica set to work with fewer members

set -euo pipefail

NAMESPACE="rocketchat"
MONGO_POD="mongodb-0"

echo "🔧 Fixing MongoDB Replica Set Configuration"
echo "=========================================="
echo ""

# Check current MongoDB pods
echo "📊 Current MongoDB pods:"
kubectl get pods -n $NAMESPACE | grep mongodb | grep -v exporter
echo ""

# Get current replica set status
echo "📋 Current replica set status:"
kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr))" 2>/dev/null || echo "Could not get replica set status"
echo ""

# Check if mongodb-0 is the primary
PRIMARY=$(kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "rs.isMaster().primary" 2>/dev/null || echo "")

if [ -z "$PRIMARY" ] || [ "$PRIMARY" == "null" ]; then
    echo "⚠️  No primary found. Reconfiguring replica set..."
    
    echo ""
    echo "Step 1: Checking if mongodb-0 is standalone..."
    kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
        try {
            rs.status();
            print('Replica set exists');
        } catch(e) {
            print('Not in replica set mode');
        }
    " 2>/dev/null
    
    echo ""
    echo "Step 2: Reconfiguring replica set to single member..."
    
    # Reconfigure to single member (mongodb-0 only)
    kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
        cfg = rs.conf();
        cfg.members = [cfg.members.find(m => m.host.includes('mongodb-0'))];
        cfg.version = cfg.version + 1;
        rs.reconfig(cfg, {force: true});
        print('Replica set reconfigured to single member');
    " 2>/dev/null || {
        echo "⚠️  Reconfiguration failed. Attempting alternative method..."
        
        # Alternative: Remove all members and add only mongodb-0
        kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
            cfg = rs.conf();
            cfg.members = [{_id: 0, host: 'mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017'}];
            cfg.version = cfg.version + 1;
            rs.reconfig(cfg, {force: true});
            print('Replica set reconfigured using alternative method');
        " 2>/dev/null || echo "❌ Reconfiguration failed. Manual intervention may be needed."
    }
    
    echo ""
    echo "Step 3: Waiting for replica set to stabilize..."
    sleep 10
    
    echo ""
    echo "Step 4: Verifying replica set status:"
    kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
        try {
            status = rs.status();
            print('Replica set members:');
            status.members.forEach(m => print('  - ' + m.name + ': ' + m.stateStr));
            print('');
            print('Primary: ' + rs.isMaster().primary);
        } catch(e) {
            print('Error getting status: ' + e.message);
        }
    " 2>/dev/null
    
else
    echo "✅ Primary found: $PRIMARY"
    echo ""
    echo "Reconfiguring replica set to remove non-existent members..."
    
    kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
        cfg = rs.conf();
        cfg.members = cfg.members.filter(m => m.host.includes('mongodb-0'));
        cfg.version = cfg.version + 1;
        rs.reconfig(cfg, {force: true});
        print('Replica set reconfigured');
    " 2>/dev/null
fi

echo ""
echo "✅ Replica set reconfiguration complete!"
echo ""
echo "📊 Final status:"
kubectl exec -it $MONGO_POD -n $NAMESPACE -- mongosh --quiet --eval "
    try {
        status = rs.status();
        print('Members:');
        status.members.forEach(m => print('  - ' + m.name + ': ' + m.stateStr));
        print('Primary: ' + rs.isMaster().primary);
    } catch(e) {
        print('Status: ' + e.message);
    }
" 2>/dev/null

echo ""
echo "💡 Next steps:"
echo "  1. Restart Rocket.Chat pods to reconnect to MongoDB:"
echo "     kubectl rollout restart deployment/rocketchat-rocketchat -n $NAMESPACE"
echo "  2. Restart stream-hub if it's still crashing:"
echo "     kubectl rollout restart deployment/rocketchat-stream-hub -n $NAMESPACE"
echo "  3. Monitor pods: kubectl get pods -n $NAMESPACE"

