#!/bin/bash
# build.sh — compila EinsteinCat y arma build/EinsteinCat.app sin Xcode.
set -euo pipefail

# Trabajar siempre desde la carpeta del proyecto, aunque se llame desde otro lado.
cd "$(dirname "$0")"

APP="build/EinsteinCat.app"

# 1. Empezar limpio (solo borra el .app dentro de build/, que está en .gitignore).
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 2. Compilar. -swift-version 5 porque el código original es Swift 5.
#    -import-objc-header: declaraciones de los métodos privados de la Touch Bar.
swiftc -swift-version 5 \
       -target x86_64-apple-macosx15.0 \
       -O \
       -import-objc-header Sources/TouchBarPrivate.h \
       Sources/*.swift \
       -o "$APP/Contents/MacOS/EinsteinCat"

# 3. Copiar Info.plist, imágenes e icono.
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/*.png "$APP/Contents/Resources/"
cp Resources/*.icns "$APP/Contents/Resources/" 2>/dev/null || true

# 4. Revisar que el plist sea válido.
plutil -lint "$APP/Contents/Info.plist"

# 5. Firma ad-hoc ("-" = sin certificado) y verificación.
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"

echo "Listo: $APP"

# 6. Instalación opcional en /Applications si se pasa el argumento --install
if [[ "${1:-}" == "--install" ]]; then
    echo "Instalando en /Applications..."
    rm -rf "/Applications/EinsteinCat.app"
    cp -R "$APP" "/Applications/EinsteinCat.app"
    touch "/Applications/EinsteinCat.app"
    echo "Instalado con éxito en /Applications/EinsteinCat.app"
fi
