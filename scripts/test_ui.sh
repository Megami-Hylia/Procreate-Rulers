#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
arch="$(uname -m)"
mkdir -p build/ToolbarHarness.app
xcrun --sdk iphonesimulator clang -arch "$arch" -isysroot "$sdk" -mios-simulator-version-min=16.3 \
  -fobjc-arc -fmodules -O1 -Wall -Wextra -Wno-unused-parameter \
  tests/ToolbarHarness.m src/Rulers.m -framework UIKit -framework Foundation \
  -o build/ToolbarHarness.app/Procreate
python3 - <<'PY'
import plistlib,pathlib
p={'CFBundleIdentifier':'test.megamihylia.rulers.resigned','CFBundleExecutable':'Procreate','CFBundleName':'ToolbarHarness','CFBundlePackageType':'APPL','CFBundleVersion':'2','CFBundleShortVersionString':'0.2','MinimumOSVersion':'16.3','UIDeviceFamily':[2],'UILaunchScreen':{}}
pathlib.Path('build/ToolbarHarness.app/Info.plist').write_bytes(plistlib.dumps(p))
PY
codesign --force --sign - build/ToolbarHarness.app
xcrun simctl list devices available --json > build/simulators.json
device="$(python3 - <<'PY'
import json
d=json.load(open('build/simulators.json'))['devices']
choices=[x for group in d.values() for x in group if 'iPad' in x['name'] and x['isAvailable']]
if not choices:raise SystemExit('No available iPad simulator')
print(choices[0]['udid'])
PY
)"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" build/ToolbarHarness.app
xcrun simctl launch "$device" test.megamihylia.rulers.resigned
container="$(xcrun simctl get_app_container "$device" test.megamihylia.rulers.resigned data)"
for attempt in {1..30}; do
  if [ -f "$container/Documents/toolbar-test.json" ]; then break; fi
  sleep 1
done
cp "$container/Documents/toolbar-test.json" build/toolbar-test.json
xcrun simctl io "$device" screenshot build/toolbar-harness.png
cat build/toolbar-test.json
python3 - <<'PY'
import json
r=json.load(open('build/toolbar-test.json'))
assert r['passed'],r['failures']
PY
