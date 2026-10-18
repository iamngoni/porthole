#!/bin/zsh
# Builds the Flutter app for TestFlight: an App Store Connect .ipa, signed automatically with the team in
# the Xcode project. Upload build/ios/ipa/*.ipa with Transporter or `xcrun altool --upload-package`.
# BUILD_NUMBER overrides the build number (default: the date and hour, so each build is higher).
set -euo pipefail
root="${0:A:h:h}"
build="${BUILD_NUMBER:-$(date +%y%m%d%H)}"

cd "$root/app"
flutter build ipa --release --export-method app-store-connect --build-number "$build"
print "Built build $build: $(print -l "$root"/app/build/ios/ipa/*.ipa)"
