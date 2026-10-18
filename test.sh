#!/bin/zsh
# Runs every test: the Swift package, then the Dart protocol package against the same vectors and, over
# loopback TCP, against the Swift host's own connection code, then the Flutter app.
set -euo pipefail
root="${0:A:h}"

cd "$root/Packages/PortholeKit"
swift test
swift build --product porthole-interop-host
export PORTHOLE_INTEROP_HOST="$(swift build --show-bin-path)/porthole-interop-host"

cd "$root/Protocol/dart"
dart pub get >/dev/null
dart analyze
dart test

cd "$root/app"
flutter pub get >/dev/null
flutter analyze
flutter test
