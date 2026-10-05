#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
xcodebuild -version | tee build/xcode-version.txt
xcodebuild -project NODO.xcodeproj -scheme NODO -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  build 2>&1 | tee build/device-build.log
APP="$PWD/build/DerivedData/Build/Products/Release-iphoneos/NODO.app"
python3 scripts/validate-app.py "$APP"
mkdir -p build/classic/Payload
/usr/bin/ditto --norsrc --noextattr "$APP" build/classic/Payload/NODO.app
APP="$PWD/build/classic/Payload/NODO.app"
# Normalize the plist before sealing resources. No fake provisioning profile.
plutil -convert xml1 "$APP/Info.plist"
xattr -cr "$APP"
chmod 755 "$APP/NODO"
python3 - <<'PY'
import plistlib
with open('build/empty-entitlements.plist','wb') as f:
    plistlib.dump({},f,fmt=plistlib.FMT_XML)
PY
codesign --force --sign - --identifier help.nodo.mobile --timestamp=none \
  --entitlements build/empty-entitlements.plist --generate-entitlement-der "$APP"
codesign --verify --deep --strict --verbose=4 "$APP" 2>&1 | tee build/signature-build.log
codesign --display --verbose=4 "$APP" 2>&1 | tee -a build/signature-build.log
codesign --display --entitlements :- "$APP" > build/extracted-entitlements.plist
python3 scripts/validate-signature.py "$APP"
# Demonstrate that the whole bundle can be re-signed without preserving old metadata.
/usr/bin/ditto --norsrc --noextattr "$APP" build/ResignCheck.app
codesign --force --sign - --identifier help.nodo.mobile --timestamp=none \
  --entitlements build/empty-entitlements.plist --generate-entitlement-der build/ResignCheck.app
codesign --verify --deep --strict --verbose=4 build/ResignCheck.app 2>&1 | tee -a build/signature-build.log
python3 scripts/package-classic.py "$APP" dist/NODO-1.0-build4-AltStore-Classic.ipa
shasum -a 256 dist/*.ipa > dist/SHA256SUMS.txt
cp build/xcode-version.txt dist/
cp build/signature-build.log dist/
echo 'Device build, ad-hoc signature, empty entitlements and local re-sign verification passed. Apple account signing and device installation not tested.' > dist/BUILD-STATUS.txt
