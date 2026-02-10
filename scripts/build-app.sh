#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (override via environment) ---
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Clockwork Claude"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE_NAME="ClockworkClaude"

echo "==> Building $APP_NAME $VERSION (build $BUILD_NUMBER)"
echo "    Configuration: $CONFIGURATION"
echo "    Signing identity: $CODESIGN_IDENTITY"
echo ""

# --- Step 1: Build with SPM ---
echo "==> swift build -c $CONFIGURATION"
cd "$PROJECT_DIR"
swift build -c "$CONFIGURATION"

# --- Step 2: Create .app bundle structure ---
echo "==> Creating app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/$CONFIGURATION/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy SPM resource bundle into Resources (for Bundle.safeModule)
RESOURCE_BUNDLE=".build/$CONFIGURATION/ClockworkClaude_ClockworkClaude.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "    Copied SPM resource bundle"
fi

# Copy and patch Info.plist
sed -e "s/\${VERSION}/$VERSION/g" \
    -e "s/\${BUILD_NUMBER}/$BUILD_NUMBER/g" \
    "$PROJECT_DIR/Resources/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"

# Copy custom fonts (check both locations)
for dir in "$PROJECT_DIR/Sources/ClockworkClaude/Resources" "$PROJECT_DIR/Resources"; do
    for font in "$dir"/*.TTF "$dir"/*.ttf "$dir"/*.otf; do
        [ -f "$font" ] && cp "$font" "$APP_BUNDLE/Contents/Resources/"
    done
done

# Copy logo if it exists (check both locations, prefer SVG)
logo_copied=false
for ext in svg png; do
    for dir in "$PROJECT_DIR/Sources/ClockworkClaude/Resources" "$PROJECT_DIR/Resources"; do
        if [ -f "$dir/logo.$ext" ]; then
            cp "$dir/logo.$ext" "$APP_BUNDLE/Contents/Resources/logo.$ext"
            logo_copied=true
            break 2
        fi
    done
done

# Copy app icon if it exists
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    # Add icon reference to Info.plist
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
fi

# Write PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "    Bundle: $APP_BUNDLE"

# Strip extended attributes that break codesign
xattr -cr "$APP_BUNDLE"

# --- Step 3: Code sign ---
echo "==> Code signing"
codesign --force --deep --sign "$CODESIGN_IDENTITY" \
    --entitlements "$PROJECT_DIR/Resources/ClockworkClaude.entitlements" \
    --options runtime \
    "$APP_BUNDLE"

echo "    Verifying signature..."
codesign -vv "$APP_BUNDLE"

# --- Step 4: Create DMG ---
DMG_NAME="ClockworkClaude-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg-staging"

echo "==> Creating DMG: $DMG_NAME"
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"

cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

# --- Step 5: Create zip ---
ZIP_NAME="ClockworkClaude-${VERSION}.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"

echo "==> Creating zip: $ZIP_NAME"
rm -f "$ZIP_PATH"
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"
cd "$PROJECT_DIR"

# --- Done ---
echo ""
echo "==> Build complete!"
echo "    App:  $APP_BUNDLE"
echo "    DMG:  $DMG_PATH"
echo "    Zip:  $ZIP_PATH"
