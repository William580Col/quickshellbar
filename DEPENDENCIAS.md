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
    imagemagick libnotify wireplumber curl swaybg dialog firefox \
    ttf-roboto ttf-nerd-fonts-symbols
```

**Debian:**
```bash
sudo apt install brightnessctl wl-clipboard network-manager wlsunset \
    imagemagick libnotify-bin wireplumber curl swaybg dialog firefox-esr \
    fonts-roboto
# Símbolos Nerd Font (no están en apt):
curl -fL -o /tmp/Symbols.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
unzip -o /tmp/Symbols.zip -d ~/.local/share/fonts/NerdFontsSymbolsOnly
fc-cache -fv
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

## 10b. SDDM (gestor de sesiones) y tema pixel

El tema `pixel` usa `Qt5Compat.GraphicalEffects`, así que además de SDDM
hay que instalar el módulo de compatibilidad Qt5:

**Arch:**
```bash
sudo pacman -S sddm qt6-5compat
```

**Debian:**
```bash
sudo apt install sddm qml6-module-qt5compat-graphicaleffects
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

## 11b. Solo si usas Umbriel

**Arch (AUR):**
```bash
paru -S umbriel-git
# XWayland requiere xwayland-satellite (está en repos extra):
sudo pacman -S xwayland-satellite
```

**Debian:** Umbriel no está en los repos oficiales (usa el repositorio apt de
NickH; ver `docs.noctalia.dev/umbriel/installation/`). `xwayland-satellite`
tampoco está empaquetado: se compila con cargo o se usan los binarios de GitHub.

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

## 13. Compresión (unzip / 7zip / unrar)

El `unzip` también lo necesita el instalador para extraer los `.zip` de
Quickshell.

**Arch:**
```bash
sudo pacman -S unzip 7zip unrar
```

**Debian:**
```bash
sudo apt install unzip 7zip unrar-free
```
(`unrar` de RARLAB está en el repo *non-free*; si lo habilitaste, usa `unrar`.)

---

## 14. Thunar (gestor de archivos) con todas sus dependencias

Incluye montaje automático (GVFS), `thunar-volman`, plugins de archivos y
miniaturas (`tumbler`/[libre]thumbnailer) y un archivador (`file-roller`).

**Arch:**
```bash
sudo pacman -S thunar thunar-volman thunar-archive-plugin \
    thunar-media-tags-plugin tumbler ffmpegthumbnailer \
    gvfs gvfs-mtp gvfs-smb file-roller
```

**Debian:**
```bash
sudo apt install thunar thunar-volman thunar-archive-plugin \
    tumbler ffmpegthumbnailer gvfs gvfs-backends gvfs-fuse file-roller
```

---

## 15. Aplicaciones adicionales

**Arch:**
```bash
sudo pacman -S firefox evince peazip geany gnome-calculator flatpak \
    mpv papirus-icon-theme adw-gtk-theme nwg-look qt5ct qt6ct
# AUR
paru -S onlyoffice-bin darkly-bin tela-icon-theme pacseek-bin
```

**Debian:**
```bash
sudo apt install firefox-esr evince geany gnome-calculator flatpak \
    mpv papirus-icon-theme qt5ct qt6ct
```
Paquetes que *no* están en apt: Peazip (https://peazip.github.io/),
Tela icon (github.com/vinceliuice/Tela-icon-theme), adw-gtk3
(gitlab.com/julianfairfax/package-repo), nwg-look (compilar desde source),
OnlyOffice (flatpak: `flatpak install flathub org.onlyoffice.desktopeditors`)
y Darkly (github.com/Bali10050/Darkly).

---

## 15b. OnlyOffice (oficina) y Pacseek (explorador AUR)

- **OnlyOffice:** en Arch se instala vía AUR (`onlyoffice-bin`). En Debian
  usa el Flatpak una vez añadido Flathub:
  `flatpak install flathub org.onlyoffice.desktopeditors`.
- **Pacseek:** explorador de paquetes de Arch desde la terminal
  (`paru -S pacseek-bin`). Solo para Arch.

---

## 15c. OpenCode (AI coding agent)

Instala el script oficial (funciona en Arch y Debian):
```bash
curl -fsSL https://opencode.ai/install | bash
```
O en Arch también hay paquete oficial: `sudo pacman -S opencode`.

---

## 15d. Temas oscuros: GTK (adw-gtk3-dark) + iconos (Tela/Papirus) + Qt (Darkly)

- **adw-gtk-theme** (Arch) trae `adw-gtk3` y `adw-gtk3-dark` (también
  disponible vía AUR `adw-gtk-theme-git`).
- **Tela icon** (AUR) y **Papirus** (repos) son los temas de iconos.
- **Darkly** (AUR `darkly-bin`) es un estilo oscuro para aplicaciones Qt
  (fork de Lightly). Se selecciona en la UI de `qt5ct` o con
  `QT_STYLE_OVERRIDE=Darkly`.
- **nwg-look** es un selector GTK estilo LXAppearance para Wayland, útil
  para cambiar temas/iconos/cursor sin GNOME.

**Activación manual del tema oscuro:**
```bash
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Tela-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

El instalador puede hacerlo solo (paso interactivo "Configurar tema oscuro"):
escribe `~/.config/gtk-3.0/settings.ini` y `gtk-4.0`, paletas oscuras de
`qt5ct`/`qt6ct` y `~/.config/environment.d/theme.conf`
(`QT_QPA_PLATFORMTHEME=qt5ct`, `GTK_THEME=adw-gtk3-dark`).

---

## Orden recomendado para una instalación limpia

1. Secciones 9/10/11 (tu compositor) — probablemente ya lo tienes si estás leyendo esto
2. Sección 1 (Quickshell)
3. Sección 2 (dependencias universales)
4. Sección 8 (Nerd Font — hazlo pronto, o vas a ver la barra "rota" visualmente el resto del proceso)
5. Secciones 3, 4, 5+6+7 (portapapeles, capturas, theming) en el orden que quieras
6. Sección 12 (opcional)
7. Secciones 13, 14 y 15 (compresión, Thunar y aplicaciones)
8. Sección 15d (temas oscuros) — al final, tras instalar temas e iconos

Después de todo esto, copia la carpeta del shell a `~/.config/quickshell/`
(o `~/.config/quickshell/sway/` si tienes varios compositores en la misma
máquina) y lanza con `quickshell -c ~/.config/quickshell`.
