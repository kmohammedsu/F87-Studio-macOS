#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="$project_dir/outputs"
app_dir="$output_dir/F87 Studio.app"
contents_dir="$app_dir/Contents"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"

cd "$project_dir"
swift build --disable-sandbox -c release --triple arm64-apple-macosx13.0
CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache-x86" \
SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache-x86" \
  swift build --disable-sandbox -c release --triple x86_64-apple-macosx13.0
"$project_dir/scripts/build_icon.sh"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
lipo -create \
  ".build/arm64-apple-macosx/release/F87Studio" \
  ".build/x86_64-apple-macosx/release/F87Studio" \
  -output "$contents_dir/MacOS/F87Studio"
cp "README.md" "THIRD_PARTY_NOTICES.md" "$contents_dir/Resources/"

cp "Resources/Info.plist" "$contents_dir/Info.plist"
xcrun actool --compile "$contents_dir/Resources" \
  --platform macosx --minimum-deployment-target 13.0 --app-icon AppIcon \
  --output-partial-info-plist "$project_dir/.build/asset-info.plist" \
  "$project_dir/Resources/Assets.xcassets" >/dev/null

# Keep a stable designated requirement across local builds. Without this explicit
# requirement, ad-hoc signing identifies each build by its changing code hash and
# macOS Input Monitoring treats every update as an unrelated application.
codesign --force --deep --sign - \
  --entitlements "$project_dir/Resources/F87Studio.entitlements" \
  --requirements '=designated => identifier "studio.f87.mac"' \
  "$app_dir"

archive="$output_dir/F87-Studio-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"

echo "$app_dir"
echo "$archive"
