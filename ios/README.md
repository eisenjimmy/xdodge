# Xdodge for iOS

A native SwiftUI + WKWebView wrapper around `../xdodge.html`. The HTML file at the repo root is the single source of truth. It is copied into the app bundle on every build, so an edit to it shows up in the next build without any other step.

## Prerequisites

- A Mac with Xcode 16 or later. The deployment target is iOS 16.0.
- XcodeGen: `brew install xcodegen`
- An Apple Developer account, for device builds, Game Center and TestFlight.

## Build and run

```sh
cd ios && xcodegen generate && open Xdodge.xcodeproj
```

1. Set your Team ID in `project.yml` under `DEVELOPMENT_TEAM`. You can also set it in Xcode's Signing tab, but every `xcodegen generate` resets that.
2. The app icon is already at `Xdodge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024x1024, opaque). Its source is `icon/AppIcon.html`, a 128px pixel canvas scaled 8x. To change it, edit that file and take a 1024x1024 screenshot of it, for example with `msedge --headless=new --window-size=1024,1024 --screenshot=AppIcon-1024.png icon/AppIcon.html`.
3. Pick the `Xdodge` scheme and a simulator or device, then Run.

Run `xcodegen generate` again after you add, rename or delete Swift files, or edit `project.yml`. `Xdodge.xcodeproj` and `Xdodge/Info.plist` are generated and git-ignored.

To debug the web layer: in Debug builds the web view can be inspected from Safari (Develop > your device > Xdodge). On the device, first turn on Settings > Safari > Advanced > Web Inspector.

## Game Center leaderboard (App Store Connect)

1. Create the app record with bundle ID `com.eisenjimmy.xdodge`.
2. On the app's page, open **Game Center**, then **Leaderboards**, then **+**, and choose **Classic Leaderboard**:
   - Leaderboard ID: `xdodge.highscore`. It must equal `GameCenterConfig.leaderboardID`, and you can't change or reuse it later.
   - Score format type: **Integer**. Score submission: **Best score**. Sort order: **High to low**.
   - Add at least one localization (display name and score format).
3. On the app version page, turn on Game Center and attach the leaderboard before you submit.

The Game Center entitlement is already declared in `project.yml`, and automatic signing turns the capability on for the App ID. To test, sign in under Settings > Game Center on a device or simulator. Development and TestFlight builds use the sandbox environment.

If Game Center is unavailable, signed out or not configured yet, the app still works. The page receives `ok:false` and keeps using its on-device leaderboard.

## JS bridge

| Direction | Shape |
|---|---|
| JS to native | `webkit.messageHandlers.xdodge.postMessage({type:'score', value:<int>})` |
| | `{type:'showLeaderboard'}` |
| | `{type:'haptic', style:'light'\|'medium'\|'heavy'\|'success'\|'error'}` |
| Native to JS | `window.xdodgeNative = {platform:'ios', version:'1.0'}` is set before the page's script runs |
| | `window` event `xdodge-native` with `detail = {type:'gc', ok:<bool>, name:<alias>}`, sent on each page load and each auth change. The latest value is also kept in `xdodgeNative.gc` |
| | A synthetic `window` `blur` pauses the game when the app resigns active or opens a Game Center sheet |

## TestFlight and App Store

- In `project.yml`, bump `CURRENT_PROJECT_VERSION` for every upload and `MARKETING_VERSION` for each release. Then run `xcodegen generate`.
- To upload: Product > Archive > Distribute App > App Store Connect.
- `ITSAppUsesNonExemptEncryption = false` answers the export-compliance question.
- Review risk: guideline 4.2 (minimum functionality) targets thin web wrappers. In the review notes, say that the game is bundled and works offline, and that it uses Game Center and haptics.
- Privacy label: the app itself collects nothing. Scores stay on the device or go to Apple's Game Center. Confirm this before you submit.
- iPad: `UIRequiresFullScreen` is deprecated as of iPadOS 26. The canvas scales to any window size, so you can remove the key when Apple stops honoring it.
