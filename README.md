# Domesday-Duplicator-MinGW64-Build-Skript

Kompakte MinGW64-Build-Skripte für das **Domesday Duplicator** Projekt. 

Diese Sammlung aus vier `.sh`-Dateien erleichtert das Aktualisieren und Kompilieren des Quellcodes unter Windows mithilfe von MinGW64.

## 📋 Übersicht der Komponenten

Das Repository enthält drei Skripte für die einzelnen Komponenten sowie ein Hauptskript:

* **Domesday Duplicator App** – Kompiliert die Hauptanwendung.
* **FX3 Firmware & Programmer** – Kompiliert die Firmware und das Programmiertool.
* **FPGA Firmware** – Kompiliert die FPGA-Firmware. *Hinweis: Das Skript sucht automatisch in der Windows-Registry nach deiner Quartus-Installation und fügt den Pfad für den Build-Prozess temporär zur Umgebungsvariable hinzu.*
* **Hauptskript (Alles-in-einem)** – Führt alle drei oben genannten Skripte nacheinander aus, um das gesamte Projekt in einem Rutsch zu bauen.

> 💡 **Bequemer Start:** Jedem Shell-Skript liegt eine passende `.bat`-Datei bei. Dadurch lassen sich die Skripte direkt per Doppelklick aus dem Windows-Explorer heraus starten, ohne vorher manuell das MinGW64-Terminal öffnen zu müssen.

## ⚙️ Voraussetzungen & Ordnerstruktur

* **MinGW64** (für die Windows-Kompilierung)
* **Altera/Intel Quartus** (wird für die FPGA-Firmware benötigt, muss aber dank Registry-Suche nicht manuell im Systempfad hinterlegt sein)

Damit die Skripte korrekt funktionieren, müssen sie relativ zum geklonten Quellcode platziert werden. Richte deine Ordnerhierarchie wie folgt ein:

```text
Dein-Projektordner/
├── DomesdayDuplicator/   # Das von GitHub geklonte Original-Repository
└── build_dd.sh           # Das Automatisierungs-Skript (sowie die weiteren Skripte)
```

## 🚀 Nutzung

1. Klone das offizielle Domesday-Duplicator-Repository in deinen Projektordner.
2. Platziere diese Build-Skripte direkt daneben (siehe Struktur oben).
3. Starte das gewünschte Skript entweder über die `.sh`-Datei im MinGW64-Terminal oder komfortabel über die entsprechende `.bat`-Datei per Doppelklick.

Downloads:  
MinGW64: https://www.msys2.org/  
Quartus: https://www.altera.com/downloads/fpga-development-tools/quartus-prime-lite-edition-design-software-version-25-1-windows  

____________________________________________________

# Domesday-Duplicator-MinGW64-Build-Script

Lightweight MinGW64 build scripts for the **Domesday Duplicator** project.

This collection of four `.sh` files simplifies the process of updating and compiling the source code under Windows using MinGW64.

## 📋 Overview of Components

The repository contains three scripts for individual components and one main script:

* **Domesday Duplicator App** – Compiles the main application.
* **FX3 Firmware & Programmer** – Compiles the firmware and the programming tool.
* **FPGA Firmware** – Compiles the FPGA firmware. *Note: The script automatically searches the Windows Registry for your Quartus installation and temporarily adds the path to the environment variables for the build process.*
* **Main Script (All-in-One)** – Executes all three scripts above sequentially to build the entire project in one go.

> 💡 **Convenient Launch:** Each shell script comes with a matching `.bat` file. This allows you to launch the scripts with a simple double-click from Windows Explorer, without having to open the MinGW64 terminal manually.

## ⚙️ Requirements & Folder Structure

* **MinGW64** (for Windows compilation)
* **Altera/Intel Quartus** (required for the FPGA firmware, but does not need to be manually added to your system PATH thanks to the automated Registry search)

For the scripts to work correctly, they must be placed relative to the cloned source code. Set up your folder hierarchy like this:

```text
Your-Project-Folder/
├── DomesdayDuplicator/   # The original repository cloned from GitHub
└── build_dd.sh           # The automation script (along with the other scripts)
```

## 🚀 Usage

1. Clone the official Domesday Duplicator repository into your project folder.
2. Place these build scripts directly next to it (as shown in the structure above).
3. Run your desired script either via the `.sh` file inside the MinGW64 terminal or comfortably by double-clicking the corresponding `.bat` file.

Downloads:  
MinGW64: https://www.msys2.org/  
Quartus: https://www.altera.com/downloads/fpga-development-tools/quartus-prime-lite-edition-design-software-version-25-1-windows  
