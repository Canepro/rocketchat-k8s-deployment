#!/bin/bash
# Quick Cost Optimization Script
# Reduces replicas for MongoDB, NATS, and DDP Streamer

set -euo pipefail

NAMESPACE="rocketchat"

echo "💰 Rocket.Chat Cost Optimization Script"
echo "======================================"
echo ""

# Check current status
echo "📊 Current deployment status:"
kubectl get pods -n $NAMESPACE | grep -E "mongodb|nats|ddp-streamer" || true
echo ""

# Ask for confirmation
read -p "Reduce MongoDB replicas? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "  MongoDB replicas (1 or 2, default 1): " MONGODB_REPLICAS
    MONGODB_REPLICAS=${MONGODB_REPLICAS:-1}
    
    CURRENT_REPLICAS=$(kubectl get statefulset mongodb -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$MONGODB_REPLICAS" -lt "$CURRENT_REPLICAS" ]; then
        echo "  Scaling MongoDB from $CURRENT_REPLICAS to $MONGODB_REPLICAS replica(s)..."
        kubectl scale statefulset mongodb --replicas=$MONGODB_REPLICAS -n $NAMESPACE
        
        echo "  Waiting for pods to terminate..."
        sleep 10
        
        echo "  Fixing MongoDB replica set configuration..."
        kubectl exec mongodb-0 -n $NAMESPACE -- mongosh --quiet --eval "
            cfg = rs.conf();
            cfg.members = [{_id: 0, host: 'mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017', priority: 2}];
            cfg.version = cfg.version + 1;
            rs.reconfig(cfg, {force: true});
            print('Replica set reconfigured');
        " 2>/dev/null || echo "  ⚠️  Replica set reconfiguration may need manual intervention"
        
        echo "  Restarting Rocket.Chat pods to reconnect..."
        kubectl rollout restart deployment/rocketchat-stream-hub -n $NAMESPACE
        kubectl rollout restart deployment/rocketchat-rocketchat -n $NAMESPACE
        
        echo "  ✅ MongoDB scaled and replica set reconfigured"
    else
        echo "  Scaling MongoDB to $MONGODB_REPLICAS replica(s)..."
        kubectl scale statefulset mongodb --replicas=$MONGODB_REPLICAS -n $NAMESPACE
        echo "  ✅ MongoDB scaled"
    fi
fi

read -p "Reduce NATS replicas to 1? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Scaling NATS to 1 replica..."
    kubectl scale statefulset rocketchat-nats --replicas=1 -n $NAMESPACE
    echo "  ✅ NATS scaled"
fi

read -p "Reduce DDP Streamer replicas to 1? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Scaling DDP Streamer to 1 replica..."
    kubectl scale deployment rocketchat-ddp-streamer --replicas=1 -n $NAMESPACE
    echo "  ✅ DDP Streamer scaled"
fi

echo ""
echo "⏳ Waiting for pods to stabilize (30 seconds)..."
sleep 30

echo ""
echo "📊 Updated deployment status:"
kubectl get pods -n $NAMESPACE | grep -E "mongodb|nats|ddp-streamer" || true

echo ""
echo "✅ Cost optimization complete!"
echo ""
echo "💡 Tips:"
echo "  - Monitor pods: kubectl get pods -n $NAMESPACE"
echo "  - Check resource usage: kubectl top pods -n $NAMESPACE"
echo "  - Test Rocket.Chat: curl -I https://<YOUR_DOMAIN>"
echo ""
echo "🔄 To rollback, use:"
echo "  kubectl scale statefulset mongodb --replicas=3 -n $NAMESPACE"
echo "  kubectl scale statefulset rocketchat-nats --replicas=2 -n $NAMESPACE"
echo "  kubectl scale deployment rocketchat-ddp-streamer --replicas=2 -n $NAMESPACE"

