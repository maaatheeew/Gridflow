#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived-data"
BUILD_PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/Release"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_NAME="Gridflow"
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-1}"
DMG_NAME="${DMG_NAME:-$APP_NAME-$APP_VERSION.dmg}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME"
APP_IDENTIFIER="com.matthewavgul.gridflow"
COPYRIGHT_LINE="${COPYRIGHT_LINE:-© Matthew Avgul}"
ICON_SOURCE_DIR="$ROOT_DIR/Sources/GridflowApp/Resources/AppIcon.icon"
RESOURCE_BUNDLE_PATH="$BUILD_PRODUCTS_DIR/Gridflow_GridflowApp.bundle"
EXECUTABLE_PATH="$BUILD_PRODUCTS_DIR/Gridflow"
ICON_INFO_PLIST="$DIST_DIR/AppIcon-info.plist"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -scheme Gridflow \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Missing built executable at $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE_PATH" ]]; then
  echo "Missing resource bundle at $RESOURCE_BUNDLE_PATH" >&2
  exit 1
fi

if [[ ! -d "$ICON_SOURCE_DIR" ]]; then
  echo "Missing app icon at $ICON_SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$RESOURCE_BUNDLE_PATH" "$APP_BUNDLE/Contents/Resources/"

xcrun actool \
  --output-format human-readable-text \
  --notices \
  --warnings \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --standalone-icon-behavior all \
  --app-icon AppIcon \
  --output-partial-info-plist "$ICON_INFO_PLIST" \
  --compile "$APP_BUNDLE/Contents/Resources" \
  "$ICON_SOURCE_DIR"

plutil -create xml1 "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $APP_IDENTIFIER" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $APP_BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.productivity" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string $COPYRIGHT_LINE" "$APP_BUNDLE/Contents/Info.plist"

rm -f "$ICON_INFO_PLIST"

chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
codesign --force --deep --sign - "$APP_BUNDLE"

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "App bundle: $APP_BUNDLE"
echo "Version: $APP_VERSION ($APP_BUILD_NUMBER)"
echo "DMG: $DMG_PATH"
