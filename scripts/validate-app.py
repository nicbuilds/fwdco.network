"""Validate actual device build output. Never creates a substitute executable."""
import pathlib, plistlib, subprocess, sys
app = pathlib.Path(sys.argv[1])
with (app / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleIdentifier'] == 'help.nodo.mobile', info
assert info['CFBundleShortVersionString'] == '1.0', info
assert info['CFBundleVersion'] == '4', info
assert set(info['UIDeviceFamily']) == {1, 2}, info
assert info['MinimumOSVersion'] == '16.0', info
assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], info
binary = app / info['CFBundleExecutable']
assert binary.is_file() and binary.stat().st_size > 0
archs = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
assert 'arm64' in archs.split(), archs
orientations = info.get('UISupportedInterfaceOrientations~ipad', info.get('UISupportedInterfaceOrientations', []))
assert len(orientations) == 4, orientations
print('PASS: device executable arm64; universal iPhone/iPad; iOS 16+; bundle/version/orientations correct.')
