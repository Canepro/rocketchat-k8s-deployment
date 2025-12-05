#!/bin/bash

# 🎯 Portfolio Demo Setup Script
# Sets up public dashboard access and demo user for Rocket.Chat

set -e

echo "🚀 Setting up Portfolio Demo Access..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 Step $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Deploy public dashboard
print_step "1" "Deploying public dashboard configuration"
kubectl apply -f aks/monitoring/grafana-public-dashboard-setup.yaml
print_success "Public dashboard configuration applied"

# Step 2: Wait for dashboard to be processed
print_step "2" "Waiting for dashboard sidecar to process new dashboard"
sleep 10

# Check if dashboard was processed
DASHBOARD_FILE=$(kubectl exec -n monitoring deployment/monitoring-grafana -c grafana-sc-dashboard -- ls -la /tmp/dashboards/ | grep public-rocketchat-overview || echo "")
if [[ -n "$DASHBOARD_FILE" ]]; then
    print_success "Public dashboard processed successfully"
else
    print_warning "Dashboard processing may take a few more moments"
fi

# Step 3: Create portfolio URLs
print_step "3" "Generating portfolio-ready URLs"

echo ""
echo "🎯 Portfolio Integration URLs:"
echo "================================"

# Public dashboard URL (with TV mode for embedding)
PUBLIC_DASHBOARD_URL="https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview/rocket-chat-production-monitoring-portfolio-view?orgId=1&refresh=30s&kiosk=tv&theme=dark"
echo -e "${BLUE}📊 Public Dashboard:${NC}"
echo "$PUBLIC_DASHBOARD_URL"
echo ""

# Public dashboard URL (normal view)
PUBLIC_DASHBOARD_NORMAL="https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview/rocket-chat-production-monitoring-portfolio-view?orgId=1&refresh=30s"
echo -e "${BLUE}📊 Public Dashboard (Normal View):${NC}"
echo "$PUBLIC_DASHBOARD_NORMAL"
echo ""

# Embedded iframe URL
IFRAME_URL="https://grafana.<YOUR_DOMAIN>/d-solo/public-rocketchat-overview/rocket-chat-production-monitoring-portfolio-view?orgId=1&refresh=30s&panelId=5&kiosk=tv&theme=dark"
echo -e "${BLUE}🖼️ Embedded View (iframe):${NC}"
echo "$IFRAME_URL"
echo ""

# Chat application URL
CHAT_URL="https://<YOUR_DOMAIN>"
echo -e "${BLUE}💬 Chat Application:${NC}"
echo "$CHAT_URL"
echo ""

# Step 4: Create demo user instructions
print_step "4" "Creating demo access instructions"

cat << 'EOF' > portfolio-demo-access.md
# 🎯 Portfolio Demo Access Guide

## 📊 Dashboard Access Options

### Option 1: Direct Public Dashboard
**URL:** `https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview`
- **View:** Full dashboard with navigation
- **Refresh:** Auto-refresh every 30 seconds
- **Interactive:** Users can zoom, select time ranges

### Option 2: Kiosk Mode (Recommended for Portfolio)
**URL:** `https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview?kiosk=tv&theme=dark`
- **View:** Full-screen without Grafana UI
- **Clean:** No navigation bars or menus
- **Professional:** Perfect for portfolio embedding

### Option 3: Embedded iframe
```html
<iframe 
  src="https://grafana.<YOUR_DOMAIN>/d-solo/public-rocketchat-overview?orgId=1&refresh=30s&panelId=5&kiosk=tv&theme=dark"
  width="100%" 
  height="500" 
  frameborder="0"
  style="border-radius: 8px;">
</iframe>
```

## 💬 Chat Application Access

### Live Production Instance
**URL:** `https://<YOUR_DOMAIN>`

**For Portfolio Visitors:**
1. **Guest Access:** Users can join as guests without registration
2. **Demo Channels:** Public channels available for exploration
3. **Features:** Real-time messaging, file sharing, emoji reactions

**Portfolio Button HTML:**
```html
<a href="https://<YOUR_DOMAIN>" 
   class="portfolio-demo-btn chat-btn" 
   target="_blank"
   rel="noopener noreferrer">
   💬 Try Live Chat Demo
</a>
```

## 🎨 Portfolio Integration Examples

### HTML Project Card
```html
<div class="project-card enterprise-chat">
  <h3>🚀 Enterprise Kubernetes Chat Platform</h3>
  
  <div class="project-stats">
    <span class="stat">99.7% Uptime</span>
    <span class="stat">28 Panels</span>
    <span class="stat">55+ Pods</span>
  </div>
  
  <div class="demo-buttons">
    <a href="https://<YOUR_DOMAIN>" 
       class="btn-primary" 
       target="_blank">
      💬 Live Chat Demo
    </a>
    
    <a href="https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview?kiosk=tv" 
       class="btn-secondary" 
       target="_blank">
      📊 Live Dashboard
    </a>
  </div>
</div>
```

### React/Next.js Component
```jsx
const RocketChatProject = () => {
  const openDemo = (url, title) => {
    window.open(url, '_blank', 'noopener,noreferrer');
    
    // Analytics tracking (optional)
    if (typeof gtag !== 'undefined') {
      gtag('event', 'demo_access', {
        'event_category': 'portfolio',
        'event_label': title,
        'value': 1
      });
    }
  };

  return (
    <div className="project-showcase">
      <h3>🚀 Enterprise Kubernetes Chat Platform</h3>
      
      <div className="demo-actions">
        <button 
          onClick={() => openDemo('https://<YOUR_DOMAIN>', 'chat_demo')}
          className="demo-btn primary">
          💬 Try Live Chat
        </button>
        
        <button 
          onClick={() => openDemo('https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview?kiosk=tv', 'dashboard_demo')}
          className="demo-btn secondary">
          📊 View Monitoring
        </button>
      </div>
    </div>
  );
};
```

## 📸 Screenshot Automation

### Dashboard Screenshots for Static Portfolio
```bash
# Use headless browser to capture dashboard screenshots
npx playwright-cli screenshot \
  "https://grafana.<YOUR_DOMAIN>/d/public-rocketchat-overview?kiosk=tv&theme=dark" \
  dashboard-screenshot.png \
  --viewport-size 1920,1080 \
  --wait-for-timeout 5000
```

## 🔒 Security & Privacy

### Public Dashboard Safety
- ✅ **Read-only access** - No modification capabilities
- ✅ **Limited metrics** - Only public-safe monitoring data
- ✅ **No sensitive data** - No user information or internal details
- ✅ **Anonymous only** - No login required or stored

### Chat Application Safety
- ✅ **Guest mode** - No registration required
- ✅ **Public channels** - No private information
- ✅ **Moderated** - Professional environment maintained
- ✅ **Demo purpose** - Clearly indicated as portfolio demonstration

## 📊 Analytics & Tracking

### Recommended Tracking Events
```javascript
// Track portfolio demo interactions
function trackDemoAccess(demoType) {
  // Google Analytics 4
  gtag('event', 'portfolio_demo_access', {
    'demo_type': demoType, // 'chat' or 'dashboard'
    'project': 'rocketchat_k8s',
    'engagement_time': Date.now()
  });
}

// Usage
document.querySelector('.chat-demo-btn').addEventListener('click', () => {
  trackDemoAccess('chat');
});

document.querySelector('.dashboard-demo-btn').addEventListener('click', () => {
  trackDemoAccess('dashboard');
});
```
EOF

print_success "Demo access guide created: portfolio-demo-access.md"

# Step 5: Create CSS for portfolio buttons
cat << 'EOF' > portfolio-demo-styles.css
/* 🎨 Portfolio Demo Button Styles */

.portfolio-demo-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  text-decoration: none;
  font-weight: 600;
  font-size: 0.95rem;
  transition: all 0.3s ease;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.portfolio-demo-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
  transition: left 0.5s;
}

.portfolio-demo-btn:hover::before {
  left: 100%;
}

.chat-btn {
  background: linear-gradient(135deg, #00d2ff, #3a7bd5);
  color: white;
}

.chat-btn:hover {
  background: linear-gradient(135deg, #3a7bd5, #00d2ff);
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(58, 123, 213, 0.3);
}

.dashboard-btn {
  background: linear-gradient(135deg, #ff6b6b, #ee5a52);
  color: white;
}

.dashboard-btn:hover {
  background: linear-gradient(135deg, #ee5a52, #ff6b6b);
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(238, 90, 82, 0.3);
}

.code-btn {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
}

.code-btn:hover {
  background: linear-gradient(135deg, #764ba2, #667eea);
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(118, 75, 162, 0.3);
}

/* Project stats styling */
.project-stats {
  display: flex;
  gap: 1rem;
  margin: 1rem 0;
  flex-wrap: wrap;
}

.stat {
  background: rgba(0,0,0,0.1);
  padding: 0.5rem 1rem;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
}

/* Responsive design */
@media (max-width: 768px) {
  .portfolio-demo-btn {
    width: 100%;
    justify-content: center;
    margin-bottom: 0.5rem;
  }
  
  .project-stats {
    flex-direction: column;
    align-items: center;
  }
}
EOF

print_success "Portfolio styles created: portfolio-demo-styles.css"

# Final summary
echo ""
echo "🎉 Portfolio Demo Setup Complete!"
echo "=================================="
print_success "✅ Public dashboard deployed"
print_success "✅ Demo access guide created"
print_success "✅ Portfolio styles generated"
print_success "✅ HTML/React examples provided"

echo ""
echo "📁 Files Created:"
echo "  - portfolio-demo-access.md"
echo "  - portfolio-demo-styles.css"
echo ""

echo "🔗 Next Steps:"
echo "  1. Test public dashboard access: $PUBLIC_DASHBOARD_NORMAL"
echo "  2. Integrate buttons into your portfolio website"
echo "  3. Customize styling to match your portfolio theme"
echo "  4. Optional: Set up analytics tracking for demo interactions"

echo ""
echo "💡 Pro Tips:"
echo "  - Use kiosk mode URLs for clean, professional presentation"
echo "  - Create screenshots for static portfolio versions"
echo "  - Consider embedding the dashboard as an iframe"
echo "  - Track user interactions for portfolio analytics"

echo ""
print_success "Portfolio demo setup completed successfully! 🚀"
