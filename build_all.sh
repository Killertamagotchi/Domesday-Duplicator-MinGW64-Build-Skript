#!/bin/bash
echo "=================================================================="
echo "      DOMESDAY DUPLICATOR COMPLETE MASTER BUILD SYSTEM           "
echo "=================================================================="
set -e

START_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
PROJECT_FOLDER=$(ls -d *DomesdayDuplicator* 2>/dev/null | head -n 1)

if [ -z "$PROJECT_FOLDER" ] || [ ! -d "$PROJECT_FOLDER" ]; then
    echo "=== ERROR: Kein Projektordner mit 'DomesdayDuplicator' im Namen gefunden! ==="
    exit 1
fi

REPO_PATH="$START_DIR/$PROJECT_FOLDER"

# === 1. ZENTRALES GIT-UPDATE ===
echo ""
echo "--> SCHRITT 1: Aktualisiere Quellcode von GitHub..."
cd "$REPO_PATH"
git stash --quiet || true
echo "Lade neueste Code-Änderungen herunter..."
git pull origin main || git pull origin master || echo "Hinweis: Git Pull fehlgeschlagen. Nutze lokalen Stand."
git stash pop --quiet 2>/dev/null || true

# === 2. VERSIONSNUMMER ZENTRAL ERMITTELN ===
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    GIT_HASH="${GIT_HASH}-dirty"
    echo "Status: Ungespeicherte lokale Änderungen im Repository!"
fi
echo "Zentrale Build-Version für diesen Durchlauf: $GIT_HASH"
export GIT_HASH
cd "$START_DIR"

# === 3. COMPONENT BUILDS ===
echo ""
echo "--> SCHRITT 2: Starte Kompilierung der Haupt-App (GUI)..."
APP_SCRIPT=$(ls build_dd.sh build_app.sh 2>/dev/null | head -n 1)
./"$APP_SCRIPT"

echo ""
echo "--> SCHRITT 3: Starte Kompilierung der FX3 USB-Firmware & Programmer..."
FX3_SCRIPT=$(ls build-fx3-programmer.sh build_fx3.sh 2>/dev/null | head -n 1)
./"$FX3_SCRIPT"

echo ""
echo "--> SCHRITT 4: Starte Kompilierung der FPGA Gateware..."
./build_fpga.sh

echo ""
echo "=================================================================="
echo "===        MASTER BUILD VOLLSTÄNDIG ERFOLGREICH!               ==="
echo "  Alle 3 Komponenten (App, FX3-Firmware, FPGA) sind aktuell!      "
echo "=================================================================="
