#!/bin/zsh
# Compila e empacota build/Dittado.app (sem Xcode, só Command Line Tools).
set -e
cd "$(dirname "$0")/.."

# Carrega variáveis de ambiente locais se existirem (ex: DITTADO_BUNDLE_ID, DITTADO_SIGN_IDENTITY)
if [ -f "scripts/local.env" ]; then
  # shellcheck source=/dev/null
  source scripts/local.env
fi

BUNDLE_ID="${DITTADO_BUNDLE_ID:-app.dittado.Dittado}"
SIGN_IDENTITY_NAME="${DITTADO_SIGN_IDENTITY:-Dittado Dev}"

swift build -c release --product Dittado

APP=build/Dittado.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp .build/release/Dittado "$APP/Contents/MacOS/Dittado"
cp -R Vendor/build-apple/whisper.xcframework/macos-arm64_x86_64/whisper.framework "$APP/Contents/Frameworks/"
cp -R Vendor/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework "$APP/Contents/Frameworks/"
cp Recursos/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"

# Define CFBundleShortVersionString e CFBundleVersion automaticamente
GIT_REV=$(git rev-list --count HEAD 2>/dev/null || echo "")
TIMESTAMP=$(date "+%Y%m%d.%H%M")
if [ -n "$GIT_REV" ] && [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  BUILD_VERSION="${DITTADO_BUILD_VERSION:-$GIT_REV}"
else
  BUILD_VERSION="${DITTADO_BUILD_VERSION:-$TIMESTAMP}"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.2.0" "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.2.0" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_VERSION" "$APP/Contents/Info.plist"

cp Recursos/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Certificado local mantém as permissões entre versões; sem ele, assinatura ad-hoc
IDENTIDADE="-"
HASH=$(security find-identity -p codesigning | grep "\"$SIGN_IDENTITY_NAME\"" | head -1 | awk '{print $2}')
if [[ -n "$HASH" ]]; then
  IDENTIDADE="$HASH"
else
  echo "⚠️ AVISO: Certificado '$SIGN_IDENTITY_NAME' não encontrado no Keychain."
  echo "⚠️ Assinatura aplicada em modo ad-hoc (-)."
  echo "⚠️ AVISO GATEKEEPER: No macOS, aplicativos assinados em modo ad-hoc sem conta Apple Developer"
  echo "    podem ser bloqueados na primeira execução. Para liberar:"
  echo "    Acesse Ajustes do Sistema > Privacidade e Segurança > clique em 'Abrir Mesmo Assim'"
  echo "    ou execute no Terminal: xattr -cr /Applications/Dittado.app"
fi

codesign --force --sign "$IDENTIDADE" "$APP/Contents/Frameworks/whisper.framework"
codesign --force --sign "$IDENTIDADE" "$APP/Contents/Frameworks/llama.framework"
codesign --force --sign "$IDENTIDADE" --identifier "$BUNDLE_ID" "$APP"

# Instala em /Applications (o Spotlight acha um só Dittado); --sem-instalar deixa só em build/
if [[ "$1" != "--sem-instalar" ]]; then
  pkill -x Dittado 2>/dev/null && sleep 1 || true
  rm -rf /Applications/Dittado.app
  mv "$APP" /Applications/Dittado.app
  APP=/Applications/Dittado.app
fi
echo "OK: $APP (id: $BUNDLE_ID | assinatura: $IDENTIDADE)"
