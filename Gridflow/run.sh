#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

cd "$ROOT_DIR"
swift run --disable-sandbox --scratch-path "$ROOT_DIR/.build/swiftpm" "Gridflow"
