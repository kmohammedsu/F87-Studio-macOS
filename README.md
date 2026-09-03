# F87 Studio for macOS

F87 Studio is a self-contained native macOS controller for AULA F87/F87 Pro keyboards whose official configuration utility is Windows-only.

## Features

- focused device-workbench interface with one compact toolbar, semantic system colors, light/dark appearance support, and restrained grouped surfaces
- two-column Lighting Workbench with an effect inspector, a dedicated keyboard stage, and visible in-context Apply control
- matching Per-key Workbench with a compact tool inspector, persistent F87 canvas, and visible paint/selection status
- firmware-supported onboard lighting modes, brightness, speed, single-color and colorful variants
- animated on-screen effect simulation before anything is sent to the keyboard
- a fixed, carefully composed window that prevents stretched preview surfaces
- always-visible Lighting and Per-key apply actions in the window toolbar, including an explicit “Turn Lights Off” state
- low-latency tactile controls, Command-1 through Command-6 navigation, instant screen changes, and a single-canvas 30 FPS preview
- customizable host-side F1–F12 macros with MacBook defaults for brightness, media, Mission Control, Spotlight, and volume
- working modern defaults for Dictation and Focus controls, plus Mission Control's direct system trigger
- pointer-aware brightness: F1/F2 use native brightness on the MacBook screen and independently dim the external monitor under the mouse
- additional F-key actions for Show Desktop, app windows, Control Center, Notification Center, Emoji, Quick Note, and display sleep
- optional launch-at-login support and an in-app F1 test for an always-available 2.4 GHz workflow
- live Accessibility diagnostics, automatic permission recovery, and one-click relaunch when macOS requires a fresh process
- a single centered navigation bar, compact horizontal effect browser, and native inspector-style controls designed for macOS
- visual per-key RGB painter for the 87-key layout
- responsive per-key tool shelf with color swatches and one-click Spectrum, Color by row, and Gaming designs
- sleep timer and debounce configuration on compatible 20-byte-protocol revisions
- built-in information popovers explaining every hardware setting
- one-click error and diagnostic-report copying with no keystroke or typed-text collection
- tailored recovery guidance for common permission, discovery, firmware, write, and verification failures
- compact single-open troubleshooting dropdowns for faster diagnosis
- Per-key Pro tools: drag painting, Undo/Redo, selection groups, eyedropper, and directional gradients
- persistent in-app profile library, menu-bar switching, and automatic per-application profiles
- automatic receiver reconnect after sleep or interruption
- crash-safe HID discovery pinned to the persistent main run loop, with overlapping scans suppressed
- microphone-powered 11-band Music mode on the verified 20-byte receiver protocol
- current-setting sync on connection and verified factory-lighting reset on the known receiver
- import/export reusable `.f87profile` JSON profiles
- wired USB (`258A:010C`) and known 2.4 GHz receiver (`3554:FA09`) discovery
- read-before-write safety and post-write verification

## Use

1. Connect the keyboard by USB cable or the known 2.4 GHz receiver (`3554:FA09`). If a receiver revision is not recognized, plug in the cable and switch the keyboard to wired mode. Configuration over Bluetooth is not supported by the device protocol.
2. Move F87 Studio to Applications and open it. Allow it under **System Settings → Privacy & Security → Input Monitoring**. If it is not listed, use the **Open Input Monitoring** button and add the app with the `+` button. To use Mac function-row mappings, also allow F87 Studio under **Privacy & Security → Accessibility**; the Settings screen shows the listener's live state.
3. Quit F87 Studio completely, reconnect the keyboard, reopen the app, and choose **Scan again**. Then customize and choose **Apply**.

The app does not listen to or record keystrokes. macOS may require Input Monitoring because AULA exposes the control channel as part of a keyboard-class HID device.

## Compatibility and safety

The known protocols cover AULA F87-family devices with the USB identifiers above. AULA has shipped multiple revisions. F87 Studio probes both the 520-byte feature-report protocol used by the detected wired `258A:010C` revision and the 20-byte control protocol used by other known revisions. It reads the complete current configuration before each update, modifies only known bytes, and verifies important changes after saving. If the device does not return the expected format, the app refuses to write.

Sleep, debounce, and factory-reset offsets have not been decoded safely for the 520-byte wired firmware, so those controls are disabled when that backend is detected. Lighting and per-key RGB remain available.

F87 Studio intentionally does not write the keyboard's undocumented macro/key-remap tables. Instead, its optional Mac function row intercepts F1–F12 in macOS and performs the selected action while the app is running. This works independently of the RGB control connection and never overwrites onboard assignments. The documented firmware tables target different USB revisions, cannot be read back from many F87 firmwares, and have not been validated on the `3554:FA09` receiver. Writing a guessed table could erase the keyboard's existing assignments.

## Build from source

Requires Xcode 15 or later:

```sh
swift test
./scripts/build_app.sh
```

The build script creates `outputs/F87 Studio.app` and a shareable ZIP archive.
The packaged app is universal and supports both Apple-silicon and Intel Macs running macOS 13 or later.
Local release builds embed a stable designated requirement for `studio.f87.mac`, so replacing the app with a later build does not create a new Input Monitoring identity.

For a Developer ID-signed and notarized distribution, first store App Store Connect credentials with `xcrun notarytool store-credentials`, then set `F87_SIGN_IDENTITY` and `F87_NOTARY_PROFILE` and run `./scripts/release_notarized.sh`. An active Apple Developer certificate is required; the project cannot create or impersonate one.

The app uses HIDAPI 0.15.0 under its BSD license. Protocol behavior was independently implemented from public reverse-engineering documentation by the AULA open-source community.

## Third-party acknowledgements

- HIDAPI — BSD-3-Clause (`THIRD_PARTY_NOTICES.md`)
- Protocol references: `marcoslor/Aula-F87-Controller`, `free-soldier28/Aula-Manager`, `vndarkblue/aula-keybind`, and `veysiemrah/aula-rgb-controller`

This project is independent and is not affiliated with AULA.
