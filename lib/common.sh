#!/usr/bin/env bash
# common.sh — utilidades compartidas del instalador de dotfiles.
# Se ejecuta con `source` desde install.sh (no directamente).

set -u

# ─────────────────────────────────────────────────────────────────────────────
# Colores y logging
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
else
  C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

info()  { printf '%s[*]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()   { printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*"; }
title() { printf '\n%s=== %s ===%s\n' "$C_MAGENTA" "$*" "$C_RESET"; }
step()  { printf '%s>> %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }

die() { err "$*"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Directorio raíz del proyecto (donde vive install.sh)
# ─────────────────────────────────────────────────────────────────────────────
if [[ -z "${PROJECT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  PROJECT_DIR="$SCRIPT_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Detección de distro
# ─────────────────────────────────────────────────────────────────────────────
# Devuelve: arch | debian | unknown
detect_distro() {
  if [[ -f /etc/arch-release ]] || grep -q '^ID=arch' /etc/os-release 2>/dev/null; then
    echo "arch"
    return
  fi
  # Derivadas de Arch (Manjaro, EndeavourOS, CachyOS, Garuda…)
  if grep -qiE '^ID_LIKE=.*arch' /etc/os-release 2>/dev/null; then
    echo "arch"
    return
  fi
  # Debian y derivadas (Ubuntu, Mint, Pop!_OS, etc.)
  if grep -qiE '^ID(_LIKE)?=.*(debian|ubuntu|linuxmint|pop)' /etc/os-release 2>/dev/null; then
    echo "debian"
    return
  fi
  echo "unknown"
}

# Distro legible para el usuario
distro_name() {
  case "$(detect_distro)" in
    arch)   echo "Arch Linux (o derivada)" ;;
    debian) echo "Debian/Ubuntu (o derivada)" ;;
    *)      echo "Desconocida" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Detección de herramientas
# ─────────────────────────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

# Helper AUR disponible: paru | yay | none
aur_helper() {
  if have paru; then echo "paru"
  elif have yay; then echo "yay"
  else echo "none"; fi
}

# Gestor de paquetes: pacman | apt | none
pkg_manager() {
  case "$(detect_distro)" in
    arch)   have pacman && echo "pacman" || echo "none" ;;
    debian) have apt && echo "apt" || echo "none" ;;
    *)      echo "none" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Respaldo de configs existentes
# ─────────────────────────────────────────────────────────────────────────────
# backup_target <ruta> — mueve la ruta a <ruta>.bak-<timestamp> si existe.
backup_target() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak-${stamp}"
    # Evita colisión si ya existe un .bak con el mismo segundo
    local n=1
    while [[ -e "$backup" ]]; do
      backup="${target}.bak-${stamp}-${n}"
      n=$((n + 1))
    done
    mv "$target" "$backup"
    warn "Respaldo: $target -> $backup"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Copia recursiva que preserva estructura y permisos
# ─────────────────────────────────────────────────────────────────────────────
# copy_dir <src> <dst> — asegura el directorio destino y copia el contenido.
copy_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  ok "Copiado $src -> $dst"
}

# copy_file <src> <dst>
copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  ok "Copiado $src -> $dst"
}

# ─────────────────────────────────────────────────────────────────────────────
# Confirmación por consola (fallback sin dialog)
# ─────────────────────────────────────────────────────────────────────────────
confirm() {
  local prompt="${1:-¿Continuar? [s/N] }"
  local ans
  read -r -p "$prompt" ans
  case "$ans" in
    [sS]|[sS][iI]|[yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}
