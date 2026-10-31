#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
clang -std=c11 -D_DEFAULT_SOURCE tests/geometry.c -lm -o build/geometry-tests
build/geometry-tests
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -arch arm64 -isysroot "$sdk" -miphoneos-version-min=16.3 \
  -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter \
  -dynamiclib src/Rulers.m -framework UIKit -framework Foundation \
  -install_name @executable_path/Frameworks/ProcreateRulers.dylib \
  -o build/ProcreateRulers.dylib
codesign --force --sign - build/ProcreateRulers.dylib
otool -hv build/ProcreateRulers.dylib
