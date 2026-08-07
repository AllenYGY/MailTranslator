#!/bin/bash
set -euo pipefail

killall Mail 2>/dev/null || true
killall MailTranslator 2>/dev/null || true
rm -rf /Applications/MailTranslator.app
cp -R build/MailTranslator.app /Applications/
xattr -cr /Applications/MailTranslator.app
codesign --verify --deep --strict --verbose=2 /Applications/MailTranslator.app
open -a /Applications/MailTranslator.app
sleep 2
pluginkit -mAvvv -p com.apple.email.extension
pluginkit -e use -i io.github.allenygy.mailtranslator.extension
open -a Mail
