#!/bin/sh
# set-tela-variant.sh [dark|light]
# Rota la variante de iconos Tela-circle según el color dominante del
# wallpaper (hex primary en ~/.local/state/quickshell-accent).
# Actualiza settings.ini (gtk-3.0 y gtk-4.0) y gsettings.

MODE="$1"
[ -z "$MODE" ] && MODE="$2"
[ -z "$MODE" ] && MODE="dark"

ACCENT_FILE="$HOME/.local/state/quickshell-accent"
HEX="$(cat "$ACCENT_FILE" 2>/dev/null | tr -d ' \n\r\t')"
HEX="${HEX#\#}"
case "$HEX" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
    *) HEX="8aa2ff" ;;
esac

if command -v python3 >/dev/null 2>&1; then
    VARIANT="$(python3 - "$HEX" "$MODE" <<'EOF'
import sys, colorsys
hexs, mode = sys.argv[1], sys.argv[2]
r, g, b = int(hexs[0:2], 16) / 255, int(hexs[2:4], 16) / 255, int(hexs[4:6], 16) / 255
h, l, s = colorsys.rgb_to_hls(r, g, b)
h *= 360
if s < 0.12:
    v = "dracula" if mode == "dark" else "grey"
elif l < 0.12:
    v = "black"
elif 10 <= h < 45 and l < 0.35:
    v = "brown"
elif h < 12 or h >= 345:
    v = "red"
elif h < 45:
    v = "orange"
elif h < 75:
    v = "yellow"
elif h < 170:
    v = "green"
elif h < 240:
    v = "blue"
elif h < 295:
    v = "purple"
else:
    v = "pink"
print(v)
EOF
)"
else
    VARIANT="$(echo "$HEX" | awk '{
        r = strtonum("0x" substr($0,1,2)) / 255
        g = strtonum("0x" substr($0,3,2)) / 255
        b = strtonum("0x" substr($0,5,2)) / 255
        mx = (r > g ? (r > b ? r : b) : (g > b ? g : b))
        mn = (r < g ? (r < b ? r : b) : (g < b ? g : b))
        d = mx - mn
        l = (mx + mn) / 2
        s = (d == 0) ? 0 : d / (1 - (2*l-1 >= 0 ? 2*l-1 : -(2*l-1)))
        if (d == 0) h = 0
        else if (mx == r) { h = 60 * ((g-b)/d); if (h < 0) h += 360 }
        else if (mx == g) h = 60 * ((b-r)/d + 2)
        else h = 60 * ((r-g)/d + 4)
        if (s < 0.12) v = "grey"
        else if (l < 0.12) v = "black"
        else if (h < 12 || h >= 345) v = "red"
        else if (h < 45) v = "orange"
        else if (h < 75) v = "yellow"
        else if (h < 170) v = "green"
        else if (h < 240) v = "blue"
        else if (h < 295) v = "purple"
        else v = "pink"
        print v
    }')"
fi

case "$VARIANT" in
    red|orange|yellow|green|teal|blue|purple|pink|brown|grey|black|white|dracula|nord|manjaro) ;;
    *) VARIANT="grey" ;;
esac

CURRENT="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
SUFFIX=""
case "$CURRENT" in
    *-dark) SUFFIX="-dark" ;;
esac
[ "$MODE" = "dark" ] && SUFFIX="-dark"

THEME="Tela-circle-$VARIANT$SUFFIX"
[ -d "/usr/share/icons/$THEME" ] || { VARIANT="grey"; THEME="Tela-circle-grey$SUFFIX"; }
[ -d "/usr/share/icons/$THEME" ] || THEME="Tela-circle-grey-dark"
[ -d "/usr/share/icons/$THEME" ] || THEME="Tela-circle"

for F in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$F" ] || continue
    if grep -q '^gtk-icon-theme-name=' "$F"; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$THEME/" "$F"
    else
        printf 'gtk-icon-theme-name=%s\n' "$THEME" >> "$F"
    fi
done

gsettings set org.gnome.desktop.interface icon-theme "$THEME" 2>/dev/null || true
echo "icon-theme -> $THEME (accent #$HEX, mode $MODE)"
