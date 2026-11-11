# Strata 2.0

**English** | [简体中文](README.zh-CN.md)

A customizable launcher built on [LiveContainer](https://github.com/LiveContainer/LiveContainer), with three interfaces and bundled SideStore support.

<p align="center"><img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png" width="160" alt="Strata icon"></p>

## Three interfaces

- **iOS Home Screen:** portrait layout, custom icons and names, static/video wallpapers, widgets, folders, scrubbable page dots, dock favorites, search and a categorized App Library.
- **Cinematic:** landscape console-style app rail, artwork, categories, adjustable Play controls and controller navigation.
- **Big Picture:** landscape library with independent portrait artwork, categories, layout sizing and controller navigation.

Artwork, categories and hidden-app choices are independent between interfaces. Imported artwork and wallpapers are available in Files → On My iPhone → Strata → Artwork.

## What's new in 2.0

- Built-in JIT preparation using a device pairing record and LocalDevVPN, plus automatic/Universal/imported per-app script choices.
- Integrated RAM capability account setup and actual host/guest memory reports. Entitlements remain subject to Apple's signing profiles and iOS limits.
- One three-finger app switcher inside the launcher and guests, showing running apps and optional pins. Open, restore, minimize or close supported guests without a permanent floating arrow.
- Native paged scrolling, continuous dock/backdrop transitions and Home-only page dots with scrubbing.
- Drag-to-create folders, drag apps out, dissolve folders while retaining apps, and hold blank Home space to edit.
- Launch with Metal HUD for supported Metal apps.

## Download and install

Get **Strata-2.0+SideStore.ipa** from [Releases](https://github.com/huzaifahshahid71-ops/Strata/releases/tag/v2.0.0). Sign and install with SideStore. When updating a compatible combined installation, **keep the current app and choose Keep App Extensions**, using the same account and identity to preserve data. Back up important guest data first.

Strata 2.0 is the product release name; this build uses the LiveContainer **3.8.11** base and development revision **25**. The underlying bundle version/identity are retained for update compatibility. The IPA does not contain personal signing credentials or pairing records.

## Chinese build (v11 → v14)

The `zh-hans` branch ships a fully localized Simplified Chinese UI and README. v11 does two things on top of the rolled-back v7 baseline:

**Merges the LiveContainer upstream update of 2026-11-08 (`9d6ea09b05`)**: built-in JIT enablers / RAM donors / helper processes and guest app extension support (`NSExtension+GuestHooks.m`, `LCPrepareGuestExtension`, `patchGuestExtensions`), the `LCAppModel.copy(fromApp:toAppInfo:)` refactor, and a new "Helper Process Support" toggle in per-app settings. The merge is three-way, so all Strata LiveBoard and Game Mode customizations are preserved; the upstream reference to `fixBackgroundTaskIdentifiers` was removed because v7 has no such property.

**Fixes certificate and tweak-module import**:

- Declares the `com.kdt.livecontainer.p12` UTI (`p12` / `pfx` / `pkcs12`) and a Signing Certificate document type. Certificates can be opened with Strata straight from Files, and file URLs route to Settings.
- Certificate import now uses security-scoped access, automatically retries with an empty password, accepts both `cert=` and `data=` deep-link parameters, and writes `LCAppGroupID` on success.
- Tweak import uses `copyItem` with security-scoped access instead of `moveItem`, so read-only sources from Files / share sheets work.
- `strataPresentSafely` works around the SwiftUI `.alert` dismissal race, so the document picker and password prompt no longer fail silently; all `UTType` force unwraps were removed.

The bundle version is **3.8.19**, higher than every previous build, so it can be installed over the top without uninstalling. This build contains **no SideInstaller**; the built-in store entry remains the original SideStore. **1332** Chinese strings are shipped.

### v12: floating menu did not appear even when enabled

The bundled Orbit / LCFloatingMenu is bumped to upstream **1.0.36** (8pt larger close-button hit area), and the bootstrap gate is fixed at the root:

- It no longer requires a non-nil `guestAppInfo` and no longer excludes `isLiveProcess`. Strata 2.0 multitask guests themselves run inside `LiveProcess.appex`, so the old check excluded every guest and the toggle did nothing.
- Guest detection now compares whether `mainBundle` has been rewritten to the guest bundle; the Strata UI and built-in SideStore still never show the bead.
- The switch is resolved from the env var, the App Group defaults, and the host defaults in turn; when none of them has a value it defaults to on and writes the value back, so a switch stored in the wrong suite can no longer be read back as "off".
- Bootstrap attempts now run immediately, at 0.6s, 2s, 5s, and again on foreground / scene activation, so enabling the switch while a guest is running takes effect without relaunching.
- A status row plus "Copy diagnostics" is added under the floating menu toggle; each guest writes its decision into the App Group so failures are visible.
- Cleanup: removed the unused `LCOrbitHost.isSupportedGuest` (its logic contradicted LiveProcess guests), removed `GuestInfo()` and a redundant `objc/message` import, and merged the duplicated host/guest/SideStore checks in `installIfPossible` into the single gate in `LCOrbitCore`.

The bundle version is **3.8.20**, and **1337** Chinese strings are shipped.

### v13: landscape-right misalignment and black bars fixed

The plugin shipped a global "orientation enforcement" layer; it is removed entirely, leaving only "keep screen awake":

- **No more window frame / bounds rewriting.** On every `layoutSubviews` and orientation change it forced every window to `(0,0,landscape width,landscape height)`. Since iOS 13 window geometry is owned by `UIWindowScene`, so hard-setting the frame desynchronises the window from the scene coordinate space - in landscape right the content is pushed to one side and a black bar appears on the other.
- **No more global replacement of `supportedInterfaceOrientations` / `__supportedInterfaceOrientations`.** It fought LiveContainer's own per-app orientation lock in `TweakLoader/UIKit+GuestHooks` for the same selector, breaking the lock and force-rotating portrait-only apps into a broken layout.
- **Orientation is declared by the system and the guest app again:** landscape-capable apps rotate normally, portrait-locked apps stay portrait, and `App settings -> Orientation lock` works again.
- The "left landscape adapt" and "ban right landscape" switches in the floating-menu settings are gone (they only patched the layer above); "Keep screen awake" stays.

The bundle version is **3.8.21**, and **1337** Chinese strings are shipped.

### v14: remaining English in LiveBoard, JIT and memory pages

Up to v13 only literal `Text("...")` sites were covered. `Text(ternary)`, `String` variables and array labels **never go through localization**, so plenty of English was left on screen. This release fixes each display path:

- **Ternary expressions** (`Text(a ? "X" : "Y")`, `Label(...)`, `Button(...)`): all now use `"X".loc`. SwiftUI's `Text`/`Label`/`Button` take a plain `String` without localization, which was the main source of English across the three LiveBoard interfaces (Cinematic / Big Picture / Home).
- **`String` assignments and returns**: `LiveBoardMode.title/detail`, `StrataJITScriptMode.title`, `getStoreName()`, and every `errorInfo = "..."`, `status = "..."`, `session.message = "..."`, `throw "..."` now use `.loc`.
- **Array labels**: the console action menu (`["Launch", "App settings", ...][index]`) is localized item by item.
- **Interpolated messages**: switched to `LCStr("key", "fallback", args)` with fixed keys so extracted key names cannot drift (9 new keys: `strata.jit.guestAck`, `strata.memory.*`, ...).
- **ObjC**: the "App controls unavailable / Hide app strip / No open apps" strings in `StrataGuestControls` now use `NSLocalizedString`.
- Three formatted strings (`"%lld apps"`, the clean-data-folder confirmation, and the move-folders completion note) used `.localizeWithFormat()`, whose compiler-extracted keys never matched the fragment and fell back to English; they now use fixed `LCStr` keys.
- Chinese strings grow from **1337 to 1449** (fragment 1005 → 1118 entries).

The bundle version is **3.8.23**.


## JIT and RAM setup

Import your own pairing record on the device, keep your working LocalDevVPN configuration, enable Developer Mode, and use JIT → Prepare device. Launch with JIT uses the existing guest runtime and a headless StikJIT helper. Script compatibility varies: Universal is selected automatically only for verified IDs; custom imports and per-app overrides remain available.

RAM capability setup signs into Apple's service to request the increased-memory capability for the installed host and guest App IDs. Reinstall/refresh with an authorized signing profile afterward. Credentials are handled in memory, and the memory reports distinguish actual guest measurements from the launcher's reading. A request is not a guarantee that iOS granted a particular amount of memory.

## Limits and testing

- **LiveExec32 still requires JIT.** There is no working JIT-free ARMv7 interpreter/AOT backend in this release.
- **Game Mode is controlled by iOS.** Request Game Mode declares guest support and requests fullscreen; it cannot reliably force a separate OS Game Mode state for every guest under the shared host identity.
- Metal HUD requires a supported Metal rendering path. Physical HUD verification and 120 Hz frame-pacing measurements for this final build remain pending.
- Normal in-process guests cannot stay independently suspended while another main-process guest runs; switching uses the existing host relaunch. Separate JIT/multitasking guests retain independent lifecycles.
- Earlier development builds were tested on an iPhone 15 Pro: Angry Birds ran with built-in JIT, and a normal JSAB guest reported an approximately 6 GiB footprint/headroom total with the memory entitlement. These results do not establish compatibility for every guest.
- The release build and package checks pass. Seven simulator UI tests cover Home gestures, folder create/drag-out/removal, categories, wallpapers, and consistent running/pinned switchers; focused folder model checks also pass. Final phone smoothness, HUD and process-switching checks remain user tests.

## Build from source

```sh
git clone --recurse-submodules https://github.com/huzaifahshahid71-ops/Strata.git
cd Strata
python3 Scripts/fetch-bundled-dependencies.py
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Use a compatible Xcode 26 or newer installation with the iPhoneOS SDK. The target remains named LiveContainer. The postbuild step embeds the JIT helper and runtime. The combined download preserves original SideStore components; a fresh source build is not byte-identical to that assembly. Sign unsigned builds before installation.

## Credits and permissions

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), the retained [LiveContainer license](LICENSE), dependency notices and pinned provenance. StosSign redistribution permission for this Strata release was confirmed by the project maintainer on 29 October 2026; no general upstream license is asserted. Strata is not affiliated with Apple, Sony or Valve.
