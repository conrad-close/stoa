# Stoa

An open-source, native Mac browser built on WebKit. No built-in AI.

Stoa is a clean-room rebuild of the ideas in [Ortix](https://systembionic.com/ortix), made with the Ortix team's blessing: spaces, profiles that keep accounts apart, collections, split view, a media dock, an ad and tracker blocker, Chrome Web Store extensions, and passwords behind Touch ID. Everything the original does except the AI layer.

**Status:** pre-alpha. Nothing runs yet beyond a window. See [docs/spec](docs/spec/) for the behavior spec as it fills in.

## Requirements

- macOS 26 or later, Apple silicon
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
xcodegen generate
open Stoa.xcodeproj
```

Core modules build and test without Xcode:

```bash
swift test
```

If the checkout lives in an iCloud-synced folder (Desktop, Documents), Finder metadata on build products makes `codesign` refuse the test bundle. Build outside the synced tree:

```bash
swift test --scratch-path ~/Library/Caches/stoa-spm
```

## Layout

| Path | What |
|---|---|
| `App/` | The macOS app target (SwiftUI shell, entitlements, Info.plist) |
| `Sources/StoaCore/` | Platform-independent models and persistence: spaces, profiles, tabs, collections |
| `Sources/StoaWeb/` | WebKit layer: data stores, content rule lists, extensions |
| `Tests/` | Swift Testing suites for the core modules |
| `docs/spec/` | Behavior spec derived from analysis, feature by feature |
| `project.yml` | XcodeGen project definition (the `.xcodeproj` is generated, not committed) |

## How it was built

Feature behavior was studied with [REA](https://github.com/morluto/rea) and Ghidra, then written fresh. No Ortix code, assets, or strings are used; the spec records behavior and evidence, and the implementation is Stoa's own.

## License

[MIT](LICENSE) © 2026 Conrad Close
