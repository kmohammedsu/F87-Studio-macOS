#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/outputs/F87 Studio.app"
archive="$project_dir/outputs/F87-Studio-macOS.zip"
identity="${F87_SIGN_IDENTITY:?Set F87_SIGN_IDENTITY to a Developer ID Application certificate name}"
notary_profile="${F87_NOTARY_PROFILE:?Set F87_NOTARY_PROFILE to a notarytool keychain profile}"

"$project_dir/scripts/build_app.sh"

codesign --force --deep --options runtime --timestamp \
  --entitlements "$project_dir/Resources/F87Studio.entitlements" \
  --sign "$identity" "$app_dir"
codesign --verify --deep --strict --verbose=2 "$app_dir"

ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"

echo "$archive"
