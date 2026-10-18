#!/bin/zsh
# Builds Porthole Host for people outside the App Store: archived, signed with Developer ID, notarized by
# Apple and stapled, then zipped. Notarizing needs a keychain profile made once with
# `xcrun notarytool store-credentials` (NOTARY_PROFILE, default porthole-notary). Pass --no-notarize to
# stop after signing. BUILD_NUMBER overrides the build number (default: the date and hour). Signs with the
# team in project.yml (see project.example.yml).
set -euo pipefail
root="${0:A:h:h}"
build="${BUILD_NUMBER:-$(date +%y%m%d%H)}"
profile="${NOTARY_PROFILE:-porthole-notary}"
out="$root/build/release/host"

if [[ ! -f "$root/project.yml" ]]; then
  print -u2 "No project.yml: copy project.example.yml to project.yml and fill in your team first."
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"
cd "$root"
xcodegen generate --quiet
xcodebuild -project Porthole.xcodeproj -scheme PortholeHost -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$out/PortholeHost.xcarchive" \
  CURRENT_PROJECT_VERSION="$build" archive
# Export with the Developer ID certificate of the team that signed the archive (project.yml's).
team="$(codesign -dv "$out/PortholeHost.xcarchive/Products/Applications/PortholeHost.app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
cat > "$out/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$out/PortholeHost.xcarchive" \
  -exportOptionsPlist "$out/export.plist" -exportPath "$out"

app="$out/PortholeHost.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
codesign --verify --deep --strict --verbose=2 "$app"
if [[ "${1:-}" == --no-notarize ]]; then
  print "Signed, not notarized: $app"
  exit 0
fi

ditto -c -k --keepParent "$app" "$out/notarize.zip"
xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"
rm "$out/notarize.zip"
ditto -c -k --keepParent "$app" "$out/Porthole-Host-$version-$build.zip"
print "Notarized: $out/Porthole-Host-$version-$build.zip"
