#!/bin/zsh
# Draws Porthole's home-screen icon (test/app_icon_test.dart) and puts it where iOS and Android look:
# one 1024-pixel icon for iOS, which Xcode scales, and for Android a plain icon plus an adaptive one.
set -euo pipefail
app="${0:A:h:h}"
layers="$(mktemp -d)"
trap 'rm -rf "$layers"' EXIT

cd "$app"
APP_ICONS="$layers" flutter test test/app_icon_test.dart

ios="$app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
rm -f "$ios"/*.png
# The App Store refuses icons with an alpha channel, even a fully opaque one.
swift - "$layers/whole.png" "$ios/AppIcon-1024.png" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
let args = CommandLine.arguments
let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
CGImageDestinationFinalize(destination)
SWIFT
cat > "$ios/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

res="$app/android/app/src/main/res"
for density icon layer in mdpi 48 108 hdpi 72 162 xhdpi 96 216 xxhdpi 144 324 xxxhdpi 192 432; do
  mkdir -p "$res/mipmap-$density"
  sips -z "$icon" "$icon" "$layers/whole.png" --out "$res/mipmap-$density/ic_launcher.png" >/dev/null
  sips -z "$layer" "$layer" "$layers/foreground.png" --out "$res/mipmap-$density/ic_launcher_foreground.png" >/dev/null
  sips -z "$layer" "$layer" "$layers/background.png" --out "$res/mipmap-$density/ic_launcher_background.png" >/dev/null
done
mkdir -p "$res/mipmap-anydpi-v26"
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<!-- Made by tool/app_icons.sh. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
XML
print "Icons updated."
