#!/bin/bash
# ==============================================================================
# SCHLANKES & AUTOMATISCHES BUILD-SCRIPT FÜR DOMESDAY DUPLICATOR (NEUE DDD-GUI)
# ==============================================================================

# Fehler abfangen
set -e

# Ermittelt automatisch den Ordner, in dem dieses Skript gerade liegt
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"

# Pfade relativ zum Skript-Standort definieren
REPO_PATH="$SCRIPT_DIR/DomesdayDuplicator"
GUI_PATH="$REPO_PATH/ddd-gui"
APP_DIR="$SCRIPT_DIR/DomesdayDuplicator-App"

TARGET_CMAKE="$GUI_PATH/CMakeLists.txt"
ICON_SOURCE_PATH="$GUI_PATH/src/gui/resources/icon.ico"

echo "=== 1. Installiere/Überprüfe benötigte MSYS2-Pakete ==="
pacman -S --needed --noconfirm \
    mingw-w64-x86_64-qt6-base \
    mingw-w64-x86_64-qt6-serialport \
    mingw-w64-x86_64-toolchain \
    make \
    mingw-w64-x86_64-libusb \
    mingw-w64-x86_64-flac \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-rcedit \
	mingw-w64-x86_64-spdlog \
    git

echo "=== 2. Wechsle in das Repository-Verzeichnis ==="
if [ ! -d "$REPO_PATH" ]; then
    echo "ERROR: Der Quellcode-Ordner 'DomesdayDuplicator' wurde nicht neben diesem Skript gefunden!"
    echo "Gesuchter Pfad: $REPO_PATH"
    exit 1
fi
cd "$REPO_PATH"

echo "=== 3. Prüfe auf Quellcode-Updates und stelle Originaldateien wieder her ==="
git stash --quiet || true
echo "Lade neueste Änderungen herunter..."
git pull origin main || git pull origin master || echo "Hinweis: Git Pull fehlgeschlagen. Fahre mit lokalem Code fort."
git checkout ddd-gui/CMakeLists.txt 2>/dev/null || true
git stash pop --quiet 2>/dev/null || true

echo "=== 4. Starte den Kompiliervorgang (Build) ==="
BUILD_DIR="$GUI_PATH/build"
rm -rf "$BUILD_DIR"

cmake -G "MinGW Makefiles" \
      -B "$BUILD_DIR" \
      -S "$GUI_PATH" \
      -DCMAKE_BUILD_TYPE=Release \
      -DDDD_ENABLE_CLANG_FORMAT=OFF \
      -DDDD_ENABLE_CLANG_TIDY=OFF

cmake --build "$BUILD_DIR" --config Release --parallel $(nproc)

echo "=== 5. Bereite Export-Ordner vor (Schließt offene Prozesse) ==="
# Schließe eventuell noch laufende Instanzen der App, die den Ordner blockieren könnten
taskkill //F //IM DomesdayDuplicator.exe 2>/dev/null || true
taskkill //F //IM ddd-gui.exe 2>/dev/null || true

# Falls das Terminal im Zielordner steht, kurz wegbewegen um Sperre aufzuheben
cd "$SCRIPT_DIR"

# Ordner leeren mit Sicherheits-Schleife
if [ -d "$APP_DIR" ]; then
    echo "Bereinige alten App-Ordner..."
    rm -rf "$APP_DIR" || (echo "Warte 2 Sekunden auf Windows-Dateifreigabe..." && sleep 2 && rm -rf "$APP_DIR")
fi
mkdir -p "$APP_DIR"

echo "=== 6. Exportiere App und brenne Icon ein ==="
echo "Suche im gesamten Build-Verzeichnis nach den Binärdateien..."
FOUND_GUI_EXE=$(find "$BUILD_DIR" -type f -name "ddd-gui.exe" | head -n 1)

if [ -n "$FOUND_GUI_EXE" ]; then
    echo "Hauptanwendung gefunden unter: $FOUND_GUI_EXE"
    cp "$FOUND_GUI_EXE" "$APP_DIR/DomesdayDuplicator.exe"
    echo "-> Erfolgreich exportiert als DomesdayDuplicator.exe"
    
    if [ -f "$ICON_SOURCE_PATH" ]; then
        echo "Brenne Icon direkt in die DomesdayDuplicator.exe ein..."
        rcedit "$APP_DIR/DomesdayDuplicator.exe" --set-icon "$ICON_SOURCE_PATH"
        echo "-> Icon erfolgreich injiziert!"
    else
        echo "WARNUNG: Icon-Datei wurde unter $ICON_SOURCE_PATH nicht gefunden!"
    fi
else
    echo "ERROR: Hauptanwendung ddd-gui.exe konnte nirgendwo im Build-Ordner gefunden werden!"
    exit 1
fi

# CLI-Tools mitsammeln
FOUND_UPDATE_EXE=$(find "$BUILD_DIR" -type f -name "ddd-update.exe" | head -n 1)
if [ -n "$FOUND_UPDATE_EXE" ]; then
    cp "$FOUND_UPDATE_EXE" "$APP_DIR/"
    echo "-> ddd-update.exe erfolgreich exportiert"
fi

FOUND_JTAG_EXE=$(find "$BUILD_DIR" -type f -name "ddd-jtag.exe" | head -n 1)
if [ -n "$FOUND_JTAG_EXE" ]; then
    cp "$FOUND_JTAG_EXE" "$APP_DIR/"
    echo "-> ddd-jtag.exe erfolgreich exportiert"
fi

cd "$APP_DIR"

# 7. windeployqt ausführen
echo "Führe windeployqt aus..."
windeployqt --no-translations DomesdayDuplicator.exe

echo "Warte kurz auf windeployqt (5 Sekunden)..."
sleep 5

echo "Sammle zusätzliche MinGW-, Qt6-Core- und ICU-Bibliotheken..."
DLL_LIST=(
    "libstdc++-6"
    "libgcc_s_seh-1"
    "libwinpthread-1"
    "libusb-1.0"
    "libflac"
    "libogg"
    "libdouble-conversion"
    "libb2"
    "libglib"
    "libpcre2-16"
    "libintl"
    "libzstd"
    "libiconv"
    "libicu"
    "zlib1"
    "libharfbuzz-0"
    "libfreetype-6"
    "libmd4c"
    "libpng16-16"
    "libbz2-1"
    "libbrotlidec"
    "libbrotlicommon"
    "libgraphite2"
    "libpcre2-8-0"
	"libspdlog-1.17"
)

for dll_name in "${DLL_LIST[@]}"; do
    find /mingw64/bin/ -iname "*${dll_name}*.dll" -exec cp {} . \; 2>/dev/null || true
done

echo "=============================================================================="
echo "ERFOLGREICH! Deine portable App inklusive ICON ist fertig unter:"
echo "$APP_DIR"
echo "=============================================================================="
