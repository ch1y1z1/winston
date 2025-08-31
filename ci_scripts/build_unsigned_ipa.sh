#!/usr/bin/env bash

# Build an unsigned iOS IPA for the Winston app.
# - Prebuilds the web extension assets
# - Archives the app (no code signing)
# - Packages Payload/ into an unsigned .ipa
#
# Usage:
#   bash ci_scripts/build_unsigned_ipa.sh [-s scheme] [-c configuration] [-p project] [-o outdir]
#
# Defaults:
#   scheme=winston, configuration=Release, project=winston.xcodeproj, outdir=build

set -euo pipefail

scheme="winston"
configuration="Release"
project="winston.xcodeproj"
outdir="build"

while getopts ":s:c:p:o:" opt; do
  case $opt in
    s) scheme="$OPTARG" ;;
    c) configuration="$OPTARG" ;;
    p) project="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    *)
      echo "Usage: $0 [-s scheme] [-c configuration] [-p project] [-o outdir]" >&2
      exit 2
      ;;
  esac
done

echo "==> Xcode: $(xcodebuild -version | tr '\n' ' | ')"
echo "==> Swift: $(swift --version | head -n 1)"

mkdir -p "$outdir"

echo "==> Prebuilding web extension (winston-everywhere)"
pushd "winston-everywhere" >/dev/null
if command -v npm >/dev/null 2>&1; then
  if [ -f package-lock.json ]; then
    npm ci
  else
    npm install
  fi
  npm run build
else
  echo "WARN: npm is not available; skipping web extension build" >&2
fi
popd >/dev/null

archive_path="$outdir/${scheme}.xcarchive"

echo "==> Archiving (unsigned)"
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -sdk iphoneos \
  -archivePath "$archive_path" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  SKIP_INSTALL=NO

apps_dir="$archive_path/Products/Applications"
if [ ! -d "$apps_dir" ]; then
  echo "ERROR: Applications folder not found in archive: $apps_dir" >&2
  exit 1
fi

app_path=$(find "$apps_dir" -maxdepth 1 -name "*.app" | head -n 1)
if [ -z "$app_path" ]; then
  echo "ERROR: .app not found in $apps_dir" >&2
  exit 1
fi

info_plist="$app_path/Info.plist"
if [ ! -f "$info_plist" ]; then
  echo "ERROR: Info.plist not found in app bundle" >&2
  exit 1
fi

short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null || echo "")
build_number=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist" 2>/dev/null || echo "")
product_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null || basename "$app_path" .app)

timestamp=$(date +%Y%m%d-%H%M%S)
ipa_name="${product_name}-${short_version:-unknown}(${build_number:-0})-${timestamp}.ipa"

echo "==> Packaging unsigned IPA: $ipa_name"
tmp_payload="$outdir/Payload"
rm -rf "$tmp_payload" "$outdir/$ipa_name"
mkdir -p "$tmp_payload"
cp -R "$app_path" "$tmp_payload/"
pushd "$outdir" >/dev/null
zip -qr "$ipa_name" Payload
popd >/dev/null
rm -rf "$tmp_payload"

echo "==> Done: $outdir/$ipa_name"
