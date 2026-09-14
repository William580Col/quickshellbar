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
| Universales | brightnessctl, wl-clipboard, networkmanager, wlsunset, imagemagick, libnotify, wireplumber, curl, swaybg | ídem con nombres apt |
| Nerd Font | descarga universal | descarga universal |
| cliphist | AUR | binario manual desde GitHub |
| Capturas | grim, slurp | grim, slurp |
| Rust/cargo | `rust` | `cargo` |
| matugen | `matugen-bin` (AUR) | `cargo install matugen` |
| awww | AUR | `cargo install --git … awww` |
| Complementarios | fuzzel, alacritty, thunar, playerctl, nm-applet | fuzzel, alacritty, thunar, playerctl, nm-gnome |

Los paquetes que no están en repos oficiales se resuelven con el helper AUR
(Arch) o con instrucciones/binarios manuales (Debian). El detalle completo está
en [`DEPENDENCIAS.md`](DEPENDENCIAS.md).

### 2. Dotfiles (`--dotfiles`)

Copia las configuraciones a `~/.config/` (respaldando lo existente con sufijo
`.bak-<timestamp>` antes de sobrescribir):

- **Compartidos:** `alacritty/`, `kitty/`, `fuzzel/`, `matugen/`
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
│   └── dotfiles.sh            # copia de dotfiles y zips Quickshell
├── DEPENDENCIAS.md            # referencia detallada de dependencias
├── alacritty/  kitty/  fuzzel/  matugen/
├── hypr/  sway/  niri/  umbriel/
└── quickshell-*.zip           # 3 variantes del shell (hyprland/sway/umbriel)
```

## Prueba sin tocar tu sistema

Para verificar la lógica de copia sin tocar `~/.config`, puedes apuntar a un
directorio temporal:

```bash
XDG_CONFIG_HOME="$(mktemp -d)" ./install.sh --compositor sway --dotfiles
```

## Seguridad

- Nada se sobrescribe sin respaldo: los archivos existentes se mueven a
  `*.bak-<timestamp>`.
- `--restaurar` revierte a la copia de respaldo más reciente; si no hay
  respaldo, elimina lo que este script instaló (asumiendo que era suyo).
- Las instalaciones con `sudo` (pacman/apt) y AUR son interactivas por diseño;
  revisa siempre el resumen antes de confirmar.
- Para restaurar manualmente: `mv ~/.config/<dir>.bak-<timestamp> ~/.config/<dir>`.
