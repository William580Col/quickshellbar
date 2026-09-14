#!/usr/bin/env bash
# dotfiles.sh — copia de dotfiles y descompresión de los zips de Quickshell.
# Se ejecuta con `source` desde install.sh.

set -u

# ─────────────────────────────────────────────────────────────────────────────
# Rutas base
# ─────────────────────────────────────────────────────────────────────────────
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# ─────────────────────────────────────────────────────────────────────────────
# Copia de dotfiles compartidos (terminales, launcher, theming)
# ─────────────────────────────────────────────────────────────────────────────
instalar_dotfiles_compartidos() {
  title "Dotfiles compartidos"

  copy_dir "$PROJECT_DIR/alacritty" "$CONFIG_HOME/alacritty"
  copy_dir "$PROJECT_DIR/kitty"    "$CONFIG_HOME/kitty"
  copy_dir "$PROJECT_DIR/fuzzel"   "$CONFIG_HOME/fuzzel"
  copy_dir "$PROJECT_DIR/matugen"  "$CONFIG_HOME/matugen"

  ok "Dotfiles compartidos instalados."
}

# ─────────────────────────────────────────────────────────────────────────────
# Copia de dotfiles específicos de un compositor
# ─────────────────────────────────────────────────────────────────────────────
# instalar_dotfiles_compositor <hypr|sway|niri|umbriel>
instalar_dotfiles_compositor() {
  local comp="$1"
  title "Dotfiles de $comp"

  case "$comp" in
    hypr)
      copy_dir "$PROJECT_DIR/hypr" "$CONFIG_HOME/hypr"
      ;;
    sway)
      copy_dir "$PROJECT_DIR/sway" "$CONFIG_HOME/sway"
      # environment.d va a ~/.config/environment.d, no dentro de sway/
      copy_file "$PROJECT_DIR/sway/environment.d/quickshell-sway.conf" \
        "$CONFIG_HOME/environment.d/quickshell-sway.conf"
      ;;
    niri)
      copy_dir "$PROJECT_DIR/niri" "$CONFIG_HOME/niri"
      ;;
    umbriel)
      copy_dir "$PROJECT_DIR/umbriel" "$CONFIG_HOME/umbriel"
      ;;
    *)
      err "Compositor desconocido: $comp"
      return 1
      ;;
  esac

  ok "Dotfiles de $comp instalados."
}

# ─────────────────────────────────────────────────────────────────────────────
# Extracción de los zips de Quickshell
# ─────────────────────────────────────────────────────────────────────────────
# Cada zip trae una variante del shell para un compositor distinto.
#   quickshell-hyprland-wallhaven.zip -> ~/.config/quickshell/
#   quickshell-sway-wallhaven.zip      -> ~/.config/quickshell/sway/
#   quickshell-umbriel.zip             -> ~/.config/quickshell/umbriel/
#
# Hyprland usa la raíz (~/.config/quickshell); sway y umbriel usan subcarpetas.
# ─────────────────────────────────────────────────────────────────────────────
instalar_quickshell() {
  local comp="$1"
  title "Quickshell ($comp)"

  if ! have unzip; then
    err "No se encontró `unzip`. Instálalo e inténtalo de nuevo."
    return 1
  fi

  local zip src dst
  case "$comp" in
    hypr)
      zip="$PROJECT_DIR/quickshell-hyprland-wallhaven.zip"
      src="quickshell"
      dst="$CONFIG_HOME/quickshell"
      ;;
    sway)
      zip="$PROJECT_DIR/quickshell-sway-wallhaven.zip"
      src="sway"
      dst="$CONFIG_HOME/quickshell/sway"
      ;;
    umbriel)
      zip="$PROJECT_DIR/quickshell-umbriel.zip"
      src="umbriel"
      dst="$CONFIG_HOME/quickshell/umbriel"
      ;;
    *)
      # Niri usa su propio shell (iNiR), que no vive en estos zips.
      info "Niri no tiene variante de Quickshell en este proyecto (usa iNiR). Omitiendo."
      return 0
      ;;
  esac

  [[ -f "$zip" ]] || { err "No existe $zip"; return 1; }

  mkdir -p "$(dirname "$dst")"
  local tmp; tmp="$(mktemp -d)"
  step "Descomprimiendo $zip"
  if unzip -o -q "$zip" -d "$tmp"; then
    # El zip trae una carpeta raíz (quickshell/, sway/ o umbriel/)
    if [[ -d "$tmp/$src" ]]; then
      backup_target "$dst"
      mkdir -p "$dst"
      cp -a "$tmp/$src"/. "$dst"/
      # Asegurar permisos de ejecución de los scripts del shell
      find "$dst" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null
      ok "Quickshell ($comp) instalado en $dst"
    else
      err "El zip no contiene la carpeta esperada '$src'."
    fi
  else
    err "Falló la descompresión de $zip."
  fi
  rm -rf "$tmp"
}

# ─────────────────────────────────────────────────────────────────────────────
# Rutas gestionadas por compositor y compartidas
#   (se usan tanto para respaldar como para restaurar/desinstalar)
# ─────────────────────────────────────────────────────────────────────────────# paths_compositor <hypr|sway|niri|umbriel>  — imprime una ruta por línea
paths_compositor() {
  local comp="$1"
  case "$comp" in
    hypr)    echo "$CONFIG_HOME/hypr"; echo "$CONFIG_HOME/quickshell" ;;
    sway)    echo "$CONFIG_HOME/sway"; echo "$CONFIG_HOME/quickshell/sway"
             echo "$CONFIG_HOME/environment.d/quickshell-sway.conf" ;;
    niri)    echo "$CONFIG_HOME/niri" ;;
    umbriel) echo "$CONFIG_HOME/umbriel"; echo "$CONFIG_HOME/quickshell/umbriel" ;;
  esac
}

# paths_compartidos — imprime una ruta por línea
paths_compartidos() {
  echo "$CONFIG_HOME/alacritty"
  echo "$CONFIG_HOME/kitty"
  echo "$CONFIG_HOME/fuzzel"
  echo "$CONFIG_HOME/matugen"
}
# respaldar_compositor <comp> — respalda solo las rutas del compositor
respaldar_compositor() {
  local comp="$1" p
  while read -r p; do backup_target "$p"; done < <(paths_compositor "$comp")
}

# respaldar_compartidos — respalda las rutas compartidas
respaldar_compartidos() {
  local p
  while read -r p; do backup_target "$p"; done < <(paths_compartidos)
}

# ─────────────────────────────────────────────────────────────────────────────
# Wallpapers
# ─────────────────────────────────────────────────────────────────────────────
# copiar_wallpapers — copia ./Wallpapers -> ~/Pictures/Wallpapers
copiar_wallpapers() {
  local src="$PROJECT_DIR/Wallpapers"
  local dst="$HOME/Pictures/Wallpapers"

  [[ -d "$src" ]] || { warn "No existe $src (no hay wallpapers que copiar)."; return 0; }
  if [[ -z "$(ls -A "$src" 2>/dev/null)" ]]; then
    info "$src está vacía; omitiendo wallpapers."
    return 0
  fi

  title "Wallpapers"
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  ok "Wallpapers copiados a $dst"
}

# ─────────────────────────────────────────────────────────────────────────────
# Shell config (bashrc / zshrc)
# ─────────────────────────────────────────────────────────────────────────────
# copiar_shell_config — copia shell/bashrc y shell/zshrc a ~/.
#   No sobrescribe a ciegas: respalda el existente y avisa.
copiar_shell_config() {
  title "Shell config (bashrc / zshrc)"

  if [[ -f "$PROJECT_DIR/shell/bashrc" ]]; then
    backup_target "$HOME/.bashrc"
    cp -a "$PROJECT_DIR/shell/bashrc" "$HOME/.bashrc"
    ok "Instalado ~/.bashrc"
  else
    warn "No existe shell/bashrc en el proyecto."
  fi

  if [[ -f "$PROJECT_DIR/shell/zshrc" ]]; then
    backup_target "$HOME/.zshrc"
    cp -a "$PROJECT_DIR/shell/zshrc" "$HOME/.zshrc"
    ok "Instalado ~/.zshrc"
  else
    warn "No existe shell/zshrc en el proyecto."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Flujo completo de dotfiles para uno o varios compositores
# ─────────────────────────────────────────────────────────────────────────────
# instalar_dotfiles <comp> [<comp> ...]
instalar_dotfiles() {
  local compositores=("$@")
  [[ ${#compositores[@]} -eq 0 ]] && { err "Falta el compositor."; return 1; }

  # Respaldar configs existentes antes de tocar nada (compartidos una sola vez)
  title "Respaldo de configuraciones existentes"
  respaldar_compartidos
  local comp
  for comp in "${compositores[@]}"; do
    respaldar_compositor "$comp"
  done

  # Instalar compartidos una sola vez
  instalar_dotfiles_compartidos

  # Wallpapers y shell config (bashrc/zshrc)
  copiar_wallpapers
  copiar_shell_config

  # Instalar cada compositor
  for comp in "${compositores[@]}"; do
    instalar_dotfiles_compositor "$comp"
    instalar_quickshell "$comp"
  done

  ok "Dotfiles completos para: ${compositores[*]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Desinstalar / restaurar dotfiles
# ─────────────────────────────────────────────────────────────────────────────
# restaurar_target <ruta> — revierte a la copia de respaldo más reciente; si no
# hay respaldo, elimina lo instalado (asume que era lo que este script copió).
restaurar_target() {
  local target="$1" latest
  latest="$(ls -1dt "${target}".bak-* 2>/dev/null | head -1)"
  if [[ -n "$latest" ]]; then
    # Quitar lo instalado actualmente y restaurar el respaldo
    if [[ -e "$target" || -L "$target" ]]; then
      rm -rf "$target"
    fi
    mv "$latest" "$target"
    ok "Restaurado $target desde $(basename "$latest")"
  else
    # Sin respaldo previo: eliminar lo que este script instaló
    if [[ -e "$target" || -L "$target" ]]; then
      rm -rf "$target"
      ok "Eliminado $target (no había respaldo previo)"
    else
      info "$target no existe; nada que hacer."
    fi
  fi
}

# restaurar_dotfiles <comp> [<comp> ...] — desinstala dotfiles (compartidos + compositores)
restaurar_dotfiles() {
  local compositores=("$@")
  [[ ${#compositores[@]} -eq 0 ]] && { err "Falta el compositor."; return 1; }

  title "Desinstalar / restaurar dotfiles"

  local p comp
  # Compartidos
  while read -r p; do restaurar_target "$p"; done < <(paths_compartidos)
  # Shell config
  restaurar_target "$HOME/.bashrc"
  restaurar_target "$HOME/.zshrc"
  # Por compositor
  for comp in "${compositores[@]}"; do
    while read -r p; do restaurar_target "$p"; done < <(paths_compositor "$comp")
  done

  info "Los wallpapers en ~/Pictures/Wallpapers no se eliminan (son archivos del usuario)."

  ok "Dotfiles desinstalados/restaurados para: ${compositores[*]}"
}
