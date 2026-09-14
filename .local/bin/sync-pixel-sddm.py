#!/usr/bin/env python3
"""Copia el wallpaper actual de Sway al fondo del tema 'pixel' de SDDM.

Uso:
    sync-pixel-sddm.py /ruta/al/wallpaper.jpg

Sin dependencias de iNiR/Quickshell: la ruta del wallpaper se recibe
como argumento (normalmente pasada por sync-sway-sddm.sh).
"""

import os
import shutil
import subprocess
import sys

THEME_NAME = "pixel"
THEME_DIR = f"/usr/share/sddm/themes/{THEME_NAME}"
ASSETS_DIR = os.path.join(THEME_DIR, "assets")
BG_DEST = os.path.join(ASSETS_DIR, "background.png")

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".gif", ".webp"}


def extract_video_frame(video_path):
    """Usa ffmpeg para extraer el primer frame de un video/gif como PNG."""
    if not shutil.which("ffmpeg"):
        print("[sddm-pixel] ffmpeg no encontrado — no se puede extraer frame")
        return None
    tmp = "/tmp/sddm-pixel-frame.tmp.png"
    try:
        proc = subprocess.run(
            ["ffmpeg", "-y", "-i", video_path, "-vframes", "1", "-update", "1", "-f", "image2", tmp],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
        if proc.returncode == 0 and os.path.isfile(tmp):
            return tmp
        print(f"[sddm-pixel] Fallo al extraer frame de {os.path.basename(video_path)}")
        return None
    except Exception as e:
        print(f"[sddm-pixel] Error de ffmpeg: {e}")
        return None


def main():
    if len(sys.argv) < 2:
        print("[sddm-pixel] Uso: sync-pixel-sddm.py /ruta/al/wallpaper")
        sys.exit(1)

    wallpaper_path = sys.argv[1]

    if not os.path.isfile(wallpaper_path):
        print(f"[sddm-pixel] El wallpaper no existe: {wallpaper_path}")
        sys.exit(1)

    if not os.path.isdir(THEME_DIR):
        print(f"[sddm-pixel] Tema no encontrado en {THEME_DIR}")
        sys.exit(1)

    if not os.path.isdir(ASSETS_DIR):
        try:
            os.makedirs(ASSETS_DIR, exist_ok=True)
        except PermissionError:
            print(f"[sddm-pixel] Permiso denegado creando {ASSETS_DIR}")
            print(f"[sddm-pixel] Corre: sudo chown -R $USER:$USER {THEME_DIR}")
            sys.exit(1)

    ext = os.path.splitext(wallpaper_path)[1].lower()
    src = wallpaper_path
    tmp_frame = None

    if ext in VIDEO_EXTENSIONS:
        tmp_frame = extract_video_frame(wallpaper_path)
        if tmp_frame is None:
            print("[sddm-pixel] Se mantiene el fondo actual (video/gif sin ffmpeg)")
            sys.exit(1)
        src = tmp_frame

    try:
        shutil.copy2(src, BG_DEST)
        print(f"[sddm-pixel] Fondo actualizado: {os.path.basename(wallpaper_path)}")
    except PermissionError:
        print(f"[sddm-pixel] Permiso denegado escribiendo {BG_DEST}")
        print(f"[sddm-pixel] Corre: sudo chown -R $USER:$USER {THEME_DIR}")
        sys.exit(1)
    except Exception as e:
        print(f"[sddm-pixel] Error copiando fondo: {e}")
        sys.exit(1)
    finally:
        if tmp_frame and os.path.isfile(tmp_frame):
            os.unlink(tmp_frame)


if __name__ == "__main__":
    main()
