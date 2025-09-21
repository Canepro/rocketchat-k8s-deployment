# 🎯 Portfolio Demo Access Guide

## 📊 Dashboard Access Options

### Option 1: Direct Public Dashboard
**URL:** `https://grafana.chat.canepro.me/d/public-rocketchat-overview`
- **View:** Full dashboard with navigation
- **Refresh:** Auto-refresh every 30 seconds
- **Interactive:** Users can zoom, select time ranges

### Option 2: Kiosk Mode (Recommended for Portfolio)
**URL:** `https://grafana.chat.canepro.me/d/public-rocketchat-overview?kiosk=tv&theme=dark`
- **View:** Full-screen without Grafana UI
- **Clean:** No navigation bars or menus
- **Professional:** Perfect for portfolio embedding

### Option 3: Embedded iframe
```html
<iframe 
  src="https://grafana.chat.canepro.me/d-solo/public-rocketchat-overview?orgId=1&refresh=30s&panelId=5&kiosk=tv&theme=dark"
  width="100%" 
  height="500" 
  frameborder="0"
  style="border-radius: 8px;">
</iframe>
```

## 💬 Chat Application Access

### Live Production Instance
**URL:** `https://chat.canepro.me`

**For Portfolio Visitors:**
1. **Guest Access:** Users can join as guests without registration
2. **Demo Channels:** Public channels available for exploration
3. **Features:** Real-time messaging, file sharing, emoji reactions

**Portfolio Button HTML:**
```html
<a href="https://chat.canepro.me" 
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
    <a href="https://chat.canepro.me" 
       class="btn-primary" 
       target="_blank">
      💬 Live Chat Demo
    </a>
    
    <a href="https://grafana.chat.canepro.me/d/public-rocketchat-overview?kiosk=tv" 
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
          onClick={() => openDemo('https://chat.canepro.me', 'chat_demo')}
          className="demo-btn primary">
          💬 Try Live Chat
        </button>
        
        <button 
          onClick={() => openDemo('https://grafana.chat.canepro.me/d/public-rocketchat-overview?kiosk=tv', 'dashboard_demo')}
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
  "https://grafana.chat.canepro.me/d/public-rocketchat-overview?kiosk=tv&theme=dark" \
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
