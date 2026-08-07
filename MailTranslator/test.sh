#!/bin/bash
set -euo pipefail

# 同 build.sh：在临时目录编译，规避 iCloud 同步目录的 mtime 抖动。
STAGE=$(mktemp -d /tmp/mt-test.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
rsync -a Sources Tests "$STAGE"/
cd "$STAGE"

mkdir -p build
xcrun swiftc -swift-version 5 \
  -framework NaturalLanguage -Xlinker -weak_framework -Xlinker Translation \
  -o build/core-tests \
  Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift \
  Sources/Extension/TranslationActionGate.swift \
  Sources/Extension/TranslationActionContext.swift \
  Sources/Extension/TranslationRefreshCoordinator.swift \
  Sources/Extension/TranslationTaskRegistry.swift \
  Sources/Extension/TranslationStore.swift Tests/CoreTests.swift
./build/core-tests

xcrun swiftc -swift-version 5 \
  -framework AppKit -framework NaturalLanguage \
  -Xlinker -weak_framework -Xlinker Translation \
  -o build/settings-hit-test \
  Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift \
  Sources/App/SettingsViewController.swift Tests/SettingsHitTest.swift
./build/settings-hit-test
