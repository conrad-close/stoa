<div align="center">
  <img width="200" height="200" src="/assets/stoa-icon.png" alt="Stoa icon">
  <h1><b>Stoa</b></h1>
  <p>A sidebar-first macOS browser. A fork of <a href="https://github.com/nook-browser/Nook">Nook</a>.</p>
</div>

## What This Is

Stoa is a fork of Nook, the fast, minimal WebKit browser by Bain Gurley and contributors. Stoa
keeps Nook's engine (spaces, profiles, Chrome/Firefox/Safari extensions, the built-in ad blocker,
Peek, the command bar, sidebar media controls, the AI chat) and is building a different look and
set of layout features on top. Planned, not shipped yet:

- A home page for new tabs
- Photo wallpapers and a richer per-space look
- A compact, icon-only sidebar rail
- A media dock with artwork, live levels, and transport controls
- Split view up to four panes with draggable seams
- Collections with per-folder color and symbol

Stoa is not Nook and is not endorsed by the Nook project. Bugs in Stoa belong here, not upstream.

## Building

macOS 15.5+ on Apple Silicon, Xcode 27. The Xcode project and scheme keep Nook's names so upstream
changes merge cleanly; the built app is `Stoa.app` with bundle id `com.conradclose.stoa`.

```bash
xcodebuild -downloadComponent MetalToolchain   # once
xcodebuild -scheme Nook -configuration Release -arch arm64 -derivedDataPath ~/Library/Caches/stoa-build \
  ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_ENTITLEMENTS="$PWD/Nook/Nook-CI.entitlements" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  RUNTIME_EXCEPTION_DISABLE_LIBRARY_VALIDATION=YES
ditto ~/Library/Caches/stoa-build/Build/Products/Release/Stoa.app /Applications/Stoa.app
```

Ad-hoc signing has no team ID, so the hardened runtime refuses to load the bundled Sparkle
framework unless library validation is relaxed; a Developer ID build would not need that flag.

## Staying Current With Nook

`upstream` points at `nook-browser/Nook`. Stoa's work lives on `main`; `develop` mirrors upstream.

```bash
git fetch upstream --tags
git merge upstream/develop   # or a release tag such as v1.5.0
```

## License

GPL-3.0, inherited from Nook. See [LICENSE](./LICENSE). The Nook name and icon are Nook's
trademarks and are not used by Stoa (see [TRADEMARK.md](./TRADEMARK.md)).
