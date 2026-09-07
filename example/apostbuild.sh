#!/usr/bin/env bash
set -euo pipefail

ANDROID_OUTPUT_DIR=build/android/android/app/src/main/assets/

cp -rv models $ANDROID_OUTPUT_DIR
cp -rv maps $ANDROID_OUTPUT_DIR
cp -rv textures $ANDROID_OUTPUT_DIR
cp -rv shaders $ANDROID_OUTPUT_DIR

echo Textures copied

cd build/android/android/
./gradlew assembleDebug
