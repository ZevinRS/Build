#!/bin/bash
# Turn an unsigned LiveContainer .xcarchive into an .ipa (Payload/LiveContainer.app, zipped).
# Mirrors the standalone part of upstream's host/.github/build_github.sh.
# Usage: package-host.sh <path/to/archive.xcarchive> <output.ipa>
set -euo pipefail

archive="$1"
out="$2"
work="$(mktemp -d)"

cp -R "$archive/Products/Applications" "$work/Payload"

# Upstream's standalone IPA ships without the SideStore integration framework.
rm -rf "$work/Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework"

# Every extension costs a free-account App ID (10 new per week). Keep only what we use:
#   LiveProcess.appex        kept: multitasking / iPad windows
#   ShareExtension.appex     removed: "Open in LiveContainer" from the share sheet
#   LaunchAppExtension.appex removed: Shortcuts "Launch App" action
# The bundle IDs of what remains must never change: a new ID costs another App ID.
rm -rf "$work/Payload/LiveContainer.app/PlugIns/ShareExtension.appex" \
       "$work/Payload/LiveContainer.app/PlugIns/LaunchAppExtension.appex" \
       "$work/Payload/LiveContainer.app/Extensions/LaunchAppExtension.appex"
echo "Extensions shipped:"; ls "$work/Payload/LiveContainer.app/PlugIns" 2>/dev/null || true

# Build number guests see through AppHubHost +info (hostBuild); also the AppHub tab's update check.
/usr/libexec/PlistBuddy -c "Add :AppHubBuild string ${APPHUB_BUILD:-dev}" \
  "$work/Payload/LiveContainer.app/Info.plist"

(cd "$work" && zip -qr host.ipa Payload -x "._*" -x "*.DS_Store" -x "__MACOSX*")
mv "$work/host.ipa" "$out"
rm -rf "$work"

echo "Packaged $out ($(du -h "$out" | cut -f1))"
