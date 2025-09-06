# 🚀 Quick Loki Log Access Guide

## 1️⃣ **Getting Started (Copy & Paste These)**

### All Rocket.Chat Logs:
```
{namespace="rocketchat"}
```

### Only Error Logs:
```
{namespace="rocketchat"} |= "error"
```

### Logs from Last Hour:
```
{namespace="rocketchat"} [1h]
```

### Specific Component Logs:
```
{pod=~"rocketchat-rocketchat.*"}
```

## 2️⃣ **What You'll See**
- Real-time logs from all Rocket.Chat components
- WebSocket connection logs (ddp-streamer)
- API request logs
- Database interaction logs
- Error messages and debugging info

## 3️⃣ **Tips**
- Use the time picker (top right) to set time range
- Click "Live" for real-time log streaming
- Click on log lines to expand details
- Use | (pipe) to filter: `{namespace="rocketchat"} |= "login"`
