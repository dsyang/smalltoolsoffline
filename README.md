# Small Tools Offline

Native iOS and Android app for downloading and viewing [code.imdaniel.fyi](https://code.imdaniel.fyi) tools offline.

## Features

- **Offline sync**: Download self-contained HTML tools for offline viewing
- **Drag to reorder**: Customize tool order with persistent drag-and-drop
- **Deep linking**: `smalltools://open/{slug}` to jump directly to a tool
- **iOS Quick Actions**: Long-press the app icon to launch a saved tool
- **iOS Siri Shortcuts**: "Open Currency Converter in Small Tools"
- **Android Home Screen Widget**: Pin a tool to the home screen for one-tap access

## Project Structure

```
├── ios-native/SmallTools/    # SwiftUI app (Xcode / XcodeGen)
├── android-native/           # Jetpack Compose app (Gradle)
├── PRODUCT.md                # Product specification (source of truth)
└── CLAUDE.md                 # AI assistant instructions
```

## iOS

Open `ios-native/SmallTools/SmallTools.xcodeproj` in Xcode and run.

The project can also be regenerated from `ios-native/SmallTools/project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Android

Open `android-native/` in Android Studio and run.

## How It Works

Both apps fetch a tool manifest from `https://code.imdaniel.fyi/assets.json`, download individual HTML tool files, verify integrity via SHA256, and display them in a WebView. See [PRODUCT.md](PRODUCT.md) for the full specification.
