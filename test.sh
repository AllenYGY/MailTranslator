#!/bin/bash
set -euo pipefail

# App Store 分支：仅 Apple 系统翻译，所有目标均以 APP_STORE 编译。
# 多云引擎（OpenAI 兼容 / 火山翻译）的源码与测试只存在于 main 分支。

# 同 build.sh：在临时目录编译，规避 iCloud 同步目录的 mtime 抖动。
STAGE=$(mktemp -d /tmp/mt-test.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
rsync -a Sources Tests "$STAGE"/
cd "$STAGE"

mkdir -p build

xcrun swiftc -swift-version 5 -D APP_STORE \
  -framework StoreKit -framework NaturalLanguage \
  -Xlinker -weak_framework -Xlinker Translation \
  -o build/store-core-tests \
  Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift \
  Sources/Extension/TranslationActionGate.swift \
  Sources/Extension/TranslationActionContext.swift \
  Sources/Extension/TranslationRefreshCoordinator.swift \
  Sources/Extension/TranslationTaskRegistry.swift \
  Sources/Extension/TranslationStore.swift Tests/CoreTests.swift
./build/store-core-tests

xcrun swiftc -swift-version 5 -D APP_STORE \
  -framework StoreKit -framework NaturalLanguage \
  -Xlinker -weak_framework -Xlinker Translation \
  -o build/edition-tests \
  Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift \
  Sources/Extension/Settings.swift Tests/AppStoreEditionTests.swift
./build/edition-tests

xcrun swiftc -swift-version 5 -D APP_STORE -D STOREKIT_UI_TEST \
  -framework StoreKit -framework AppKit -framework NaturalLanguage \
  -Xlinker -weak_framework -Xlinker Translation \
  -o build/store-settings-hit-test \
  Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift \
  Sources/App/PurchaseView.swift Sources/App/SettingsViewController.swift Tests/SettingsHitTest.swift
./build/store-settings-hit-test
