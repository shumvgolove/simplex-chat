#!/bin/bash

# Builds the iOS app for the simulator into <derived data>/Build/Products/Debug-iphonesimulator/SimpleX.app.
# With a git ref, it builds the app with the WebRTC package that ref pins, such as the released app's, and then
# restores the branch's pin, so the call test can call between the branch's WebRTC and that one.
# Usage: scripts/ci/ios-sim/build-app.sh <derived data> [git ref for WebRTC]

set -euo pipefail

derived_data=$1
webrtc_ref=${2:-}
project=apps/ios/SimpleX.xcodeproj
pins=("$project/project.pbxproj" "$project/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

webrtc_revision() {
  grep -A3 'simplex-chat/WebRTC' | grep -oE '[0-9a-f]{40}' | head -n 1
}

if [ -n "$webrtc_ref" ]; then
  git fetch --depth 1 origin "$webrtc_ref"
  current=$(webrtc_revision < "${pins[1]}")
  other=$(git show "FETCH_HEAD:${pins[1]}" | webrtc_revision)
  echo "building with the WebRTC of $webrtc_ref ($other) in place of $current"
  trap 'git checkout -- "${pins[@]}"' EXIT
  sed -i '' "s/$current/$other/" "${pins[@]}"
fi

xcodebuild build -quiet \
  -project "$project" \
  -scheme "SimpleX (iOS)" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_data" \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ARCHS=arm64 \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER=
