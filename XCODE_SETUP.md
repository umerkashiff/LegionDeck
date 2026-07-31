# LegionDeck — Xcode Project Setup Guide
## (Do this once on a Mac — the source files are already written)

---

## Prerequisites
- **Xcode 16+** (or Xcode 27 beta for iOS 27 SDK)
- **Apple ID** signed into Xcode (free account is fine)
- A Mac with Xcode installed (needed to create the `.xcodeproj` and build)

---

## Step 1 — Create the iOS App Target

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name:** `LegionDeck`
   - **Bundle ID:** `com.legiondeck.app`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save to the `LegionDeck/` folder you already have (the one with all `.swift` files)
5. **Delete** the auto-generated `ContentView.swift` and `LegionDeckApp.swift` — our versions are already in `LegionDeck/App/`

---

## Step 2 — Add All Source Files

In Xcode's Project Navigator, **drag-and-drop** these folders into the `LegionDeck` group:
- `LegionDeck/App/`
- `LegionDeck/Networking/`
- `LegionDeck/Background/`
- `LegionDeck/LiveActivity/`
- `LegionDeck/Watch/`
- `LegionDeck/Clipboard/`
- `LegionDeck/Debug/`
- `LegionDeck/Views/`

Make sure **"Copy items if needed"** is **unchecked** and **"Add to target: LegionDeck"** is checked.

---

## Step 3 — Add `silence.mp3`

1. Download any 1-second silent MP3 (e.g., `silence.mp3`) — you can generate one with Audacity or download from online
2. Drag it into `LegionDeck/Resources/` in Xcode
3. Make sure "Add to target: LegionDeck" is checked

---

## Step 4 — Configure Info.plist

1. Select `LegionDeck` target → **Info** tab
2. Add these keys manually (or use the `Info.plist` from `LegionDeck/Resources/`):
   - `UIBackgroundModes` → Array → Item 0: `audio`
   - `NSSupportsLiveActivities` → Boolean → `YES`
   - `NSSupportsLiveActivitiesFrequentUpdates` → Boolean → `YES`
   - `NSPasteboardUsageDescription` → String → `LegionDeck syncs your clipboard between iPhone and PC.`

---

## Step 5 — Add Widget Extension (Dynamic Island)

1. **File → New → Target → Widget Extension**
2. Name it: `LegionActivityWidget`
3. **Uncheck** "Include Configuration App Intent"
4. When Xcode asks to activate the scheme, click **Activate**
5. Delete the auto-generated `LegionActivityWidget.swift` — our version is in `LegionActivityWidget/`
6. Drag both `LegionActivityWidget/LegionActivityAttributes.swift` and `LegionActivityWidget/LegionActivityWidget.swift` into the `LegionActivityWidget` group
7. **CRITICAL:** Select `LegionActivityAttributes.swift` → File Inspector (right panel) → **Target Membership** → Check BOTH `LegionDeck` AND `LegionActivityWidget`

---

## Step 6 — Add watchOS App Target

1. **File → New → Target → Watch App**
2. Name it: `LegionDeckWatch`
3. Bundle ID: `com.legiondeck.app.watchkitapp`
4. When prompted to add a scheme, click **Activate**
5. Add `LegionDeckWatch/` Swift files to the watch target
6. Add a **Widget Extension** inside the watch target:
   - **File → New → Target → Widget Extension** (watchOS)
   - Name: `LegionWatchWidget`
   - Add `LegionDeckWatch/LegionWatchWidget/LegionWatchWidget.swift`

---

## Step 7 — App Group (for Watch data sharing)

1. Select `LegionDeck` target → **Signing & Capabilities** → **+ Capability → App Groups**
2. Add: `group.com.legiondeck.app`
3. Repeat for `LegionDeckWatch` target
4. Repeat for `LegionWatchWidget` target

---

## Step 8 — Signing

1. Select `LegionDeck` target → **Signing & Capabilities**
2. Set **Team** to your Apple ID
3. Let Xcode auto-manage provisioning
4. Repeat for all targets (LegionActivityWidget, LegionDeckWatch, LegionWatchWidget)

> **Free Account Note:** Xcode may warn about some capabilities not being available with a free account.
> Live Activities and App Groups *do* work with free accounts when sideloading.

---

## Step 9 — Build Scheme for IPA (GitHub Actions)

The CI pipeline uses:
```
-project LegionDeck.xcodeproj -scheme LegionDeck
```

Make sure you have a scheme named `LegionDeck` (Xcode creates this automatically).

---

## Step 10 — Install via AltStore

1. Download IPA from GitHub Actions → Artifacts
2. Open **AltStore** on your iPhone → **+** → select `LegionDeck.ipa`
3. Or use **Sideloadly** on your Windows PC with iPhone connected via USB

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No account for team" | Sign into Xcode with your Apple ID |
| Live Activity won't start | Check NSSupportsLiveActivities = YES in Info.plist |
| Watch widget not updating | Verify App Group ID matches in all 3 targets |
| Background socket dies | Confirm UIBackgroundModes: [audio] in Info.plist and silence.mp3 is bundled |
| CPU temp reads 0 | Re-run `start.bat` — needs Admin (UAC prompt) |
