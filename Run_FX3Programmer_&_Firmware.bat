@echo off
title Domesday Duplicator FX3 programmer & Firmware Build System

echo ==================================================================
echo   Starte MSYS2 MinGW64-Umgebung fuer Domesday Duplicator Build...
echo ==================================================================
echo.

rem Startet das MSYS2/MinGW64-Terminal und fuehrt die build-fx3-programmer.sh im aktuellen Verzeichnis aus
C:\msys64\msys2_shell.cmd -mingw64 -where "%~dp0" -c "./build-fx3-programmer.sh"

echo.
echo ==================================================================
echo   Der Build-Prozess wurde an MSYS2 uebergeben.
echo   Dieses Fenster schliesst sich jetzt. Die Explorer-Fenster 
echo   oeffnen sich automatisch, sobald der Build fertig ist!
echo ==================================================================
timeout /t 5