# Dependencias del shell de Quickshell — Arch y Debian

Guía de instalación limpia para un sistema recién instalado. Copia y pega
el bloque completo de tu distro; luego copia solo la sección de tu
compositor (Hyprland / Sway / Niri).

---

## 1. Quickshell (el shell en sí)

**Arch** (solo por AUR, no está en repos oficiales):
```bash
# con paru
paru -S quickshell-git
# o con yay
yay -S quickshell-git
```

**Debian** (testing/unstable, empaquetado oficialmente):
```bash
sudo apt install quickshell
```

---

## 2. Dependencias universales (las tres variantes las necesitan)

**Arch:**
```bash
sudo pacman -S brightnessctl wl-clipboard networkmanager wlsunset \
    imagemagick libnotify wireplumber curl swaybg
```

**Debian:**
```bash
sudo apt install brightnessctl wl-clipboard network-manager wlsunset \
    imagemagick libnotify-bin wireplumber curl swaybg
```

Qué hace cada uno:
| Paquete | Para qué lo usa el shell |
|---|---|
| brightnessctl | Control de brillo |
| wl-clipboard | `wl-copy`/`wl-paste` — portapapeles y copiar capturas |
| network-manager / networkmanager | `nmcli` — panel de Wi-Fi |
| wlsunset | Luz nocturna |
| imagemagick | `convert` — miniaturas de wallpapers |
| libnotify / libnotify-bin | `notify-send` — notificaciones de captura de pantalla |
| wireplumber | `wpctl` — control de volumen con la rueda del mouse |
| curl | Búsqueda y descarga de wallpapers de Wallhaven |
| swaybg | Wallpaper de respaldo si no tienes awww/hyprpaper |

---

## 3. Portapapeles con historial (cliphist) — no está en repos oficiales de ninguno de los dos

**Arch (AUR):**
```bash
paru -S cliphist
```

**Debian (binario manual, no está en apt):**
```bash
curl -L -o /tmp/cliphist.tar.gz \
    https://github.com/sentriz/cliphist/releases/latest/download/cliphist_linux_amd64.tar.gz
tar -xzf /tmp/cliphist.tar.gz -C /tmp
sudo install -m755 /tmp/cliphist /usr/local/bin/cliphist
```

---

## 4. Capturas de pantalla (grim + slurp)

**Arch:**
```bash
sudo pacman -S grim slurp
```

**Debian:**
```bash
sudo apt install grim slurp
```

(En Niri no hace falta: usa su propio sistema nativo de capturas.)

---

## 5. Rust/cargo — necesario para matugen y awww (ninguno está en apt)

**Arch:**
```bash
sudo pacman -S rust
```

**Debian:**
```bash
sudo apt install cargo
```

---

## 6. Theming automático de color (matugen)

**Ambas distros** (vía cargo, no está empaquetado en ninguna):
```bash
cargo install matugen
# el binario queda en ~/.cargo/bin/matugen — agrégalo a tu PATH si no
# aparece: echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
```

Alternativa Arch (AUR, evita compilar):
```bash
paru -S matugen-bin
```

---

## 7. Wallpaper con transición (awww — reemplaza a swww, que está deprecado)

**Arch (AUR):**
```bash
paru -S awww
```

**Debian** (no está en apt, compilar con cargo):
```bash
cargo install --git https://codeberg.org/LGFae/awww awww
```

Si prefieres no instalar nada de esto, el shell cae automáticamente a
`swaybg` (ya instalado en el paso 2) — solo pierdes la transición animada
al cambiar de wallpaper.

---

## 8. Nerd Font (los iconos de la barra son glifos de una Nerd Font)

**IMPORTANTE:** ni Arch ni Debian tienen en sus repos oficiales una
versión ya parcheada con los glifos de iconos — el paquete normal
`ttf-jetbrains-mono`/`fonts-jetbrains-mono` es la fuente SIN los iconos.
Sin este paso, vas a ver cuadros vacíos o "?" en vez de los iconos de la
barra.

**Método universal (funciona igual en ambas distros):**
```bash
mkdir -p ~/.local/share/fonts
curl -L -o /tmp/JetBrainsMono.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerd
fc-cache -fv
```

(Alternativa en Arch vía AUR si prefieres que pacman la gestione:
`paru -S ttf-jetbrains-mono-nerd` — verifica el nombre exacto en AUR, a
veces cambia.)

---

## 9. Solo si usas Hyprland

**Arch:**
```bash
sudo pacman -S hyprland hyprpaper xdg-desktop-portal-hyprland
```

**Debian (testing):**
```bash
sudo apt install hyprland hyprpaper xdg-desktop-portal-hyprland
```

---

## 10. Solo si usas Sway

**Arch:**
```bash
sudo pacman -S sway swayidle swaylock
```

**Debian:**
```bash
sudo apt install sway swayidle swaylock
```

---

## 11. Solo si usas Niri

**Arch (AUR):**
```bash
paru -S niri
```

**Debian:** revisa si tu versión de Debian ya lo empaqueta
(`apt search niri`); si no, hay binarios en las releases de GitHub del
proyecto.

---

## 12. Complementarios que usan los atajos de teclado portados (opcional)

Estos no los usa el shell directamente, pero sí los binds que armamos en
`hyprland.lua`/`sway config`/`niri config.kdl`:

**Arch:**
```bash
sudo pacman -S fuzzel alacritty thunar playerctl network-manager-applet
```

**Debian:**
```bash
sudo apt install fuzzel alacritty thunar playerctl network-manager-gnome
```

---

## Orden recomendado para una instalación limpia

1. Secciones 9/10/11 (tu compositor) — probablemente ya lo tienes si estás leyendo esto
2. Sección 1 (Quickshell)
3. Sección 2 (dependencias universales)
4. Sección 8 (Nerd Font — hazlo pronto, o vas a ver la barra "rota" visualmente el resto del proceso)
5. Secciones 3, 4, 5+6+7 (portapapeles, capturas, theming) en el orden que quieras
6. Sección 12 (opcional)

Después de todo esto, copia la carpeta del shell a `~/.config/quickshell/`
(o `~/.config/quickshell/sway/` si tienes varios compositores en la misma
máquina) y lanza con `quickshell -c ~/.config/quickshell`.
