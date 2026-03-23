# Gridflow macOS Package

This directory contains the Swift package for the Gridflow macOS app. The repository root `README.md` is the primary public project overview; this file is the package-level quick start.

## Run

Open `Gridflow/` in Xcode and run the `Gridflow` target, or use Terminal:

```bash
cd "/path/to/repo/Gridflow"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
swift run --disable-sandbox --scratch-path "$PWD/.build/swiftpm" Gridflow
```

## Build A DMG

```bash
cd "/path/to/repo/Gridflow"
APP_VERSION=1.0.0 APP_BUILD_NUMBER=1 ./scripts/build_dmg.sh
```

## Notes

- Product name: `Gridflow`
- Local app data lives in `~/Library/Application Support/Gridflow/storage.json`
