#!/bin/bash

# Runs the SimpleX Calls tests (apps/ios/SimpleX Calls) in the booted simulator SIM_UDID: two call clients in the app's
# process make an encrypted video call. The app needs sounds/video.mp4 (test-video.swift) in place of the camera.
# Usage: scripts/ci/ios-sim/call-xctest.sh <derived data of the app's build> <output dir>

set -euo pipefail

derived=$1
out=$2
: "${SIM_UDID:?SIM_UDID must be the booted simulator}"
mkdir -p "$out"

xcode=(
  -project apps/ios/SimpleX.xcodeproj
  -scheme "SimpleX (iOS)"
  -configuration Debug
  -destination "id=$SIM_UDID"
  -derivedDataPath "$derived"
  -onlyUsePackageVersionsFromResolvedFile
  -skipPackagePluginValidation
  -skipMacroValidation
  -only-testing:"SimpleX Calls"
  ARCHS=arm64
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY=-
  DEVELOPMENT_TEAM=
  PROVISIONING_PROFILE_SPECIFIER=
)

xcodebuild build-for-testing -quiet "${xcode[@]}"
xcrun simctl privacy "$SIM_UDID" grant microphone chat.simplex.app
xcrun simctl privacy "$SIM_UDID" grant camera chat.simplex.app
xcodebuild test-without-building -resultBundlePath "$out/CallTests.xcresult" "${xcode[@]}"
