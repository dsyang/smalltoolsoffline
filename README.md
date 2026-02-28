# Small Tools Offline

Offline viewer for [code.imdaniel.fyi](https://code.imdaniel.fyi) tools with iOS Shortcuts and Quick Actions.

## Features

- **Offline sync**: Download all self-contained HTML tools for offline viewing
- **Quick Actions**: Long-press the app icon to jump directly to a saved tool (up to 4)
- **Siri Shortcuts**: "Open Currency Converter in Small Tools" — works with Siri, Spotlight, and the Shortcuts app

## Setup

```bash
# 1. Install dependencies
npm install

# 2. Add platforms
npx cap add ios
npx cap add android

# 3. Sync web assets
npx cap sync

# 4. Open Xcode
npx cap open ios
```

## Xcode Configuration (required for Shortcuts)

After `npx cap open ios`, do the following in Xcode:

### 1. Register the URL scheme

Go to your app target → **Info** → **URL Types** → click **+**:

| Field        | Value          |
|-------------|----------------|
| Identifier  | `fyi.imdaniel.smalltools` |
| URL Schemes | `smalltools`   |
| Role        | Editor         |

This enables `smalltools://open/{slug}` deep links.

### 2. Add the App Intents file

Copy `ios-native/OpenToolIntent.swift` into `ios/App/App/` in Xcode:

- Right-click the `App` folder in Xcode's navigator
- **Add Files to "App"…**
- Select `OpenToolIntent.swift`
- Make sure **"Copy items if needed"** is checked
- Target membership: **App** ✓

### 3. Update AppDelegate.swift

In `ios/App/App/AppDelegate.swift`, add URL handling so Capacitor receives the deep link when launched from a Siri Shortcut:

```swift
import UIKit
import Capacitor
import CapawesomeCapacitorAppShortcuts  // add this import

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // ... existing code ...

    // ADD: Handle URL scheme launches (Siri Shortcuts deep links)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    // ADD: Handle quick action launches (home screen long-press)
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        AppShortcutsPlugin.handleShortcutItem(shortcutItem)
        completionHandler(true)
    }
}
```

### 4. Build & run

Select your device/simulator and hit **Run (⌘R)**.

## How it all connects

```
┌─────────────────────────────────────────────────┐
│ Siri / Shortcuts app / Spotlight                │
│  "Open Currency Converter in Small Tools"       │
│                    │                            │
│         OpenToolIntent.perform()                │
│                    │                            │
│     UIApplication.open(smalltools://open/currency)
│                    │                            │
├────────────────────┼────────────────────────────┤
│                    ▼                            │
│  Capacitor @capacitor/app                       │
│    appUrlOpen event → parse slug                │
│                    │                            │
│              openTool('currency')               │
│                    │                            │
│    @capacitor/filesystem → load HTML            │
│                    │                            │
│             iframe srcdoc = html                │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Home Screen Long-Press (Quick Actions)          │
│                    │                            │
│  @capawesome/capacitor-app-shortcuts            │
│    'click' event → parse slug                   │
│                    │                            │
│              openTool('currency')               │
└─────────────────────────────────────────────────┘
```

## Adding new tools

1. Add an entry to `TOOLS` in `www/index.html`
2. Add a matching `ToolEntity` in `OpenToolIntent.swift`
3. Rebuild

## Browser testing

Open `www/index.html` directly — uses localStorage instead of Capacitor Filesystem.
Quick Actions and Deep Links are no-ops in the browser.

## Project structure

```
├── capacitor.config.ts
├── package.json
├── www/
│   └── index.html              # Entire web app
├── ios-native/
│   └── OpenToolIntent.swift    # Copy into ios/App/App/ in Xcode
└── README.md
```
