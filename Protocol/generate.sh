#!/bin/zsh
# Regenerates the Swift and Dart code for Protocol/porthole.proto. Run from anywhere; commit the output.
# Needs protoc (brew install protobuf) and, for Dart, protoc_plugin (dart pub global activate protoc_plugin).
set -euo pipefail
root=${0:A:h:h}
kit="$root/Packages/PortholeKit"

# The Swift generator is built from the exact swift-protobuf version the package depends on.
swift package --package-path "$kit" resolve >/dev/null
swift build --package-path "$kit/.build/checkouts/swift-protobuf" -c release --product protoc-gen-swift >/dev/null
swift_plugin="$kit/.build/checkouts/swift-protobuf/.build/release/protoc-gen-swift"

swift_out="$kit/Sources/PortholeProtocol/Generated"
mkdir -p "$swift_out"
protoc --proto_path="$root/Protocol" --plugin=protoc-gen-swift="$swift_plugin" \
  --swift_out="$swift_out" --swift_opt=Visibility=Internal porthole.proto
echo "Swift: $swift_out/porthole.pb.swift"

dart_out="$root/Protocol/dart/lib/src/generated"
if [[ -d "$root/Protocol/dart" ]]; then
  mkdir -p "$dart_out"
  protoc --proto_path="$root/Protocol" --plugin=protoc-gen-dart="$HOME/.pub-cache/bin/protoc-gen-dart" \
    --dart_out="$dart_out" porthole.proto
  echo "Dart: $dart_out"
fi
