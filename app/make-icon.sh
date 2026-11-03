#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

tmp=$(mktemp -d)
swift make-icon.swift "$tmp/icon.png"
mkdir "$tmp/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$tmp/AppIcon.iconset" -o AppIcon.icns
rm -rf "$tmp"
echo "AppIcon.icns"
