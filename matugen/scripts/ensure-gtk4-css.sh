#!/bin/sh
# Asegura que GTK4 importe la paleta generada por matugen.
# ~/.config/gtk-4.0/gtk.css era un symlink al tema Darkly y su @import
# se resolvía dentro del directorio del tema, donde colors.css no existe.
GTK4_DIR="$HOME/.config/gtk-4.0"
mkdir -p "$GTK4_DIR"
for F in "$GTK4_DIR/gtk.css" "$GTK4_DIR/gtk-dark.css"; do
    [ -L "$F" ] && rm -f "$F"
    [ -e "$F" ] || printf "@import 'colors.css';\n" > "$F"
done

# El gtk.css de Darkly también importa 'colors.css' de forma relativa.
# Enlazamos su copia local a la paleta de matugen para evitar el warning.
DARKLY_GTK4="$HOME/.local/share/themes/Darkly/gtk-4.0"
if [ -d "$DARKLY_GTK4" ] && [ ! -e "$DARKLY_GTK4/colors.css" ]; then
    ln -sfn "$GTK4_DIR/colors.css" "$DARKLY_GTK4/colors.css"
fi
