#!/bin/bash
# export PATH=$PATH:/h/altera_lite/25.1std/quartus/bin64

# Automatische Suche nach Quartus auf allen verfügbaren Windows-Laufwerken
QUARTUS_BIN=""

# Ermittelt alle gemounteten Windows-Laufwerke (z. B. /cygdrive/c, /cygdrive/d, /c, /d)
AVAILABLE_DRIVES=$(mount | awk '{print $3}' | grep -E '^/(cygdrive/)?([a-zA-Z])$' | sort -u)

# Falls mount keine Ergebnisse liefert, nutzen wir Standard-Laufwerke als Fallback
if [ -z "$AVAILABLE_DRIVES" ]; then
    AVAILABLE_DRIVES="/cygdrive/c /cygdrive/d /cygdrive/e"
fi

for drive in $AVAILABLE_DRIVES; do
    for folder in "intelFPGA_lite" "altera_lite" "intelFPGA"; do
        base_dir="$drive/$folder"
        if [ -d "$base_dir" ]; then
            # Sucht nach dem bin64-Ordner in der höchsten Versionsnummer (sortiert nach Version)
            LATEST_BIN=$(ls -d "$base_dir"/*/quartus/bin64 2>/dev/null | sort -V | tail -n 1)
            if [ -d "$LATEST_BIN" ]; then
                QUARTUS_BIN="$LATEST_BIN"
                break 2 # Bricht beide Schleifen ab, sobald die erste gültige Installation gefunden wurde
            fi
        fi
    done
done

if [ -n "$QUARTUS_BIN" ]; then
    export PATH="$PATH:$QUARTUS_BIN"
    echo "Quartus-Pfad automatisch gefunden: $QUARTUS_BIN"
else
    echo "=== ERROR: Keine Quartus-Installation auf den verfügbaren Laufwerken gefunden! ==="
    exit 1
fi

echo "=== Starte Domesday Duplicator FPGA Build ==="

START_DIR=$(pwd)
OUTPUT_DIR="$START_DIR/FPGA Firmware"
PROJECT_FOLDER=$(ls -d *DomesdayDuplicator* 2>/dev/null | head -n 1)

if [ -z "$PROJECT_FOLDER" ] || [ ! -d "$PROJECT_FOLDER" ]; then
    echo "=== ERROR: Kein Projektordner mit 'DomesdayDuplicator' im Namen gefunden! ==="
    exit 1
fi

# Weiche: Nutzt den vom Masterskript exportierten Hash oder liest ihn lokal aus
if [ -z "$GIT_HASH" ]; then
    cd "$START_DIR/$PROJECT_FOLDER"
    GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        GIT_HASH="${GIT_HASH}-dirty"
    fi
    cd "$START_DIR"
fi

if [ -z "$GIT_HASH" ]; then
    GIT_HASH="0000000"
fi
echo "Aktueller Versions-Hash: $GIT_HASH"

SRC_DIR="$START_DIR/$PROJECT_FOLDER/fpga"
BUILD_DIR="$START_DIR/$PROJECT_FOLDER/build/fpga"

if [ ! -d "$SRC_DIR" ]; then
    echo "=== ERROR: Der Ordner 'fpga/' wurde in $PROJECT_FOLDER not gefunden! ==="
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/common"
cp -r "$SRC_DIR"/* "$BUILD_DIR/"

echo "Generiere offizielle version.vh in der Sandbox..."
chmod +x "$SRC_DIR/generate-version.sh"
"$SRC_DIR/generate-version.sh" "$BUILD_DIR/common" "$GIT_HASH"

cd "$BUILD_DIR"
QPF_PATH=$(find . -name "*.qpf" -print -quit)
if [ -z "$QPF_PATH" ]; then
    echo "=== ERROR: Keine .qpf Datei gefunden! ==="
    exit 1
fi

PROJECT_SUBDIR=$(dirname "$QPF_PATH")
PROJECT_NAME=$(basename "$QPF_PATH" .qpf)
cd "$PROJECT_SUBDIR"
FINAL_BUILD_SUBDIR=$(pwd)

echo "Kompiliere Quartus-Projekt: $PROJECT_NAME..."
quartus_sh --flow compile "$PROJECT_NAME"

if [ $? -eq 0 ]; then
	echo "=== Quartus Build erfolgreich! ==="
	rm -rf "$OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"

    
    # Ihre funktionierende Pfadkonvertierung
    WIN_OUTPUT_DIR=$(cygpath -w "$OUTPUT_DIR" | tr '\\' '/')
    SOF_FILE=$(find "$FINAL_BUILD_SUBDIR" -type f -name "*.sof" -print -quit)
    WIN_SOF_FILE=$(cygpath -w "$SOF_FILE" | tr '\\' '/')
    
    if [ -n "$SOF_FILE" ]; then
        echo "1. Konvertiere .sof zu flüchtigem .rbf-Format..."
        quartus_cpf -c "$SOF_FILE" "$OUTPUT_DIR/${PROJECT_NAME}.rbf"
        
        echo "2. Erstelle temporäre Konfigurationsdatei (.cof)..."
        cat <<EOF > jic_config.cof
<?xml version="1.0" encoding="US-ASCII" standalone="yes"?>
<cof>
    <eprom_name>EPCS64</eprom_name>
    <flash_loader_device>EP4CE22</flash_loader_device>
    <output_filename>${WIN_OUTPUT_DIR}/${PROJECT_NAME}.jic</output_filename>
    <n_pages>1</n_pages>
    <width>1</width>
    <mode>7</mode>
    <sof_data>
        <user_name>Page_0</user_name>
        <page_flags>1</page_flags>
        <bit0>
            <sof_filename>${WIN_SOF_FILE}</sof_filename>
        </bit0>
    </sof_data>
    <version>10</version>
    <create_cvp_file>0</create_cvp_file>
    <create_hps_img_file>0</create_hps_img_file>
    <options><map_file>1</map_file></options>
</cof>
EOF
        echo "3. Generiere permanente .jic-Datei aus .sof..."
        quartus_cpf -c jic_config.cof
        rm -f jic_config.cof
        cp "$SOF_FILE" "$OUTPUT_DIR/"
    fi
    echo "=== FPGA BUILD ERFOLGREICH BEENDET! ==="
else
    echo "=== ERROR: FPGA Build fehlgeschlagen! ==="
    exit 1
fi
