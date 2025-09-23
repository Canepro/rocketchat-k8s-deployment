#!/bin/bash

# Apply Secrets from .env file to Kubernetes
# This script populates Kubernetes secrets with credentials from your local .env file
# Usage: ./scripts/apply-secrets.sh

set -e

# Load environment variables from .env file
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create a .env file with your credentials."
    echo "See .env.example for the required format."
    exit 1
fi

# Load the .env file
set -a
source .env
set +a

echo "🔐 Applying secrets from .env file to Kubernetes..."

# Validate required environment variables
if [ -z "$GMAIL_USERNAME" ] || [ -z "$GMAIL_APP_PASSWORD" ]; then
    echo "❌ Error: GMAIL_USERNAME and GMAIL_APP_PASSWORD are required in .env"
    exit 1
fi

if [ -z "$ROCKETCHAT_WEBHOOK_URL" ]; then
    echo "❌ Error: ROCKETCHAT_WEBHOOK_URL is required in .env"
    exit 1
fi

if [ -z "$ALERT_EMAIL_RECIPIENT" ]; then
    echo "❌ Error: ALERT_EMAIL_RECIPIENT is required in .env"
    exit 1
fi

echo "✅ Environment variables loaded successfully"

# Apply SMTP secret
echo "📧 Updating SMTP secret..."
kubectl patch secret alertmanager-smtp -n monitoring \
  --type='merge' \
  -p="{\"data\":{\"username\":\"$(echo -n "$GMAIL_USERNAME" | base64)\",\"password\":\"$(echo -n "$GMAIL_APP_PASSWORD" | base64)\"}}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply AlertmanagerConfig with real webhook URL and email
echo "🚨 Updating Alertmanager configuration..."
kubectl patch alertmanagerconfig rocketchat-alertmanager-config -n monitoring \
  --type='merge' \
  -p="{
    \"spec\": {
      \"receivers\": [
        {
          \"name\": \"email-notifications\",
          \"emailConfigs\": [
            {
              \"to\": \"$ALERT_EMAIL_RECIPIENT\",
              \"authUsername\": \"$GMAIL_USERNAME\"
            }
          ]
        },
        {
          \"name\": \"rocketchat-webhook\",
          \"webhookConfigs\": [
            {
              \"url\": \"$ROCKETCHAT_WEBHOOK_URL\"
            }
          ]
        }
      ]
    }
  }" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets applied successfully!"
echo ""
echo "🔍 Verification:"
echo "SMTP Secret:"
kubectl get secret alertmanager-smtp -n monitoring -o jsonpath='{.data.username}' | base64 -d
echo ""
echo "Alertmanager Config:"
kubectl get alertmanagerconfig rocketchat-alertmanager-config -n monitoring -o yaml | grep -E "(to:|url:)" | head -4

echo ""
echo "🎉 Your monitoring secrets are now configured!"
echo "📧 Email alerts will be sent to: $ALERT_EMAIL_RECIPIENT"
echo "💬 Rocket.Chat alerts will be sent to your webhook"
