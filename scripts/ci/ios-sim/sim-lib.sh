# shellcheck shell=bash disable=SC2034,SC2154
# Shared by smoke-test.sh and call-test.sh: a new simulator and onboarding to the chat list, driven with the ui helper.
# Source it after setting ui to the helper's path; each function acts on the simulator in SIM_UDID.
# SC2034, SC2154: bundle_id and app_group are for the scripts that source it, which set ui.

bundle_id=chat.simplex.app
app_group=group.chat.simplex.app

# Creates and boots an iPhone 17 simulator named $1, opens its window and prints its UDID.
new_simulator() {
  local runtime udid
  runtime=com.apple.CoreSimulator.SimRuntime.iOS-$(xcrun --sdk iphonesimulator --show-sdk-version | tr . -)
  udid=$(xcrun simctl create "$1" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
  echo "simulator $1 $udid, runtime $runtime" >&2
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b > /dev/null
  open -a Simulator --args -CurrentDeviceUDID "$udid"
  echo "$udid"
}

expect_in_tree() {
  local tree
  tree=$("$ui" tree)
  if ! grep -q "$@" <<< "$tree"; then
    echo "error: ${*: -1} is not in the accessibility tree"
    exit 1
  fi
}

# iOS asks once whether the app may send notifications. The tree sometimes shows the app under this alert rather than
# the alert (run 38895987656), so its Allow button is also looked for at its place.
allow_notifications() {
  local deadline=$((SECONDS + 30)) element
  while [ "$SECONDS" -lt "$deadline" ]; do
    if "$ui" tap Allow 1; then
      return
    fi
    element=$("$ui" point 275 518 || true)
    if grep -qF '"Allow"' <<< "$element"; then
      "$ui" tap-xy 275 518
      return
    fi
    sleep 2
  done
  echo "no notifications alert to allow"
}

# From the app's first screen to the chat list, creating the profile $1; shot names start with $2.
onboard() {
  local name=$1 prefix=${2:-}
  "$ui" wait "Get started" 180
  "$ui" shot "${prefix}first-screen"
  "$ui" tap "Get started"

  "$ui" wait "Create profile" 30
  "$ui" tap-value "Enter profile name..."
  "$ui" type "$name"
  "$ui" shot "${prefix}profile-name"
  "$ui" tap "Create profile"

  "$ui" wait "Continue" 60
  "$ui" shot "${prefix}your-network"
  "$ui" tap "Continue"

  "$ui" wait "Accept" 30
  "$ui" shot "${prefix}network-commitments"
  "$ui" tap "Accept"

  sleep 5
  "$ui" shot "${prefix}after-onboarding"
  allow_notifications
  "$ui" shot "${prefix}notifications-allowed"

  "$ui" wait "Talk to someone" 60
  "$ui" shot "${prefix}chat-list"
}
