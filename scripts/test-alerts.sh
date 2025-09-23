#!/bin/bash

# Test Rocket.Chat Alerts
# This script sends test alerts to verify webhook delivery to Rocket.Chat

echo "🧪 Testing Rocket.Chat Alert System"
echo "=================================="

# Test 1: Performance Alert
echo "📊 Test 1: Sending performance alert..."
kubectl exec -n monitoring pod/alertmanager-monitoring-kube-prometheus-alertmanager-0 -- \
  amtool --alertmanager.url=http://localhost:9093 alert add \
  alertname=RocketChatHighCPU \
  severity=warning \
  'message="Test: High CPU usage detected (>80% for 15 minutes)"'

# Test 2: Error Alert
echo "🚨 Test 2: Sending error alert..."
kubectl exec -n monitoring pod/alertmanager-monitoring-kube-prometheus-alertmanager-0 -- \
  amtool --alertmanager.url=http://localhost:9093 alert add \
  alertname=RocketChatContainerRestartsHigh \
  severity=critical \
  'message="Test: Container restart rate high (3+ restarts in 10 minutes)"'

# Test 3: OOM Alert
echo "💥 Test 3: Sending OOM alert..."
kubectl exec -n monitoring pod/alertmanager-monitoring-kube-prometheus-alertmanager-0 -- \
  amtool --alertmanager.url=http://localhost:9093 alert add \
  alertname=RocketChatOOMKills \
  severity=critical \
  'message="Test: Out of memory kill detected"'

echo ""
echo "✅ Test alerts sent!"
echo "📱 Check your Rocket.Chat #alerts channel for webhook notifications"
echo ""
echo "🔍 Alert Types Tested:"
echo "  • Performance alerts (CPU, memory)"
echo "  • Error alerts (restarts, OOM)"
echo "  • Critical alerts (immediate attention)"
echo ""
echo "📊 Expected Results in Rocket.Chat:"
echo "  • Alert messages posted by webhook bot"
echo "  • Proper formatting with severity indicators"
echo "  • Links to troubleshooting documentation"
