#!/bin/bash
# ==============================================================================
# COMBINED BUILD- & DEPLOY-SCRIPT FOR FX3 PROGRAMMER & FIRMWARE (CORRECT PARAMS)
# ==============================================================================

# Fehler abfangen
set -e

# Ermittelt automatisch den Ordner, in dem dieses Skript gerade liegt
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"

# Pfade relativ zum Skript-Standort definieren
REPO_PATH="$SCRIPT_DIR/DomesdayDuplicator"
FX3_PATH="$REPO_PATH/fx3"
APP_DIR="$SCRIPT_DIR/FX3Programmer & Firmware"

echo "=== 1. Installiere/Überprüfe benötigte MSYS2-Pakete ==="
pacman -S --needed --noconfirm pactoys git make

# pacboy wählt automatisch die richtige Umgebung für Standardpakete
pacboy -S --needed --noconfirm \
  toolchain:p \
  libusb:p \
  cmake:p \
  gtest:p

# Installiert die UCRT64-Variante der ARM-Toolchain nach
pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-arm-none-eabi-toolchain

echo "=== 2. Wechsle in das Repository-Verzeichnis ==="
if [ ! -d "$REPO_PATH" ]; then
  echo "ERROR: Der Quellcode-Ordner 'DomesdayDuplicator' wurde nicht neben diesem Skript gefunden!"
  echo "Gesuchter Pfad: $REPO_PATH"
  exit 1
fi
cd "$REPO_PATH"

echo "=== 3. Bereite Code-Fixes vor (Patches für Windows) ==="
git checkout fx3/programmer/tests/test_flashprog.cpp 2>/dev/null || true
git checkout fx3/programmer/src/fx3-programmer.c 2>/dev/null || true

# Fix für den mkdir-Fehler unter Windows (entfernt das zweite Argument 0755)
SED_FILE="$FX3_PATH/programmer/tests/test_flashprog.cpp"
if [ -f "$SED_FILE" ]; then
  echo "Patsche mkdir-Aufruf in test_flashprog.cpp..."
  sed -i 's/::mkdir(asDir.c_str(), 0755)/::mkdir(asDir.c_str())/g' "$SED_FILE"
fi

# Fix für die %ld Warnungen (ersetzt %ld mit %lld bei ssize_t)
C_FILE="$FX3_PATH/programmer/src/fx3-programmer.c"
if [ -f "$C_FILE" ]; then
  echo "Behebe Format-Warnungen in fx3-programmer.c..."
  sed -i 's/read %ld of %d bytes/read %lld of %d bytes/g' "$C_FILE"
fi

echo "=== 4. Kompiliere den Programmer ==="
PROG_BUILD_DIR="$FX3_PATH/programmer/build"
rm -rf "$PROG_BUILD_DIR"

cmake -G "MinGW Makefiles" \
  -B "$PROG_BUILD_DIR" \
  -S "$FX3_PATH/programmer" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "$PROG_BUILD_DIR" --config Release --parallel $(nproc)

echo "=== 5. Kompiliere die Firmware ==="
FW_BUILD_DIR="$FX3_PATH/firmware/build"

if [ -d "$FX3_PATH/firmware" ] && [ -f "$FX3_PATH/firmware/CMakeLists.txt" ]; then
  rm -rf "$FW_BUILD_DIR"
  
  # Sucht den Pfad zum UCRT64 ARM-Compiler heraus
  ARM_GCC_PATH="/ucrt64/bin/arm-none-eabi-gcc"
  ARM_GXX_PATH="/ucrt64/bin/arm-none-eabi-g++"
  
  # Fallback falls UCRT-Pfadstruktur in deiner MSYS-Installation abweicht
  if [ ! -f "$ARM_GCC_PATH" ]; then
    ARM_GCC_PATH=$(which arm-none-eabi-gcc 2>/dev/null || echo "arm-none-eabi-gcc")
    ARM_GXX_PATH=$(which arm-none-eabi-g++ 2>/dev/null || echo "arm-none-eabi-g++")
  fi

  echo "Nutze ARM-Compiler von: $ARM_GCC_PATH"

  # Konfiguration mit den zwingend erforderlichen Cross-Compile-Parametern
  CC="$ARM_GCC_PATH" CXX="$ARM_GXX_PATH" cmake -G "MinGW Makefiles" \
    -B "$FW_BUILD_DIR" \
    -S "$FX3_PATH/firmware" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Generic \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY

  cmake --build "$FW_BUILD_DIR" --config Release --parallel $(nproc)
else
  echo "Hinweis: Kein Firmware-CMake-Projekt in $FX3_PATH/firmware gefunden. Überspringe Firmware-Build."
fi

echo "=== 6. Bereite Export-Ordner vor ==="
# Schließe eventuell noch offene Programmer-Prozesse, die den Ordner sperren
taskkill //F //IM fx3-programmer.exe 2>/dev/null || true

# Falls dein eigenes Terminal gerade im Zielordner steht, kurz wegbewegen
cd "$SCRIPT_DIR"

if [ -d "$APP_DIR" ]; then
  echo "Bereinige alten App-Ordner..."
  # Versuche es zuerst normal mit rm
  rm -rf "$APP_DIR" 2>/dev/null || {
    echo "Ordner blockiert. Erzwinge Windows-Bereinigung..."
    sleep 2
    # Windows-Pfad konvertieren
    WIN_APP_DIR=$(cygpath -w "$APP_DIR")
    command cmd.exe //c "rmdir /s /q \"$WIN_APP_DIR\"" 2>/dev/null || true
  }
fi

# Zweiter Fallback: Wenn der Ordner immer noch da ist, versuchen wir den Inhalt zu leeren
if [ -d "$APP_DIR" ]; then
  rm -rf "$APP_DIR"/* 2>/dev/null || true
fi

# Erstelle den Ordner neu (oder nutze den bestehenden, falls er nicht gelöscht werden konnte)
mkdir -p "$APP_DIR"

echo "=== 7. Exportiere Programmer, Firmware und Bibliotheken ==="
# 7a. Programmer kopieren
FOUND_PROG_EXE=$(find "$PROG_BUILD_DIR" -type f -name "fx3-programmer.exe" | head -n 1)
if [ -n "$FOUND_PROG_EXE" ]; then
  cp "$FOUND_PROG_EXE" "$APP_DIR/"
  echo "-> fx3-programmer.exe erfolgreich exportiert"
else
  echo "ERROR: fx3-programmer.exe wurde nicht gefunden!"
  exit 1
fi

# 7b. Firmware (.img-Dateien) kopieren
FIRST_FW_IMG=""
if [ -d "$FW_BUILD_DIR" ]; then
  FOUND_IMG=$(find "$FW_BUILD_DIR" -type f -name "*.img")
  if [ -n "$FOUND_IMG" ]; then
    echo "$FOUND_IMG" | while read -r img_path; do
      cp "$img_path" "$APP_DIR/"
      echo "-> Firmware-Image '$(basename "$img_path")' erfolgreich exportiert"
    done
    FIRST_FW_IMG=$(basename "$(echo "$FOUND_IMG" | head -n 1)")
  else
    FOUND_ANY_FW=$(find "$FW_BUILD_DIR" -type f \( -name "*.img" -o -name "*.elf" -o -name "*.bin" \))
    if [ -n "$FOUND_ANY_FW" ]; then
       echo "$FOUND_ANY_FW" | while read -r fw_path; do
         cp "$fw_path" "$APP_DIR/"
         echo "-> Firmware-Datei '$(basename "$fw_path")' exportiert"
       done
       if [[ "$FOUND_ANY_FW" == *".img"* ]]; then
         FIRST_FW_IMG=$(basename "$(echo "$FOUND_ANY_FW" | grep '\.img$' | head -n 1)")
       fi
    else
       echo "WARNUNG: Keine kompilierte Firmware im Build-Ordner gefunden!"
    fi
  fi
fi

if [ -z "$FIRST_FW_IMG" ]; then
  FIRST_FW_IMG="domesday-duplicator.img"
fi

# 7c. libusb-1.0.dll kopieren
if [ -f "/mingw64/bin/libusb-1.0.dll" ]; then
  cp "/mingw64/bin/libusb-1.0.dll" "$APP_DIR/"
  echo "-> libusb-1.0.dll erfolgreich kopiert"
else
  echo "WARNUNG: libusb-1.0.dll konnte in /mingw64/bin/ nicht gefunden werden!"
fi

echo "=== 8. Erstelle Windows-Batchdateien (.bat) ==="
# Erstellt eine Hilfedatei, um Parameter einzusehen
cat << 'EOF' > "$APP_DIR/1_Programmer_Hilfe.bat"
@echo off
cd /d "%~dp0"
echo === FX3 PROGRAMMER HILFE ===
fx3-programmer.exe --help
echo.
pause
EOF

# Erstellt eine Batch-Datei zum auflisten der verbundenen Geräte
cat << 'EOF' > "$APP_DIR/2_Programmer_Geräteauflistung.bat"
@echo off
cd /d "%~dp0"
echo === FX3 PROGRAMMER AUFLISTUNG ===
fx3-programmer.exe -l
echo.
pause
EOF

# Erstellt eine Batch-Datei zum Laden in den flüchtigen RAM (-d)
cat << EOF > "$APP_DIR/3_Firmware_RAM_Laden.bat"
@echo off
cd /d "%~dp0"
echo === FIRMWARE IN RAM LADEN ===
fx3-programmer.exe -d "$FIRST_FW_IMG"
echo.
pause
EOF

# Erstellt eine Batch-Datei zum dauerhaften Flashen des PROM (-p)
cat << EOF > "$APP_DIR/4_Firmware_PROM_Flashen.bat"
@echo off
cd /d "%~dp0"
echo === FIRMWARE IN PROM FLASHEN ===
echo Druecke eine Taste, um das dauerhafte Flashen von $FIRST_FW_IMG in das PROM zu starten...
pause
fx3-programmer.exe -p "$FIRST_FW_IMG"
echo.
pause
EOF

# Erstellt eine Batch-Datei zum Verifizieren (-v)
cat << EOF > "$APP_DIR/5_Firmware_Verifizieren.bat"
@echo off
cd /d "%~dp0"
echo === FIRMWARE VERIFIZIEREN ===
fx3-programmer.exe -v "$FIRST_FW_IMG"
echo.
pause
EOF

echo "-> Batchdateien erfolgreich generiert!"

echo "=============================================================================="
echo "ERFOLGREICH! Der FX3-Programmer, Firmware und .bat-Dateien sind bereit unter:"
echo "$APP_DIR"
echo "=============================================================================="
