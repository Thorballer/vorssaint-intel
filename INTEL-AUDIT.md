# Vorssaint Apple-Silicon-Only Audit

Task: t_2ec024d4 · Repo: `vorssaint/vorssaint-utils` @ main (cloned to
`~/.hermes/kanban/workspaces/t_2ec024d4/vorssaint-utils`) · Audit date: 2026-09-26

## Executive summary

Vorssaint is a SwiftPM-manifested but **hand-compiled** app: `build.sh` drives
`swiftc` directly with a hard-coded target triple. There are **no vendored
binaries, no CocoaPods/Carthage, and zero third-party SwiftPM dependencies**
— every import maps to a system framework (Foundation, AppKit, SwiftUI,
IOKit, AVFoundation, Accelerate, Metal, …), all of which ship universal in
the macOS SDK.

The only hard x86_64 blocker in the tree is **one line**: the arm64 target
triple in `build.sh`. Everything else found is either already arch-portable
or a policy/expectation item. The only `#if arch(...)` in 610 Swift files
picks a CPU-brand string for update-feed checks and compiles correctly for
x86_64 as written.

Verified on this machine (Intel Mac mini, i5-8500B, Swift 6.1.2/Xcode SDK
15.5): `swiftc -target x86_64-apple-macosx14.0` is accepted by the local
toolchain, and a full-module x86_64 compile of all 606 app sources was run
to ground the findings (see "Verification" below).

The upshot for the build task (t_33250c81): **x86_64-only is the right
choice.** A universal build would buy nothing for an Intel-only user while
doubling compile time on this 6-core Intel mini.

---

## 1. Build configuration

### 1.1 HARD BLOCKER — arm64-only target triple

- **File:** `build.sh:65`
- **Finding:** `TARGET="arm64-apple-macosx14.0"`, consumed by every compile:
  - `build.sh:522` — unit tests (`swiftc … -target "$TARGET"`)
  - `build.sh:552` — main app (`swiftc … -target "$TARGET"`)
  - `build.sh:557` — fan helper (`build/$FAN_HELPER_ID`)
  - `build.sh:568` — Now Playing dylib (`libVorssaintNowPlaying.dylib`)
- **Impact:** every artifact (app executable, fan-control LaunchDaemon
  helper, Now Playing dylib, test runner) is arm64-only. Nothing in the
  bundle runs natively on Intel Macs.
- **Fix:** `TARGET="x86_64-apple-macosx14.0"` (or add
  `--target=`/`ARCHS=` override arg with arm64 default preserved). Single
  variable feeds all four compile sites — one-line change fixes the class.
  If a universal build is ever wanted instead: compile twice per artifact
  and `lipo -create` the four outputs (app, helper, dylib, tests).

### 1.2 Package.swift — NOT a blocker

- **File:** `Package.swift`
- **Finding:** `platforms: [.macOS(.v14)]`, one executable target + two
  systemLibrary targets (`HIDEventSystem`, `VMStatisticsCompat`). No
  `EXCLUDED_ARCHS`, no arch restrictions, **no dependencies**. Note: CI and
  build.sh never call `swift build`; the manifest is documentation-only
  today.
- **Fix:** none required. (Optional: if the project ever moves to
  `swift build`, keep using it as-is — it's arch-neutral.)

### 1.3 Product policy — Apple Silicon stated everywhere (informational)

- **Files:** `README.md:29` (badge: "macOS 14+ Apple Silicon"),
  `README.md:208` ("A Mac with Apple Silicon"), `CONTRIBUTING.md:8`
  ("You need macOS 14 or newer, Apple Silicon and the Xcode Command Line
  Tools"), `docs/TROUBLESHOOTING.md`, CHANGELOG, .github templates — all
  declare Apple Silicon-only as product policy. Not a code blocker; fix is
  documentation: when shipping the Intel build, note the added platform
  support in README/CONTRIBUTING.

## 2. Dependencies

### 2.1 Vendored binaries / CocoaPods / Carthage — none

- **Evidence:** `find . -name '*.a' -o -name '*.dylib' -clean` style sweeps
  found zero `.a`/`.dylib`/`.framework`/`.xcframework`/`.o` files in the
  tree (the only dylib in the product, `libVorssaintNowPlaying.dylib`, is
  compiled from source by build.sh itself); no Podfile/Cartfile; Package.swift
  has zero dependency entries.

### 2.2 System frameworks — all universal in the SDK

- **Evidence:** import census across 610 Swift files: Foundation (293),
  AppKit (219), SwiftUI (189), CoreGraphics (75), Combine (63), Darwin (39),
  Carbon (36), ApplicationServices (33), IOKit (21), AVFoundation (17),
  Vision (4), Accelerate (4), ScreenCaptureKit (3), Metal (1), IOBluetooth,
  CoreWLAN, CoreBluetooth, CryptoKit, etc. — every one is an Apple system
  framework present for both architectures in every macOS SDK.
- **Fix:** none.

### 2.3 Non-Swift runtime assets — arch-neutral

- `Resources/now-playing.pl` (perl script loaded via /usr/bin/perl),
  `Resources/agent-prices.json`, localization `.lproj` folders, GIFs,
  images — no compiled content.

## 3. Source-level architecture-specific code

Full sweep of 610 Swift files + 2 C shims for `#if arch(`, `__arm64__`,
`__x86_64__`, NEON, assembly (`.s`/`.S`/`asm()`/`__asm__`), and
`arch-guarded imports`:

### 3.1 `#if arch(arm64)` in AppUpdatesService — NOT a blocker (already correct)

- **File:** `Sources/Vorssaint/Services/AppUpdates/AppUpdatesService.swift:448-452`
- **Finding:** selects `architecture = "arm64"` vs `"x86_64"` for
  update-feed metadata. This is a correct `#if arch(...)` /
  `#else` pair — it compiles fine for x86_64 (the `#else` branch is taken).
- **Note:** this whole service is being removed by sibling task
  t_81226807 (strip GitHub auto-update); the point becomes moot after that
  lands.

### 3.2 machdep.cpu.brand_string consumers — graceful on Intel

- **Files:** `Sources/Vorssaint/Services/Metrics/TemperatureSensorSelector.swift:73-89`
  and `FanControlHardware.swift:46`
- **Finding:** `TemperatureSensorSelector.platform(brandString:)` returns
  `.generic` for any brand string that isn't "Apple …" (i.e., Intel CPUs),
  `hasCPUCoreSet(.generic) == false`, and
  `isCPUTemperatureKey`/`displayedCPUTemperature` handle `.generic` by
  falling back to hottest-sensor. Fan control requires mapped core sensors
  — on Intel it will report "no mapped sensors" rather than misbehaving
  (see §5.3 for what that means for feature parity).

### 3.3 CPU-core-type detection (P/E cores) — absent

- **Evidence:** no `perflevel` / `hw.perflevel` / efficiency-core queries
  anywhere in Sources; app never branches on core topology.

### 3.4 Inline assembly / NEON intrinsics — absent

- **Evidence:** no `.s`/`.S`/`.asm` files; no `asm()`/`__asm__`; no NEON
  references; no `__arm64__`/`__x86_64__` C macros.

### 3.5 Accelerate/vDSP — portable

- **Files:** `NotchAudioLevelService.swift`, `AppVolumeMixer.swift`,
  `MixerRender.swift`, `RecorderSystemAudioTap.swift`
- **Finding:** vDSP DFT/windowing/vector math via the Accelerate framework
  — ships for x86_64 in the SDK. No hand-written NEON.

### 3.6 Pointer-width patterns — already portable

- **Finding:** 35 `bitPattern` conversions, but all go through
  `UInt(bitPattern:)` (pointer-width) or `UInt32` on a 32-bit value
  (`OSAtomicAdd32Barrier`), not truncating-pointer idioms that would break
  at one specific pointer size.

### 3.7 Timebase / sysctl usage — portable

- **Evidence:** timestamps use `CFAbsoluteTime*`; sysctls used are
  `kern.osrelease`, `kern.boottime`, `vm.swapusage`, `hw.model`,
  `machdep.cpu.brand_string`, `kern.memorystatus_vm_pressure_level`,
  network route messages — all valid on Intel macOS 14+.

### 3.8 Metal — portable

- `ExtraBrightnessService.swift` uses `MTLCreateSystemDefaultDevice()` with
  graceful `nil` fallback; Intel GPUs are supported by Metal on macOS 14.

## 4. Embedded artifacts shipped in the app bundle

| Artifact | Built by | Arch risk |
|---|---|---|
| `Vorssaint` executable | build.sh:550-554 | fixed by §1.1 |
| `com.vorssaint.utils.fan-control` helper (LaunchDaemon) | build.sh:557-564 | fixed by §1.1 |
| `libVorssaintNowPlaying.dylib` | build.sh:568-575 | fixed by §1.1 |
| `now-playing.pl` | resource | none |
| `AppIcon.icns` / `Assets.car` / GIFs / lprojs | actool / copy | none |

All compiled artifacts flow from the single `$TARGET` variable — fixing
§1.1 covers the entire bundle.

## 5. Behavioral notes for an Intel build (not build blockers)

These are runtime differences worth knowing about — none prevent building
or launching on Intel; the audit's fix list is unchanged.

- **§5.1 `TemperatureSensorSelector.currentPlatform()` fallback
  asymmetry:** if the `machdep.cpu.brand_string` sysctl fails, the code
  returns `.unmappedAppleSilicon` — a misnamed Intel Mac would be
  classified as Apple Silicon. Purely cosmetic for display logic; on real
  Intel hardware the sysctl always exists, so this never fires. No fix
  required for the port.
- **§5.2 AppUpdatesService** already selects the right architecture string
  at compile time (§3.1) and is scheduled for removal (t_81226807) anyway.
- **§5.3 Fan control and CPU-temperature features are Apple-Silicon-keyed:**
  FanControlPolicy requires mapped per-core sensors; on Intel the app will
  show fans but treat manual control as unsupported, and CPU temp falls
  back to hottest-sensor display. This is pre-existing policy in the code,
  not an arch dependency — extending fan control to Intel SMC keys would be
  a feature decision outside this audit's scope.
- **§5.4 CI/release runners:** ci.yml (macos-15 / macos-26) and release.yml
  (macos-26) runners are all Apple Silicon GitHub runners; builds will
  continue to be arm64 unless the workflow passes an explicit target flag
  to build.sh. If upstream CI must keep shipping arm64, add a build.sh
  `--target=` argument (default arm64) and pass `--target=x86_64` for the
  Intel artifacts.

## 6. Verification performed

1. Cloned `vorssaint/vorssaint-utils` (default branch `main`).
2. Swept all 610 Swift files + C shims for arch conditionals, C arch
   macros, assembly, NEON, P/E-core sysctls, timebase and pointer-width
   traps — results in §3.
3. Confirmed zero vendored binary dependencies (§2.1).
4. `swiftc --version` on this Mac mini (Intel i5-8500B): Apple Swift
   6.1.2, **default target x86_64-apple-macosx15.0**.
5. Toolchain probe: `swiftc -target x86_64-apple-macosx14.0` compiles and
   links a probe binary; `file` confirms `Mach-O 64-bit executable x86_64`.
6. Full-module x86_64 compile probe: all 606 app sources compiled with
   `-target x86_64-apple-macosx14.0` — **zero errors** (only 4 pre-existing
   Swift-6-mode Sendability warnings in ShelfService/WallpaperSection/
   ClipboardThumbnailImage, present in the arm64 build as well).
7. **End-to-end build verification:** applied the §1.1 one-line fix to
   build.sh and ran `./build.sh` unmodified otherwise — **exit 0**, bundle
   staged at `build/stage/Vorssaint.app`. `lipo -info` + `file` on every
   Mach-O in the bundle (executable, fan-control helper,
   libVorssaintNowPlaying.dylib): all pure x86_64, no arm64 slices.
8. **Native run verification:** `./build/Vorssaint --selftest` executed
   directly on this Intel Mac mini — `SELFTEST OK`, exit 0 (one
   informational warning about absent SMC temperature keys, unrelated to
   architecture).

## 7. Recommended fix list for t_33250c81 (build task)

1. `build.sh:65`: `TARGET="x86_64-apple-macosx14.0"` (one-line change; or
   make it an overridable `--target=` argument). **This is the only
   required code change — and it has already been applied and verified on
   this machine** (see §6.7-6.8); the modified build.sh + built app are in
   this task's workspace clone at
   `~/.hermes/kanban/workspaces/t_2ec024d4/vorssaint-utils/`.
2. Skip no other source changes — nothing else in the tree is arm64-bound.
3. Choose **x86_64-only** (recommended and now proven): the only consumer
   is an Intel Mac; universal doubles compile time on this 6-core mini for
   zero benefit.
4. Update README/CONTRIBUTING lines (README.md:29, README.md:208,
   CONTRIBUTING.md:8) if the Intel build will be distributed.
5. After building, verify with `lipo -info` + `file` on all Mach-O
   artifacts (app executable, fan helper, Contents/Frameworks dylib) —
   acceptance criterion for t_33250c81, already demonstrated in §6.7.
