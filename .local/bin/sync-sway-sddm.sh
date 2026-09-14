#!/usr/bin/env bash
set -euo pipefail

SYNC_SCRIPT="${HOME}/.local/bin/sync-pixel-sddm.py"
WALLPAPERS_DIR="${HOME}/Pictures/Wallpapers"

WALLPAPER=""

echo "[Sway-SDDM] Detectando fondo de pantalla activo..."

# 1. awww (mantenido activamente) o swww (legado) — usado en Sway/Umbriel
if command -v awww &> /dev/null && awww query &> /dev/null; then
    WALLPAPER=$(awww query | awk -F 'image: ' '{print $2}' | head -n 1)
elif command -v swww &> /dev/null && swww query &> /dev/null; then
    WALLPAPER=$(swww query | awk -F 'image: ' '{print $2}' | head -n 1)

# 2. hyprpaper — usado normalmente en Hyprland
# Formato de salida: "eDP-1: /home/user/wallpapers/wp1.jpg" (una línea por monitor)
elif command -v hyprctl &> /dev/null && hyprctl hyprpaper listactive &> /dev/null; then
    WALLPAPER=$(hyprctl hyprpaper listactive | head -n 1 | sed 's/^[^:]*: *//')

# 3. swaybg — fallback genérico por proceso, sin depender del compositor
elif pgrep -x "swaybg" &> /dev/null; then
    WALLPAPER=$(ps aux | grep '[s]waybg' | grep -oE '\-i\s+[^ ]+' | awk '{print $2}' | sed "s|~|$HOME|")
fi

# 4. Validación y fallback al directorio de Wallpapers si la detección automática falla
if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "[Sway-SDDM] ⚠ No se detectó un proceso activo (awww/hyprpaper/swaybg). Buscando el archivo más reciente en $WALLPAPERS_DIR..."
    if [ -d "$WALLPAPERS_DIR" ]; then
        WALLPAPER=$(find "$WALLPAPERS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.mp4" -o -name "*.webm" \) -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d' ')
    fi
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "[Sway-SDDM] ✗ Error: No se encontró ningún fondo de pantalla válido."
    exit 1
fi

echo "[Sway-SDDM] ✓ Fondo detectado: $WALLPAPER"

# 5. Sincronizar con el tema de SDDM
if [ -f "$SYNC_SCRIPT" ]; then
    echo "[Sway-SDDM] Sincronizando con el tema pixel de SDDM..."
    python3 "$SYNC_SCRIPT" "$WALLPAPER"
else
    echo "[Sway-SDDM] ✗ Error: No se encontró el script en $SYNC_SCRIPT."
    echo "Se intentará una copia directa como alternativa de emergencia..."
    mkdir -p /usr/share/sddm/themes/pixel/assets
    cp "$WALLPAPER" /usr/share/sddm/themes/pixel/assets/background.png
fi

echo "[Sway-SDDM] ¡Proceso finalizado con éxito!"
