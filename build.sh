#!/bin/bash
set -euo pipefail

# App Store-only local build; use the Xcode archive workflow for distribution.
# iCloud 同步目录下编译不稳定（fileproviderd 会改动源文件 mtime），
# 先把源码同步到本地临时目录再编译，产物拷回 build/。
STAGE=$(mktemp -d /tmp/mt-build.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
rsync -a Sources Resources "$STAGE"/
cd "$STAGE"

SDK=$(xcrun --show-sdk-path)
TARGETS=(arm64-apple-macos26.0 x86_64-apple-macos26.0)
APP=build/MailTranslator.app
EXT="$APP/Contents/PlugIns/MailTranslatorExtension.appex"
ARCH_BUILD=build/.arch

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS" "$ARCH_BUILD"
cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/Ext-Info.plist "$EXT/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"
printf 'XPC!????' > "$EXT/Contents/PkgInfo"

APP_BINARIES=()
EXT_BINARIES=()

for target in "${TARGETS[@]}"; do
  arch=${target%%-*}
  arch_dir="$ARCH_BUILD/$arch"
  mkdir -p "$arch_dir"

  xcrun swiftc -sdk "$SDK" -target "$target" -swift-version 5 -O -D APP_STORE \
    -module-name MailTranslator -framework AppKit -framework StoreKit -framework NaturalLanguage \
    -Xlinker -weak_framework -Xlinker Translation \
    -o "$arch_dir/MailTranslator" \
    Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift Sources/App/*.swift
  APP_BINARIES+=("$arch_dir/MailTranslator")

  xcrun swiftc -sdk "$SDK" -target "$target" -swift-version 5 -O -D APP_STORE \
    -application-extension -module-name MailTranslatorExtension \
    -framework MailKit -framework AppKit -framework StoreKit -framework NaturalLanguage \
    -Xlinker -weak_framework -Xlinker Translation \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -o "$arch_dir/MailTranslatorExtension" \
    Sources/Core/*.swift Sources/Engine/*.swift Sources/Providers/*.swift Sources/Extension/*.swift
  EXT_BINARIES+=("$arch_dir/MailTranslatorExtension")
done

xcrun lipo -create "${APP_BINARIES[@]}" \
  -output "$APP/Contents/MacOS/MailTranslator"
xcrun lipo -create "${EXT_BINARIES[@]}" \
  -output "$EXT/Contents/MacOS/MailTranslatorExtension"
rm -rf "$ARCH_BUILD"

IDENT=${APP_SIGNING_IDENTITY:-}
if [ -z "$IDENT" ]; then
  IDENT=$(security find-identity -v -p codesigning | awk -F '"' '/Apple Development/{print $2; exit}')
fi
if [ -z "$IDENT" ] || [ "$IDENT" = "-" ]; then
  IDENT=-
  SIGN_OPTIONS=(--timestamp=none --options runtime)
elif [[ "$IDENT" == *"Apple Development"* ]]; then
  SIGN_OPTIONS=(--timestamp=none --options runtime)
else
  SIGN_OPTIONS=(--timestamp --options runtime)
fi

codesign --force "${SIGN_OPTIONS[@]}" \
  --entitlements Resources/AppStore-Extension.entitlements --sign "$IDENT" "$EXT"
codesign --force "${SIGN_OPTIONS[@]}" \
  --entitlements Resources/AppStore-App.entitlements --sign "$IDENT" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Build OK: $APP"

OLDPWD_SYNC=$(cd "$OLDPWD" && pwd)
mkdir -p "$OLDPWD_SYNC/build"
rsync -a --delete build/ "$OLDPWD_SYNC/build/"
# Existing iCloud/Finder metadata on destination directories invalidates signatures.
xattr -cr "$OLDPWD_SYNC/$APP"
codesign --verify --deep --strict --verbose=2 "$OLDPWD_SYNC/$APP"
echo "Synced to $OLDPWD_SYNC/build"
