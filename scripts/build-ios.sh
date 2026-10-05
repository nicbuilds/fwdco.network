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
mkdir -p build/package/Payload
/usr/bin/ditto "$APP" build/package/Payload/NODO.app
(cd build/package && /usr/bin/zip -qry ../../dist/NODO-1.0-build2-unsigned.ipa Payload)
/usr/bin/ditto -c -k --keepParent "$APP" dist/NODO-1.0-build2-unsigned.app.zip
shasum -a 256 dist/*.ipa dist/*.zip > dist/SHA256SUMS.txt
cp build/xcode-version.txt dist/
echo 'Device compilation and package validation succeeded; Apple signing still required.' > dist/BUILD-STATUS.txt
