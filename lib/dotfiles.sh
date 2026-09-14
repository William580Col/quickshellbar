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
# Frameworks de shell: ble.sh (bash line editor) y oh-my-bash
# ─────────────────────────────────────────────────────────────────────────────
# instalar_ble_sh — clona y compila ble.sh en ~/.local/share/blesh
instalar_ble_sh() {
  local dst="$HOME/.local/share/blesh"
  if [[ -f "$dst/ble.sh" ]]; then
    info "ble.sh ya está instalado."
    return 0
  fi
  if ! have git; then
    warn "git no disponible; omitiendo ble.sh."
    return 0
  fi

  title "ble.sh (bash line editor)"
  step "Clonando y compilando ble.sh..."
  local tmp; tmp="$(mktemp -d)"
  git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$tmp/ble.sh"
  make -C "$tmp/ble.sh" >/dev/null
  make -C "$tmp/ble.sh" install PREFIX="$HOME/.local" >/dev/null
  rm -rf "$tmp"
  ok "ble.sh instalado en $dst"
}

# instalar_oh_my_bash — clona oh-my-bash en ~/.oh-my-bash
instalar_oh_my_bash() {
  local dst="$HOME/.oh-my-bash"
  if [[ -d "$dst" ]]; then
    info "oh-my-bash ya está instalado."
    return 0
  fi
  if ! have git; then
    warn "git no disponible; omitiendo oh-my-bash."
    return 0
  fi

  title "Oh My Bash"
  step "Clonando oh-my-bash..."
  git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git "$dst"
  ok "oh-my-bash instalado en $dst"
}

# ─────────────────────────────────────────────────────────────────────────────
# Tema SDDM (pixel)
# ─────────────────────────────────────────────────────────────────────────────
# instalar_tema_sddm — copia el tema a /usr/share/sddm/themes/pixel, genera el
#   fichero de configuración de SDDM y ajusta permisos (owner: $USER) para que
#   los scripts sync-* puedan escribir el fondo sin sudo.
instalar_tema_sddm() {
  local src="$PROJECT_DIR/sddm theme/pixel"
  local themes_dir="/usr/share/sddm/themes"
  local dst="$themes_dir/pixel"
  local conf="/etc/sddm.conf.d/99-pixel-theme.conf"

  [[ -d "$src" ]] || { warn "No existe el tema SDDM en $src"; return 0; }
  if ! have sddm; then
    info "SDDM no está instalado; omitiendo tema (instálalo con --deps o --ambos)."
    return 0
  fi

  title "Tema SDDM (pixel)"

  # Respaldar tema previo si existe
  if [[ -d "$dst" ]]; then
    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$dst.bak-$stamp"
    sudo mv "$dst" "$backup"
    warn "Respaldo: $dst -> $backup"
  fi

  step "Copiando tema a $dst"
  sudo mkdir -p "$themes_dir"
  sudo cp -a "$src" "$dst"

  step "Cambiando permisos (owner: $USER)"
  sudo chown -R "$USER:$USER" "$dst"

  # assets/ para el fondo (los scripts sync-* escriben aquí background.png)
  sudo mkdir -p "$dst/assets"
  if [[ -f "$PROJECT_DIR/Wallpapers/default.png" ]]; then
    sudo cp -a "$PROJECT_DIR/Wallpapers/default.png" "$dst/assets/background.png"
  fi

  step "Generando configuración de SDDM ($conf)"
  sudo mkdir -p /etc/sddm.conf.d
  sudo tee "$conf" >/dev/null <<'EOF'
[Theme]
Current=pixel
EOF

  ok "Tema SDDM 'pixel' instalado y configurado."
}

# ─────────────────────────────────────────────────────────────────────────────
# Scripts del usuario (~/.local/bin)
# ─────────────────────────────────────────────────────────────────────────────
# copiar_scripts_local_bin — copia .local/bin/* a ~/.local/bin sin modificarlos.
copiar_scripts_local_bin() {
  local src="$PROJECT_DIR/.local/bin"
  local dst="$HOME/.local/bin"

  [[ -d "$src" ]] || { warn "No existe $src (no hay scripts que copiar)."; return 0; }
  if [[ -z "$(ls -A "$src" 2>/dev/null)" ]]; then
    info "$src está vacío; omitiendo scripts."
    return 0
  fi

  title "Scripts (~/.local/bin)"
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  # No modificar contenido; solo asegurar permisos de ejecución
  find "$dst" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} \;
  ok "Scripts copiados a $dst"
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

  # Wallpapers y shell config (bashrc/zshrc) + frameworks de shell
  copiar_wallpapers
  instalar_ble_sh
  instalar_oh_my_bash
  copiar_shell_config

  # Tema SDDM y scripts del usuario
  instalar_tema_sddm
  copiar_scripts_local_bin

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
