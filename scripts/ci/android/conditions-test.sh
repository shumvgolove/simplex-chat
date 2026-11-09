#!/bin/bash

# Tests which notice the app opens over the chat list (What's new, What's new with the link to updated conditions, the
# usage conditions sheet, or none) for each state of the usage conditions and of What's new, after each way the chat
# list is shown again: a cold start, Back and reopen, Home and reopen, and a rotation.
# Usage: scripts/ci/android/conditions-test.sh <apk> <output dir> <pr|base>
# pr expects the behaviour of the branch, base the behaviour of master before it. The states are set with the app's
# chat console (/sql chat) and its What's new preference. Results: results.md in the output dir and the job summary.

set -euo pipefail

apk=$1
export UI_OUT=$2
variant=$3
case "$variant" in
  pr | base) ;;
  *)
    echo "error: the variant is pr or base"
    exit 1
    ;;
esac
here=$(cd "$(dirname "$0")" && pwd)
ui=$here/ui
package=chat.simplex.app
chat_list="Start new chat"
observe_secs=12
seen_version=v7.1
old_version=v6.5
results=$UI_OUT/results.md
failed=0

log() {
  echo "$(date -u +%H:%M:%S) $*"
}

launch() {
  local activity
  activity=$(adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$package" | tail -n 1)
  adb shell am start -W -n "$activity" > /dev/null
  "$ui" wait "$chat_list" 90
}

app_pid() {
  adb shell pidof "$package" || true
}

cold() {
  adb shell am force-stop "$package"
  launch
}

back_reopen() {
  "$ui" key BACK
  sleep 2
  launch
}

home_reopen() {
  "$ui" key HOME
  sleep 2
  launch
}

rotate() {
  adb shell settings put system accelerometer_rotation 0
  adb shell settings put system user_rotation "$1"
  sleep 3
  "$ui" wait "$chat_list" 30
}

# swipes up in the middle of the screen, in its current orientation
scroll_down() {
  local w h
  read -r w h < <(adb shell dumpsys window displays | grep -o 'cur=[0-9]*x[0-9]*' | head -n 1 | tr 'x=' '  ' | awk '{ print $2, $3 }')
  "$ui" scroll $((w / 2)) $((h * 3 / 4)) down "$1" > /dev/null
}

# The notice on screen within observe_secs of the chat list: conditions, whatsnew+link, whatsnew or none.
observe() {
  local deadline=$((SECONDS + observe_secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if "$ui" find "Accept conditions" > /dev/null 2>&1; then
      echo conditions
      return
    fi
    if "$ui" find "New in" > /dev/null 2>&1; then
      if "$ui" find "View updated conditions" > /dev/null 2>&1; then
        echo whatsnew+link
      else
        scroll_down 4
        if "$ui" find "View updated conditions" > /dev/null 2>&1; then
          echo whatsnew+link
        else
          echo whatsnew
        fi
      fi
      return
    fi
    sleep 1
  done
  echo none
}

deadline_shown() {
  if "$ui" find "Conditions will be automatically accepted for enabled operators on" > /dev/null 2>&1; then
    echo yes
  else
    scroll_down 4
    if "$ui" find "Conditions will be automatically accepted for enabled operators on" > /dev/null 2>&1; then
      echo yes
    else
      echo no
    fi
  fi
}

close_notice() {
  case "$1" in
    whatsnew | whatsnew+link)
      if ! "$ui" click-text OK 3 > /dev/null 2>&1; then
        scroll_down 6
        "$ui" click-text OK 5 > /dev/null 2>&1 || "$ui" key BACK
      fi
      ;;
    conditions) "$ui" key BACK ;;
  esac
  "$ui" wait "$chat_list" 15
  # the notice is closed, not replaced by another one
  sleep 2
  if "$ui" find "New in" > /dev/null 2>&1 || "$ui" find "Accept conditions" > /dev/null 2>&1; then
    "$ui" shot notice-after-close
    "$ui" key BACK
  fi
}

record() {
  local name=$1 trigger=$2 expected=$3 observed=$4 process=$5 deadline=$6 status=PASS
  if [ "$expected" != "$observed" ]; then
    status=FAIL
    failed=$((failed + 1))
    echo "::error::$variant $name ($trigger): expected $expected, observed $observed"
  fi
  echo "| $name | $trigger | $expected | $observed | $process | $deadline | $status |" >> "$results"
  log "$status $name ($trigger): expected $expected, observed $observed, $process"
}

# step <name> <trigger> <expected with the branch> <expected on master> [accept]
step() {
  local name=$1 trigger=$2 expected observed before after process deadline=-
  if [ "$variant" = pr ]; then expected=$3; else expected=$4; fi
  if [ "$trigger" != cold ]; then
    "$ui" find "$chat_list" > /dev/null || fail "no chat list before $name"
  fi
  before=$(app_pid)
  case "$trigger" in
    cold) cold ;;
    back) back_reopen ;;
    home) home_reopen ;;
    landscape) rotate 1 ;;
    portrait) rotate 0 ;;
  esac
  after=$(app_pid)
  if [ "$trigger" = cold ]; then
    process=new
  elif [ -n "$before" ] && [ "$before" = "$after" ]; then
    process=same
  else
    process="restarted ($before -> $after)"
  fi
  observed=$(observe)
  "$ui" shot "$variant-$name-$observed" > /dev/null
  if [ "$observed" = conditions ]; then
    deadline=$(deadline_shown)
  fi
  record "$name" "$trigger" "$expected" "$observed" "$process" "$deadline"
  if [ "${5:-}" = accept ] && [ "$observed" = conditions ]; then
    "$ui" click-text "Accept conditions" 10
    if "$ui" wait "$chat_list" 15 && ! "$ui" find "Accept conditions" > /dev/null 2>&1; then
      record "$name-accept" "Accept conditions" closed closed same -
    else
      record "$name-accept" "Accept conditions" closed open same -
      "$ui" key BACK
    fi
    "$ui" shot "$variant-$name-accepted" > /dev/null
  else
    close_notice "$observed"
  fi
}

fail() {
  echo "error: $*"
  "$ui" shot failure || true
  exit 1
}

# Settings > App version > Developer tools > Chat console, from the chat list
open_console() {
  local name code
  name=$(adb shell dumpsys package "$package" | sed -n 's/^ *versionName=//p' | head -n 1 | tr -d '\r')
  code=$(adb shell dumpsys package "$package" | sed -n 's/^ *versionCode=\([0-9]*\).*/\1/p' | head -n 1)
  "$ui" click-text "profile image placeholder" 10
  "$ui" click-text "Settings" 10
  for _ in 1 2 3 4 5 6 7 8; do
    "$ui" find "$name ($code)" > /dev/null 2>&1 && break
    scroll_down 2
  done
  "$ui" click-text "$name ($code)" 10
  "$ui" click-text "Developer tools" 10
  "$ui" click-text "Chat console" 10
  "$ui" wait "Send Message" 5 > /dev/null 2>&1 || true
}

console_field() {
  "$ui" tree | sed -n -E 's/^EditText .* at ([0-9]+),([0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/p' |
    awk '{ print $1 + int($3 / 2), $2 + int($4 / 2); exit }'
}

console_command() {
  local x y
  read -r x y < <(console_field) || fail "no chat console field"
  "$ui" click "$x" "$y"
  "$ui" type "$1"
  "$ui" click-text "Send Message" 10
  sleep 3
}

sql() {
  log "sql: $*"
  open_console
  for statement in "$@"; do
    console_command "/sql chat $statement"
  done
  "$ui" shot "$variant-sql" > /dev/null
  # stopped: the next start, a step's, is the first with the new state
  adb shell am force-stop "$package"
}

# notified_at of the conditions, the only row of a new user's usage_conditions
check_notified() {
  local name=$1 expected=$2 observed
  open_console
  console_command "/sql chat select 'NOTIFIED_'||count(notified_at) from usage_conditions"
  "$ui" click-text "result" 10 || true
  sleep 1
  "$ui" shot "$variant-$name" > /dev/null
  observed=$("$ui" text | grep -o 'NOTIFIED_[0-9]' | head -n 1 || true)
  record "$name" "/sql chat select" "NOTIFIED_$expected" "${observed:-unknown}" same -
  adb shell am force-stop "$package"
}

# stops the app: the next step starts it cold
prefs() {
  "$ui" prefs "WhatsNewVersion=$1"
}

"$here/smoke-test.sh" "$apk" "$UI_OUT" onboarding
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
{
  echo "### Notices over the chat list: $variant"
  echo
  echo "| Step | Trigger | Expected | Observed | Process | Deadline shown | Result |"
  echo "|---|---|---|---|---|---|---|"
} > "$results"

# A: conditions accepted, What's new seen
prefs "$seen_version"
step A1 cold none none
step A2 back none none

# B: conditions accepted, What's new of a new version
prefs "$old_version"
step B1 cold whatsnew whatsnew
step B2 back none none
step B3 cold none none

# C: updated conditions, never notified, What's new of a new version
sql "delete from operator_usage_conditions" "update usage_conditions set notified_at=null"
prefs "$old_version"
step C1 cold whatsnew+link whatsnew+link
step C2 back none whatsnew+link
step C3 home none none
step C4 landscape none whatsnew+link
step C5 portrait none whatsnew+link
step C6 back none whatsnew+link
check_notified C7-notified 1
step C8 cold conditions none
step C9 back none none

# D: updated conditions, never notified, What's new seen
sql "update usage_conditions set notified_at=null"
step D1 cold conditions whatsnew+link
step D2 back none whatsnew+link
step D3 landscape none whatsnew+link
step D4 portrait none whatsnew+link
check_notified D5-notified 1
step D6 cold conditions none
step D7 cold conditions none

# E: updated conditions required, past their deadline
sql "update usage_conditions set created_at='2025-01-01 00:00:00'"
step E1 cold conditions none
step E2 back none none

# F: the conditions accepted from the sheet
if [ "$variant" = pr ]; then
  step F1 cold conditions none accept
  step F2 back none none
  step F3 cold none none
  # G: accepted again, What's new of a new version
  prefs "$old_version"
  step G1 cold whatsnew whatsnew
  step G2 back none none
fi

cat "$results"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$results" >> "$GITHUB_STEP_SUMMARY"
fi
if [ "$failed" -gt 0 ]; then
  echo "error: $failed steps differ from the expected notice"
  exit 1
fi
echo "all steps show the expected notice"
