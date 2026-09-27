# Vorssaint — Intel (x86_64) build

> **Unofficial.** This is an independently maintained Intel build branch of
> [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils).
> Not affiliated with, endorsed by, or produced by the Vorssaint project.
> Upstream ships Apple Silicon builds only; this branch makes the same app
> build and run as a native x86_64 binary on Intel Macs (macOS 14+).
>
> **This repository distributes source only.** Per upstream's
> [TRADEMARKS.md](TRADEMARKS.md), unofficial builds may not use the Vorssaint
> name, icon, or bundle identity — so if you redistribute a build you make
> from this branch, rename and re-brand it first. For personal use, just
> build and install locally (see below). The upstream self-updater has been
> removed from this branch, so it never phones upstream's release feed.

## Why this exists

Vorssaint upstream requires Apple Silicon; the only arch blocker is one line
in `build.sh` that hard-codes an `arm64` target triple. Upstream has open
issues asking for Intel support (#1639, #1494, #1514) and three closed,
unmerged Intel PRs (#135, #417, #1048). This branch is the minimal,
up-to-date port.

## What changed vs upstream `main`

Four commits on top of upstream `main` (`c793a7d3`, 2026-09-26):

1. `remove GitHub auto-update` — the GitHub-Releases self-updater
   (hourly checks against `api.github.com`, DMG download + admin install,
   update UI, showcase video downloader) is removed entirely: 40 files,
   +279/−3056. The app makes no network connections at startup. The
   *App Updates* feature (updating *other* apps) is untouched.
2. `build for x86_64 (Intel)` — `build.sh` targets
   `x86_64-apple-macosx14.0` instead of `arm64-apple-macosx14.0`.
3. `restore brightness-onboarding prompt` — restores an upstream feature
   adjacent to the removed updater code (see commit message).
4. `docs` — Intel noted as a supported target; `INTEL-AUDIT.md` included
   (the dependency audit that found the single-blocker conclusion).

Everything else is upstream code, GPL-3.0-or-later, unchanged.

## Build it yourself (Intel Mac)

Requirements: macOS 14+, an Intel Mac, [Xcode Command Line Tools]
(`xcode-select --install`). No other dependencies — the project vendors
nothing and has no SwiftPM/CocoaPods packages.

```sh
git clone -b x86_64-build https://github.com/Thorballer/vorssaint-intel.git
cd vorssaint-intel
./build.sh            # compile, generate the icon, assemble + ad-hoc sign the bundle
./build.sh --install  # same, then install into /Applications and launch
```

All three Mach-O artifacts (app, fan-control helper, Now Playing dylib)
come out pure x86_64. Fan Control and CPU-temperature features remain
Apple-Silicon-keyed by upstream design; on Intel the app degrades those
cards gracefully (documented in `INTEL-AUDIT.md`).

## Verification performed

- `./build.sh` exit 0 on a Mac mini (Intel i5-8500B, macOS 15.7.4)
- `lipo`/`file`: all bundled Mach-O binaries x86_64-only
- `codesign --verify --deep --strict` passes (ad-hoc signature)
- `Vorssaint --selftest` exits 0
- App launches, renders its status menu, and quits cleanly on real Intel hardware
- `strings` census of the compiled binary: zero references to the removed
  updater endpoints (`api.github.com/repos/vorssaint/...`)
- Test suite at time of port: 67,602 / 67,627 checks pass; the 25 failures
  are pre-existing Recorder-suite failures, identical on unmodified upstream

## License

GPL-3.0-or-later, inherited from upstream. The Vorssaint name, logo, icon
and trade dress are **not** covered by that license — see
[TRADEMARKS.md](TRADEMARKS.md).
