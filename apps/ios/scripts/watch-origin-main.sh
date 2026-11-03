#!/usr/bin/env bash
# Watches origin/main for new commits and wakes the Cursor iOS integrate loop.
set -euo pipefail
REPO="${REPO:-/Users/meghpatel/Documents/StingerDelay-3D}"
STATE="${STATE:-/tmp/stinger-ios-last-integrated-sha}"
INTERVAL="${INTERVAL:-30}"

cd "$REPO"
git rev-parse origin/main > "$STATE" 2>/dev/null || git fetch origin main -q
LAST="$(cat "$STATE" 2>/dev/null || true)"

while true; do
  git fetch origin main -q 2>/dev/null || true
  CUR="$(git rev-parse origin/main 2>/dev/null || true)"
  if [[ -n "$CUR" && "$CUR" != "$LAST" ]]; then
    echo "AGENT_LOOP_WAKE_stinger_ios_integrate {\"prompt\":\"origin/main advanced from ${LAST:-none} to $CUR. Pull, classify changed paths, integrate into apps/ios/BuzzRoute per Continuous Repo Integrate playbook, xcodebuild validate, push apps/ios if changed.\",\"old\":\"${LAST:-}\",\"new\":\"$CUR\"}"
    LAST="$CUR"
    echo "$CUR" > "$STATE"
  fi
  sleep "$INTERVAL"
done
