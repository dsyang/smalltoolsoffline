# Small Tools Offline

## Product Spec

Always reference [PRODUCT.md](PRODUCT.md) before making changes. This document is the source of truth for app behavior and must be kept in sync with any feature changes. When adding or modifying functionality, update PRODUCT.md to reflect the new behavior.

## Architecture

- **iOS:** SwiftUI app in `ios-native/SmallTools/`. Uses `@Observable` ToolStore, NavigationStack, and AppIntents.
- **Android:** Jetpack Compose app in `android-native/`. Uses ViewModel with StateFlow, Compose Navigation, and Glance widgets.
- **Manifest:** Both apps fetch tools from `https://code.imdaniel.fyi/assets.json`.

## Cross-Platform Parity

Both apps should behave identically per PRODUCT.md. When making a change to one platform, check if the same change is needed on the other. Platform-specific features are explicitly marked in the product spec.
