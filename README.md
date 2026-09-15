# Instalador de dotfiles — Niri · Sway · Hyprland · Umbriel

Instalador interactivo (CLI) para las configuraciones y dependencias del
ecosistema Quickshell sobre los compositores **Niri**, **Sway**, **Hyprland** y
**Umbriel**.

Detecta automáticamente la distro (**Arch** o **Debian** y derivadas), usa el
helper AUR disponible (`paru`/`yay`) en Arch, y ofrece menús basados en
[`dialog`](https://invisible-island.net/dialog/) con fallback a menús de
consola cuando `dialog` no está instalado o no hay TTY.

## Requisitos

- `bash` 4+
- En modo interactivo: `dialog` (opcional — hay fallback a consola)
- `curl` y `unzip` (para la Nerd Font, cliphist y los zips de Quickshell)
- Arch: `pacman` + un helper AUR (`paru` o `yay`) para los paquetes del AUR
- Debian: `apt-get`

## Uso

```bash
cd /home/william/proyecto

# Menú interactivo (elige compositores y acción)
./install.sh

# Modo directo (no interactivo)
./install.sh --compositor sway --deps       # solo dependencias
./install.sh --compositor niri --dotfiles   # solo dotfiles
./install.sh --compositor hypr --ambos      # dependencias + dotfiles

# Varios compositores a la vez
./install.sh --compositor hypr,sway --ambos
./install.sh --todos --dotfiles             # los 4 compositores

# Desinstalar / restaurar (revierte a los respaldos .bak-*)
./install.sh --compositor sway --restaurar

./install.sh --help
```

**Compositor** válido: `hypr` | `sway` | `niri` | `umbriel` (separados por coma, o `--todos` para los 4)

**Acciones:**
- `--deps` — instalar dependencias
- `--dotfiles` — instalar dotfiles
- `--ambos` — dependencias + dotfiles
- `--restaurar` — desinstalar dotfiles (restaura respaldos `.bak-*`)

## Qué hace

### 1. Dependencias (`--deps`)

Instala, según la distro detectada:

| Grupo | Arch | Debian |
|---|---|---|
| Comositor | hyprland / sway / niri(AUR) / umbriel(AUR) | hyprland / sway / niri(manual) / umbriel(manual) |
| Quickshell | `quickshell-git` (AUR) | `quickshell` (apt) |
| Base | dialog, firefox | dialog, firefox-esr |
| Fuentes | ttf-roboto, ttf-nerd-fonts-symbols | fonts-roboto + Nerd Font Symbols (GitHub) |
| Universales | brightnessctl, wl-clipboard, networkmanager, wlsunset, imagemagick, libnotify, wireplumber, curl, swaybg | ídem con nombres apt |
| Nerd Font | descarga universal | descarga universal |
| cliphist | AUR | binario manual desde GitHub |
| Capturas | grim, slurp | grim, slurp |
| Rust/cargo | `rust` | `cargo` |
| matugen | `matugen-bin` (AUR) | `cargo install matugen` |
| awww | AUR | `cargo install --git … awww` |
| xwayland-satellite | pacman (extra) — solo Umbriel | manual (cargo/binarios GitHub) — solo Umbriel |
| yay (helper AUR) | auto-instala si falta | — |
| SDDM | sddm + qt6-5compat si falta | sddm + qml6-module-qt5compat-graphicaleffects si falta |
| oh-my-bash | curl (instalador oficial) | curl (instalador oficial) |
| ble.sh | clona a `~/.local/share/blesh` | ídem |
| Complementarios | fuzzel, alacritty, thunar, playerctl, nm-applet | fuzzel, alacritty, thunar, playerctl, nm-gnome |

Los paquetes que no están en repos oficiales se resuelven con el helper AUR
(Arch) o con instrucciones/binarios manuales (Debian). El detalle completo está
en [`DEPENDENCIAS.md`](DEPENDENCIAS.md).

### 2. Dotfiles (`--dotfiles`)

Copia las configuraciones a `~/.config/` (respaldando lo existente con sufijo
`.bak-<timestamp>` antes de sobrescribir):

- **Compartidos:** `alacritty/`, `kitty/`, `fuzzel/`, `matugen/`
- **Shell:** `shell/bashrc` → `~/.bashrc` y `shell/zshrc` → `~/.zshrc` (+ oh-my-bash y ble.sh)
- **Wallpapers:** `Wallpapers/` → `~/Pictures/Wallpapers/`
- **Tema SDDM:** `sddm-theme/pixel/` → `/usr/share/sddm/themes/pixel/` + config `[Theme] Current=pixel`
- **Scripts:** `.local/bin/` → `~/.local/bin/` (sin modificar)
- **Hyprland:** `hypr/` → `~/.config/hypr/`
- **Sway:** `sway/` → `~/.config/sway/` + `environment.d/quickshell-sway.conf`
- **Niri:** `niri/` → `~/.config/niri/` (config modular en `config.d/`)
- **Umbriel:** `umbriel/` → `~/.config/umbriel/`

Y descomprime la variante de Quickshell correspondiente:

| Zip | Destino |
|---|---|
| `quickshell-hyprland-wallhaven.zip` | `~/.config/quickshell/` |
| `quickshell-sway-wallhaven.zip` | `~/.config/quickshell/sway/` |
| `quickshell-umbriel.zip` | `~/.config/quickshell/umbriel/` |

> **Nota Umbriel:** el shell (del zip) va a `~/.config/quickshell/umbriel/` y la
> config del compositor (config.toml + colors.toml + noctalia.toml) sale de la
> carpeta `umbriel/` del proyecto. El `config.toml` ya incluye
> `files = ["colors.toml"]`, por lo que `umbriel validate` no falla.

## Estructura del proyecto

```
proyecto/
├── install.sh                 # punto de entrada (menús + CLI)
├── lib/
│   ├── common.sh              # detección distro/AUR, logging, respaldo
│   ├── dependencies.sh        # definición e instalación de paquetes
│   └── dotfiles.sh            # copia de dotfiles, wallpapers y zips Quickshell
├── DEPENDENCIAS.md            # referencia detallada de dependencias
├── shell/
│   ├── bashrc                 # tu configuración de Bash
│   └── zshrc                  # tu configuración de Zsh
├── Wallpapers/                # se copian a ~/Pictures/Wallpapers
├── alacritty/  kitty/  fuzzel/  matugen/
├── hypr/  sway/  niri/  umbriel/
└── quickshell-*.zip           # 3 variantes del shell (hyprland/sway/umbriel)
```

> **Nota shell:** `shell/bashrc` y `shell/zshrc` son tus configuraciones actuales
> con las rutas hardcodeadas (`/home/william/...`) reemplazadas por `$HOME` para
> que sean portables. Al instalarse, respaldan el `~/.bashrc`/`~/.zshrc`
> existente. Además se instalan **oh-my-bash** (`~/.oh-my-bash`) y **ble.sh**
> (`~/.local/share/blesh`), que el `bashrc` ya carga.
>
> **Nota wallpapers:** se copian a `~/Pictures/Wallpapers/` y **no** se eliminan
> al ejecutar `--restaurar` (son archivos del usuario, no config del script).
>
> **Nota tema SDDM:** el tema se instala en `/usr/share/sddm/themes/pixel` (con
> `sudo`), se cambia el owner a `$USER` (para que los scripts `sync-*` escriban
> el fondo sin sudo) y se genera `/etc/sddm.conf.d/99-pixel-theme.conf` con
> `Current=pixel`. Los scripts `sync-pixel-sddm.py` y `sync-sway-sddm.sh` se
> copian a `~/.local/bin` **sin modificar** (son correctos tal cual).

## Prueba sin tocar tu sistema

Para verificar la lógica de copia sin tocar `~/.config`, puedes apuntar a un
directorio temporal:

```bash
XDG_CONFIG_HOME="$(mktemp -d)" ./install.sh --compositor sway --dotfiles
```

## Seguridad

- Nada se sobrescribe sin respaldo: los archivos existentes se mueven a
  `*.bak-<timestamp>`.
- `--restaurar` revierte a la copia de respaldo más reciente (incluye
  `~/.bashrc` y `~/.zshrc`); los wallpapers, el tema SDDM, los scripts de
  `~/.local/bin` y los frameworks de shell no se tocan.
- El helper AUR (`yay`) se instala automáticamente solo si no hay ni `paru` ni
  `yay` en el sistema (Arch).
- SDDM se instala solo si no está presente.
