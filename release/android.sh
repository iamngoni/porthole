#!/bin/zsh
# Builds the Android app bundle for Play internal testing, signed with the upload key in
# app/android/key.properties. Upload build/app/outputs/bundle/release/app-release.aab in Play Console.
# BUILD_NUMBER overrides the version code (default: the date and hour, so each build is higher).
set -euo pipefail
root="${0:A:h:h}"
build="${BUILD_NUMBER:-$(date +%y%m%d%H)}"

if [[ ! -f "$root/app/android/key.properties" ]]; then
  print -u2 "No upload key: create app/android/key.properties first (see README, Test builds)."
  exit 1
fi

cd "$root/app"
flutter build appbundle --release --build-number "$build"
print "Built version code $build: $root/app/build/app/outputs/bundle/release/app-release.aab"
