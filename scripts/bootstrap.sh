#!/usr/bin/env bash
# One-time setup: generate the native Android/iOS/macOS/Windows/Linux folders with
# the io.surprise.dj namespace, then fetch packages.
#
#   org (io.surprise) + project name (dj)  =>  applicationId / bundle id io.surprise.dj
set -euo pipefail

flutter create --org io.surprise --project-name dj --platforms=android,ios .
flutter pub get

cat <<'EOF'

Done. Next:
  flutter analyze
  flutter test
  flutter run            # pick a landscape-capable device

iOS only: set the deployment target to 13.0 in ios/Podfile (platform :ios, '13.0').
EOF
