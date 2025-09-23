#!/bin/bash

# Re-enable Email Alerts
# Run this script when Gmail rate limiting has reset (usually within a few hours)

echo "📧 Re-enabling Email Alerts for Rocket.Chat Monitoring"
echo "=================================================="

# Re-enable email routing for critical and warning alerts
kubectl patch alertmanagerconfig rocketchat-alertmanager-config -n monitoring --type='merge' -p '{
  "spec": {
    "route": {
      "receiver": "rocketchat-webhook",
      "routes": [
        {
          "matchers": [{"name": "severity", "value": "critical"}],
          "receiver": "email-notifications",
          "continue": true
        },
        {
          "matchers": [{"name": "severity", "value": "warning"}],
          "receiver": "email-notifications",
          "continue": true
        }
      ]
    }
  }
}'

echo "✅ Email alerts re-enabled!"
echo ""
echo "📧 Alert Routing Now Active:"
echo "  • Critical alerts → Email + Rocket.Chat webhook"
echo "  • Warning alerts → Email + Rocket.Chat webhook"
echo "  • Info alerts → Rocket.Chat webhook only"
echo ""
echo "📬 Test email delivery:"
echo "  ./scripts/test-alerts.sh  # This will send both email and webhook"
echo ""
echo "⚠️  If Gmail rate limiting occurs again, run this script again in a few hours"
