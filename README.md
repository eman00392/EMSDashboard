# 🚑 EMSDashboard — iOS + CarPlay App

Real-time EMS dispatch display for Active911 alerts, with CarPlay support.
Connects to your existing Node.js server via Socket.IO.

---

## Before You Open Xcode

### 1. Apple Developer Account
- Enroll at https://developer.apple.com/account ($99/year)

### 2. Request CarPlay Entitlement
- Go to https://developer.apple.com/carplay
- Select: **Communication App**
- Takes 2–5 business days to approve

---

## Setup Steps in Xcode

### Step 1 — Open the Project
- Open `EMSDashboard.xcodeproj` in Xcode
- Sign in to your Apple Developer account:
  Xcode → Settings → Accounts → + → Apple ID

### Step 2 — Set Your Team & Bundle ID
- Click the project name in the navigator (top left)
- Select target: **EMSDashboard**
- Signing & Capabilities tab:
  - Team: Select your developer account
  - Bundle Identifier: `com.YOURSTATION.emsdashboard`
    (e.g. `com.eastchesterems.dashboard`)

### Step 3 — Add Socket.IO Package
- File → Add Package Dependencies
- Paste: `https://github.com/socketio/socket.io-client-swift`
- Version: Up to Next Major from 16.0.0
- Add to target: EMSDashboard

### Step 4 — Set Your Server IP
- Open `EMSSocketManager.swift`
- Replace `YOUR_SERVER_IP` with your server's address:
  ```swift
  private let serverURL = "http://192.168.1.100:3000"
  ```

- Open `AppDelegate.swift`
- Replace `YOUR_SERVER_IP` in the APNs registration URL too

### Step 5 — Add CarPlay Capability
- Signing & Capabilities tab → + Capability → CarPlay
- Xcode will link the `.entitlements` file automatically

### Step 6 — Add Background Modes Capability
- Signing & Capabilities → + Capability → Background Modes
- Check: ✅ Audio (keeps socket alive in background)
- Check: ✅ Remote notifications

---

## Testing Without a Car

1. Run the app on your iPhone or iOS Simulator (⌘R)
2. In Xcode menu: **I/O → External Displays → CarPlay**
3. A second CarPlay window appears
4. Trigger a test call:
   ```bash
   curl -X POST http://YOUR_SERVER_IP:3000/test-call
   ```
5. The CarPlay screen should update immediately
6. Clear the call:
   ```bash
   curl -X POST http://YOUR_SERVER_IP:3000/clear-call
   ```

---

## File Overview

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | App launch, socket start, APNs registration |
| `SceneDelegate.swift` | iPhone window setup |
| `ViewController.swift` | iPhone UI — live call display |
| `CarPlaySceneDelegate.swift` | CarPlay screen controller |
| `DashboardTemplate.swift` | Builds CPListTemplate for CarPlay |
| `CallDataModel.swift` | Shared live data (call + connection status) |
| `EMSSocketManager.swift` | Socket.IO connection to server.js |
| `NotificationManager.swift` | Critical push alerts |
| `Info.plist` | App config, scene routing, permissions |
| `EMSDashboard.entitlements` | CarPlay + APNs entitlements |

---

## CarPlay Screen Layout

```
┌─────────────────────────────┐
│  🚑 EMS Dashboard           │
├─────────────────────────────┤
│  🚨 ACTIVE CALL             │
│  27 GRANT ST TUCKAHOE       │
│  STRUCTURE FIRE             │
├─────────────────────────────┤
│  🚒 Units                   │
│  M-1, E-52, L-7            │
├─────────────────────────────┤
│  PATIENT                    │
│  🧑‍⚕️ Patient               │
│  85F · Conscious · Breathing│
├─────────────────────────────┤
│  ACTIONS                    │
│  ℹ️  Full Call Details      │
│  🗺  Navigate to Scene      │
└─────────────────────────────┘
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| CarPlay screen blank | Check Info.plist scene config matches exactly |
| Socket won't connect | Phone and server must be on same network |
| "Missing entitlement" crash | Wait for Apple CarPlay entitlement approval |
| App disconnects in background | Ensure Background Modes → Audio is enabled |
| Notifications silent | Critical alerts need special APNs entitlement |

---

## Server-Side: Register for Push Notifications

Add to your `server.js` to receive device tokens:

```javascript
let deviceTokens = [];

app.post('/register-device', (req, res) => {
  const { token } = req.body;
  if (token && !deviceTokens.includes(token)) {
    deviceTokens.push(token);
    console.log('Registered device token:', token);
  }
  res.json({ success: true });
});
```

---

Built for Eastchester EMS · Powered by Active911 + Socket.IO
