#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_path="build/Build/Products/Release-iphoneos/Mujian.app"
if [[ ! -f "$app_path/Mujian" || ! -f "$app_path/Info.plist" ]]; then
  echo 'The compiled iPhone app is missing. Read the Xcode build log first.' >&2
  exit 1
fi
plutil -lint "$app_path/Info.plist"
file "$app_path/Mujian"
if ! lipo -archs "$app_path/Mujian" | grep -q 'arm64'; then
  echo 'Expected an arm64 iPhone binary.' >&2
  exit 1
fi
mkdir -p dist
package_dir="$(mktemp -d)"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/Mujian.app"
project_root="$PWD"
(
  cd "$package_dir"
  zip -qry "$project_root/dist/Mujian-unsigned.ipa" Payload
)
(
  cd dist
  shasum -a 256 Mujian-unsigned.ipa > SHA256.txt
)
echo 'Created dist/Mujian-unsigned.ipa. Sign this IPA with your own signing tool before installing.'
