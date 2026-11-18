# Small Tools — Product Specification

Small Tools is a cross-platform mobile app for downloading and viewing self-contained HTML tools offline. Tools are fetched from a remote manifest and stored locally for offline use.

Both iOS and Android apps must implement all features described in this document unless marked as platform-specific.

## Remote API

### Manifest

- **URL:** `https://code.imdaniel.fyi/assets.json`
- **Format:** `{ "tools": [{ "title", "description", "path", "sha256", "file_size_bytes", "assets" }] }`
- Each tool entry includes a SHA256 hash for integrity verification and an optional file size in bytes.
- Each tool entry includes an `assets` array of additional files the tool depends on (e.g. images). Each asset has `path`, `sha256`, and optional `file_size_bytes`. The array may be empty or absent (older manifests).
- Tool files and assets are downloaded from `https://code.imdaniel.fyi/{path}`.

## Data Model

A **Tool** has:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Display name |
| `description` | string | Short description |
| `path` | string | Relative path on CDN (e.g. `tools/2048.html`) |
| `sha256` | string | Hex-encoded SHA256 hash of the file contents |
| `file_size_bytes` | int? | Optional file size for display |
| `assets` | Asset[] | Additional dependent files (images, etc.); empty by default |

An **Asset** has:

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path on CDN (e.g. `tools/allergy-icons/egg.png`) |
| `sha256` | string | Hex-encoded SHA256 hash of the file contents |
| `file_size_bytes` | int? | Optional file size |

Derived properties:

- **id / slug**: The filename without extension (e.g. `tools/2048.html` -> `2048`). Used as the stable identifier throughout the app.
- **filename**: The last path component (e.g. `2048.html`).
- **download URL**: `https://code.imdaniel.fyi/{path}`.

## Screens

### Tool List (Home)

The main screen shows all tools from the manifest in a scrollable list.

**Title:** "Small Tools" — displayed as a large/prominent title (not inline).

**List items (Tool Row):**

- Primary text: tool title.
- Secondary text: human-readable file size (e.g. "42 KB") if `file_size_bytes` is present.
- Trailing status icon indicating download state:
  - **Downloading:** spinner/progress indicator.
  - **Outdated:** orange refresh icon. Tappable to trigger re-download.
  - **Downloaded (up to date):** green checkmark.
  - **Not downloaded:** gray/secondary download arrow.

**Interactions:**

- **Tap row:** navigate to the Tool Viewer for that tool.
- **Pull to refresh:** fetch the latest manifest from the server (bypassing HTTP cache) and update the list. This also triggers cleanup of removed tools (see [Removed Tool Cleanup](#removed-tool-cleanup)).
- **Swipe to delete (trailing):** only shown for tools that have a local file. Deletes the downloaded file but keeps the tool in the list.
- **Drag to reorder:** user can reorder tools in the list. The custom order is persisted across app launches. New tools from the manifest that aren't in the saved order are appended to the end.

**Empty states:**

- If fetching manifest and no cached tools: show a loading indicator with "Loading tools..." text.
- If manifest loaded but empty: show a placeholder message prompting the user to pull to refresh.

**On appear / launch:**

- Fetch the manifest (using cached version immediately if available, then updating from network).
- Warm the WebView pool (see [WebView Pool](#webview-pool)).

### Tool Viewer

Displays a downloaded tool's HTML in a full-screen WebView.

**Behavior:**

- On open, if the tool is not yet downloaded, automatically download it and show a loading state ("Downloading {name}...").
- If download fails, show an error state.
- Once the file is available locally, load it in the WebView from the local filesystem.
- A floating back button (top-left, with a translucent/material background) allows returning to the list.
- The native navigation bar is hidden — the tool's HTML content occupies the full screen.

## Manifest Fetching

- The manifest is fetched on app launch and on pull-to-refresh.
- **Cache bypass:** manifest requests must ignore the HTTP cache (`reloadIgnoringLocalCacheData` / equivalent) to always get the latest version from the server.
- **Local cache:** after a successful fetch, the manifest JSON is saved to local storage so it can be loaded immediately on next launch without network.
- **Failure handling:** if the network request fails, the app continues using the cached manifest silently.

## Download & Storage

### Local file storage

- Downloaded tool HTML files are stored in a `tools/` subdirectory of the app's documents/files directory.
- Tool assets are stored mirroring the CDN's directory structure relative to the `tools/` root (e.g. CDN `tools/allergy-icons/egg.png` is stored at `tools/allergy-icons/egg.png` in the app directory). This ensures relative references in the tool's HTML (e.g. `<img src="allergy-icons/egg.png">`) resolve correctly when loaded from the local filesystem.
- The cached manifest is stored alongside this directory as `manifest.json`.

### Asset downloads

- When a tool is downloaded for offline use, all of its assets are downloaded as well. Assets for a tool download concurrently.
- Deleting a tool's local file also deletes its downloaded assets.

### SHA256 integrity

- After downloading a tool, or when scanning existing files, the app computes the SHA256 hash of the file contents and compares it to the manifest's `sha256` value.
- A tool is considered up to date only when its HTML file **and every one of its assets** exist locally and match their respective `sha256` hashes.
- If the HTML hash does not match, or any asset is missing or has a mismatched hash, the tool is marked as **outdated** (shown with an orange refresh icon). Re-downloading fetches the HTML and all assets again.
- Downloads write files atomically to prevent corruption, creating any intermediate asset directories as needed.

### Download states

Each tool can be in one of these states:

1. **Not downloaded** — no local file exists.
2. **Downloading** — a download is in progress.
3. **Downloaded** — local file exists and SHA256 matches the manifest.
4. **Outdated** — local file exists but SHA256 does not match (tool was updated on the server).

### Removed tool cleanup

When a new manifest is fetched, any files in the local `tools/` directory that do not correspond to a tool **or one of its assets** in the new manifest must be automatically deleted. This handles the case where a tool (or an asset) is removed from `assets.json` — its downloaded file should not linger on disk. Empty asset subdirectories are also removed.

### Concurrent downloads

When multiple tools need downloading (e.g. during initial setup), downloads should run concurrently, not sequentially.

## Tool Ordering

- Users can drag to reorder tools in the list.
- The order is persisted as an ordered list of tool IDs (slugs) in local storage (UserDefaults on iOS, SharedPreferences on Android).
- On manifest fetch, the saved order is applied: tools are sorted according to the saved order, and any new tools not in the saved order are appended at the end.
- If no saved order exists, tools appear in manifest order.

## WebView

### Configuration

The WebView used to display tools must have:

- JavaScript enabled.
- DOM storage enabled.
- Local file access enabled (loading from `file://` URLs).
- Fullscreen API support enabled.
- Debug/inspection enabled (for development).
- Scroll bounce disabled (content should not overscroll).
- Transparent/clear background.

### WebView Pool

To avoid cold-start delays when navigating to a tool, the app pre-creates ("warms") a WebView instance when the tool list appears. When a tool is opened, the warm WebView is used and a new one is immediately created for next time. This is a cross-platform requirement.

## Deep Linking

**URL scheme:** `smalltools://open/{slug}`

- Both platforms register and handle this scheme.
- On receiving a deep link, the app navigates to the Tool Viewer for the matching tool (looked up by slug).
- If the app is already showing a tool, the navigation state is reset before navigating to the new tool.

## Platform-Specific Features

### iOS Only

#### Quick Actions (Home Screen Long-Press)

- Up to 4 dynamic shortcuts are created from the user's downloaded tools.
- Shortcuts are updated when the app enters the background.
- Each shortcut opens the corresponding tool via the deep link handler.
- Icon: wrench and screwdriver system image.

#### Siri Shortcuts (App Intents)

- An `OpenToolIntent` is registered so users can create Siri Shortcuts to open specific tools.
- The intent provides a list of available tools from the cached manifest.
- Shortcut phrases: "Open {Tool} in Small Tools", "Launch {Tool} in Small Tools".
- Opens the app and navigates to the tool via deep link.

#### iOS Home Screen Widget (Currency Converter)

A WidgetKit widget that shows exchange rates for one currency pair. This is iOS-only for now, and Android has no equivalent. It is a different feature from the Android Glance widget under [Home Screen Widget](#home-screen-widget), which launches a tool.

**Widget kind:** `CurrencyWidget`. Gallery name: "Currency Converter".

**Families:**

- **Small:** header, the first four preset amounts with their conversions, and the freshness footer.
- **Medium:** header, the six preset amounts in a 2 x 3 grid (source amount on the left, converted amount on the right), and the freshness footer.
- **Lock Screen (rectangular):** pair, rate, and freshness footer. The system tints this family, so it has no background and no accent colors.

**Header:** the pair as `FROM → TO` (for example `USD → NTD`), then the rate (for example `1 USD = 32.50 NTD`). The pair uses the source currency's accent color, from the web tool: USD green, EUR yellow, NTD pink, JPY blue. Light mode uses darker shades of these. GBP, CNY and CAD use the primary text color. Rates below 1 show four decimals.

**Currency names:** TWD is shown as **NTD**, as on the web tool. Other currencies use their ISO codes.

**Configuration:** long-press the widget and choose Edit Widget. The **From** and **To** pickers list USD, EUR, GBP, TWD (NTD), JPY, CNY (RMB) and CAD. The default pair is USD → TWD. There are no other settings.

**Amounts:** the preset source amounts come from the shared formatter. For example, USD uses 1, 5, 10, 20, 50 and 100. Amounts include the currency symbol and thousands separators. JPY shows whole units (`¥1,000`); every other currency, including TWD, shows two decimals (`NT$32,500.00`).

**Refresh:** WidgetKit reloads the timeline at or after 3 hours. The system chooses the exact time. Each timeline has an entry every 30 minutes across those 3 hours, so the freshness footer stays current between reloads.

**Rates:** the widget fetches rates itself. It has no App Group and shares no storage with the app. Sources are tried in order: `https://open.er-api.com/v6/latest/USD`, then `https://api.exchangerate-api.com/v4/latest/USD`. The first response that has a usable rate for every supported currency is used and cached. Conversions go through USD.

**Matches the web tool:** the sources, their order, the fallback rates, the USD pivot and the NTD label follow [Currency Converter](https://code.imdaniel.fyi/tools/currency-universal.html). The logic lives in `ios-native/SmallTools/CurrencyCore/` and is compiled into the widget extension. The app does not depend on it.

**Offline and fallback:**

- If the network fails, the widget uses the last successful rates from its cache file (`rates.json` in its caches directory).
- If nothing is cached, it uses the built-in fallback rates (the web tool's `FALLBACK_RATES`: EUR 0.92, GBP 0.79, TWD 32.5, JPY 150, CNY 7.2 and CAD 1.37 per USD). The footer then reads "Offline rates".
- The widget always shows rates and never an error state.
- The gallery preview and the placeholder use the built-in fallback rates and make no network request.

**Freshness footer:** "Updated just now", "Updated 25m ago", "Updated 2h ago", "Updated 3d ago", or "Offline rates".

**Tap action:** opens the app and navigates to the Currency Converter tool through the deep link `smalltools://open/currency-universal`. The slug is the filename of the tool's path in the manifest (`tools/currency-universal.html`). The tool downloads on open if it is not on the device yet. If the manifest no longer lists the tool, the app opens to the tool list.

### Android Only

_(No Android-only features at this time. The home screen widget is being promoted to a cross-platform feature — see below.)_

## Cross-Platform Features To Implement

These features exist on one platform but are required on both:

| Feature | Exists On | Missing From |
|---------|-----------|--------------|
| Drag to reorder | iOS | Android |
| Home screen widget | Android | iOS |
| WebView pool warm-up | iOS | Android |
| Removed tool cleanup | iOS | Android |

### Home Screen Widget

A home screen widget allows the user to launch a specific tool directly from the home screen.

**Configuration:** when adding the widget, the user picks a tool from the list of available tools.

**Display:** shows the app name ("Small Tools") and the selected tool's title.

**Tap action:** opens the app and navigates directly to the selected tool.

**Cleanup:** when the widget is removed, its persisted configuration data should be cleaned up.
