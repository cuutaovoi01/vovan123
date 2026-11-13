#!/bin/bash
# Build KFCrossOverIPC cho arm64 + arm64e, ghép FAT.
# Chay tren macOS (Xcode) hoac GitHub Actions macos runner.
set -e
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "SDK: $SDK"
xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=15.0 -isysroot "$SDK" \
  -fobjc-arc -O2 -dynamiclib -framework Foundation -framework CoreFoundation \
  KFCrossOverIPC.m -o libCo_arm64.dylib
xcrun --sdk iphoneos clang -arch arm64e -miphoneos-version-min=15.0 -isysroot "$SDK" \
  -fobjc-arc -O2 -dynamiclib -framework Foundation -framework CoreFoundation \
  KFCrossOverIPC.m -o libCo_arm64e.dylib
lipo -create -output libCrossOverIPC.dylib libCo_arm64.dylib libCo_arm64e.dylib
lipo -info libCrossOverIPC.dylib
ls -la libCrossOverIPC.dylib
