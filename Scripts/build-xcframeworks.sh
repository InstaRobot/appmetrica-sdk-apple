#!/usr/bin/env bash
# Build distributable XCFrameworks (iOS device + Simulator + macOS) from SwiftPM schemes.
# Run from repo root. Output: build/xcframeworks/*.xcframework
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/build/xcframeworks"
WORK="${ROOT}/build/xcf-work"
rm -rf "$OUT" "$WORK"
mkdir -p "$OUT" "${WORK}/archives" "${WORK}/lib"

# Public library products (scheme name = product name)
SCHEMES=(
  AppMetricaCore
  AppMetricaCrashes
  AppMetricaAdSupport
  AppMetricaWebKit
  AppMetricaLibraryAdapter
  AppMetricaScreenshot
  AppMetricaIDSync
  AppMetricaAnalytics
)

find_object_in_archive() {
  local archive_root="$1"
  local scheme="$2"
  local found
  found="$(find "${archive_root}/Products" -name "${scheme}.o" -print -quit)"
  if [[ -z "$found" || ! -f "$found" ]]; then
    echo "::error::Missing ${scheme}.o in archive ${archive_root}" >&2
    exit 1
  fi
  printf '%s' "$found"
}

archive_scheme() {
  local scheme="$1"
  local destination="$2"
  local slug="$3"
  local archive_path="${WORK}/archives/${scheme}-${slug}.xcarchive"
  local dd="${WORK}/dd/${scheme}-${slug}"
  rm -rf "$dd"
  echo "Archiving ${scheme} (${slug})..."
  xcodebuild archive \
    -scheme "$scheme" \
    -destination "$destination" \
    -archivePath "$archive_path" \
    -derivedDataPath "$dd" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_VALIDATE_MODULE_INTERFACE=NO
}

build_one_xcframework() {
  local scheme="$1"
  archive_scheme "$scheme" "generic/platform=iOS" "iphoneos"
  archive_scheme "$scheme" "generic/platform=iOS Simulator" "iphonesimulator"
  archive_scheme "$scheme" "generic/platform=macOS" "macos"

  local ios_o sim_o mac_o
  ios_o="$(find_object_in_archive "${WORK}/archives/${scheme}-iphoneos.xcarchive" "$scheme")"
  sim_o="$(find_object_in_archive "${WORK}/archives/${scheme}-iphonesimulator.xcarchive" "$scheme")"
  mac_o="$(find_object_in_archive "${WORK}/archives/${scheme}-macos.xcarchive" "$scheme")"

  cp "$ios_o" "${WORK}/lib/${scheme}-ios.a"
  cp "$sim_o" "${WORK}/lib/${scheme}-sim.a"
  cp "$mac_o" "${WORK}/lib/${scheme}-mac.a"

  local hdr="${ROOT}/${scheme}/Sources/include"
  if [[ -d "$hdr" ]]; then
    xcodebuild -create-xcframework \
      -library "${WORK}/lib/${scheme}-ios.a" -headers "$hdr" \
      -library "${WORK}/lib/${scheme}-sim.a" -headers "$hdr" \
      -library "${WORK}/lib/${scheme}-mac.a" -headers "$hdr" \
      -output "${OUT}/${scheme}.xcframework"
  else
    xcodebuild -create-xcframework \
      -library "${WORK}/lib/${scheme}-ios.a" \
      -library "${WORK}/lib/${scheme}-sim.a" \
      -library "${WORK}/lib/${scheme}-mac.a" \
      -output "${OUT}/${scheme}.xcframework"
  fi
}

cd "$ROOT"
for scheme in "${SCHEMES[@]}"; do
  build_one_xcframework "$scheme"
done

echo "XCFrameworks written to ${OUT}"
ls -la "$OUT"
