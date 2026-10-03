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
    err 'No se encontró unzip. Instálalo e inténtalo de nuevo.'
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
    # El zip trae una carpeta raíz. Buscamos la esperada ($src) y, si no
    # existe, usamos la primera carpeta de nivel superior (el nombre puede
    # variar, p. ej. quickshell-hyprland-wallhaven/ en vez de quickshell/).
    local root=""
    if [[ -d "$tmp/$src" ]]; then
      root="$tmp/$src"
    else
      root="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    fi
    if [[ -n "$root" && -d "$root" ]]; then
      backup_target "$dst"
      mkdir -p "$dst"
      cp -a "$root"/. "$dst"/
      # Asegurar permisos de ejecución de los scripts del shell
      find "$dst" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null
      ok "Quickshell ($comp) instalado en $dst"
    else
      err "El zip no contiene una carpeta raíz válida."
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
#   IMPORTANTE: se llama DESPUÉS de instalar_oh_my_bash(), porque el
#   instalador oficial de OMB escribe su propia plantilla en ~/.bashrc; el
#   ~/.bashrc del proyecto (con OSH_THEME="modern") gana siempre.
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

  # Tema modern personalizado del prompt (oh-my-bash).
  # Va en custom/ para no bloquear los updates del repo upstream: al resolver
  # un tema, OMB prueba primero $OSH_CUSTOM/themes/<tema> y después
  # $OSH/themes/<tema>, así que custom/ tiene prioridad. Aun así también
  # sobrescribimos el upstream de themes/ (respaldándolo en .bak la primera
  # vez) para que el prompt sea idéntico aunque OSH_CUSTOM apunte a otra ruta.
  if [[ -f "$PROJECT_DIR/shell/oh-my-bash-themes/modern.theme.sh" ]]; then
    if [[ -d "$HOME/.oh-my-bash" ]]; then
      _instalar_tema_modern "$HOME/.oh-my-bash/custom/themes/modern/modern.theme.sh"
      _instalar_tema_modern "$HOME/.oh-my-bash/themes/modern/modern.theme.sh"
      ok "Tema modern de oh-my-bash instalado"
    else
      warn "~/.oh-my-bash no existe; omitiendo tema modern."
    fi
  fi
}

# _instalar_tema_modern <destino> — copia shell/oh-my-bash-themes/modern.theme.sh
# a <destino> de forma idempotente: si el destino ya es idéntico no hace nada;
# si hay que sobrescribirlo, guarda el original en <destino>.bak una sola vez.
_instalar_tema_modern() {
  local src="$PROJECT_DIR/shell/oh-my-bash-themes/modern.theme.sh" dst="$1"
  mkdir -p "$(dirname "$dst")"
  cmp -s "$src" "$dst" 2>/dev/null && return 0
  if [[ -f "$dst" && ! -e "$dst.bak" ]]; then
    cp -a "$dst" "$dst.bak"
    warn "Respaldado tema original: $dst.bak"
  fi
  cp -a "$src" "$dst"
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

# instalar_oh_my_bash — instala oh-my-bash vía el instalador oficial (curl)
instalar_oh_my_bash() {
  local dst="$HOME/.oh-my-bash"
  if [[ -d "$dst" ]]; then
    info "oh-my-bash ya está instalado."
    return 0
  fi

  title "Oh My Bash"

  # Asegurar curl y git (el instalador oficial necesita curl; git para el
  # fallback). Si hay gestor de paquetes disponible, se instalan solos.
  if ! have curl || ! have git; then
    local d; d="$(detect_distro)"
    if have sudo && { have pacman || have apt; }; then
      info "Instalando curl/git (necesarios para oh-my-bash)..."
      if have pacman; then sudo pacman -S --needed --noconfirm curl git
      else sudo apt install -y curl git; fi
    fi
    have curl || have git || {
      err "Se necesita curl o git para instalar oh-my-bash. Omítelo e instálalo manualmente."
      return 1
    }
  fi

  local tmp; tmp="$(mktemp -d)"
  local installer="$tmp/install.sh"

  # 1) Instalador oficial vía curl. Ahora se descarga a un archivo real y se
  #    comprueba que llegó entero (antes, si curl fallaba, $(...) quedaba
  #    vacío y "bash -c ''" devolvía 0 sin instalar nada).
  if have curl && curl -fsSL \
      https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh \
      -o "$installer" && [[ -s "$installer" ]]; then
    step "Instalando oh-my-bash (instalador oficial, --unattended)..."
    bash "$installer" --unattended
  else
    # 2) Fallback: clonar directamente. El ~/.bashrc del proyecto ya hace
    #    source de $OSH/oh-my-bash.sh, así que el clone basta.
    warn "No se pudo descargar el instalador oficial; usando git clone."
    step "Clonando oh-my-bash (git clone)..."
    if have git; then
      git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git "$dst"
    else
      err "git tampoco está disponible; oh-my-bash no instalado."
      rm -rf "$tmp"
      return 1
    fi
  fi
  rm -rf "$tmp"

  if [[ -d "$dst" ]]; then
    ok "oh-my-bash instalado en $dst"
  else
    warn "Oh My Bash no quedó instalado en $dst. Revisa la conexión de red."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Colores del prompt bash: matugen -> ~/.config/aether/theme/colors.toml
# ─────────────────────────────────────────────────────────────────────────────
# La cadena en caliente es: quickshell (cambio de wallpaper) -> apply-colors.sh
# -> matugen image -> template aether-colors.toml -> colors.toml, que lee el
# tema modern de oh-my-bash en cada prompt.
#
# asegurar_templates_matugen — matugen 4.x aborta (y entonces no llega a
#   generar colors.toml) si algún input_path de su config no existe. Cada zip
#   de quickshell sólo trae los templates de su compositor, así que en una
#   instalación limpia de un solo compositor faltan los de los demás. Esta
#   función completa los que falten extrayéndolos de los zips versionados.
#   No fatal: si falta unzip o algún template, sólo avisa.
asegurar_templates_matugen() {
  local conf="$CONFIG_HOME/matugen/config.toml"
  [[ -f "$conf" ]] || return 0
  if ! have unzip; then
    warn "unzip no disponible; no puedo completar los templates de matugen."
    return 0
  fi

  local path base zip entry
  local -a inputs=()
  while IFS= read -r path; do
    inputs+=("$path")
  done < <(grep -o 'input_path[[:space:]]*=[[:space:]]*"[^"]*"' "$conf" |
           sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/')
  ((${#inputs[@]})) || return 0

  for path in "${inputs[@]}"; do
    path="${path/#\~/$HOME}"
    [[ -f "$path" ]] && continue
    base="$(basename "$path")"
    entry=""
    # 1) los templates que viajan en matugen/ (los instala copy_dir)
    if [[ -f "$PROJECT_DIR/matugen/templates/$base" ]]; then
      mkdir -p "$(dirname "$path")"
      cp -a "$PROJECT_DIR/matugen/templates/$base" "$path"
      ok "Template de matugen completado: $path"
      continue
    fi
    # 2) los de quickshell: cada zip sólo trae los de su compositor, así que
    #    en una instalación de un solo compositor faltan los de los demás.
    for zip in "$PROJECT_DIR"/quickshell-*.zip; do
      [[ -f "$zip" ]] || continue
      entry="$(unzip -Z1 "$zip" 2>/dev/null | grep "/matugen-templates/$base\$" | head -1)"
      [[ -n "$entry" ]] && break
    done
    if [[ -z "$entry" ]]; then
      warn "No encuentro el template $base en el proyecto ni en los zips ($path)."
      continue
    fi
    mkdir -p "$(dirname "$path")"
    if unzip -p "$zip" "$entry" >"$path" 2>/dev/null && [[ -s "$path" ]]; then
      ok "Template de matugen completado: $path"
    else
      rm -f "$path"
      warn "No pude extraer $base de $(basename "$zip")."
    fi
  done
  return 0
}

# generar_colores_prompt — genera ~/.config/aether/theme/colors.toml una sola
#   vez al instalar, para que el primer prompt ya salga con los colores del
#   wallpaper en vez de la paleta por defecto del tema. No fatal: si no hay
#   matugen, wallpaper o la generación falla, sólo avisa y el tema usa su
#   paleta hardcodeada.
generar_colores_prompt() {
  local conf="$CONFIG_HOME/matugen/config.toml"
  local out="$HOME/.config/aether/theme/colors.toml"

  if [[ -f "$out" ]]; then
    info "Colores del prompt ya generados: $out"
    return 0
  fi
  if ! have matugen; then
    info "matugen no disponible; el prompt usará su paleta por defecto."
    return 0
  fi
  if [[ ! -f "$conf" ]]; then
    warn "No existe $conf; no puedo generar los colores del prompt."
    return 0
  fi

  local dir="$HOME/Pictures/Wallpapers" wp
  wp="$(find "$dir" -maxdepth 1 -type f -name 'image.*' -print -quit 2>/dev/null)"
  [[ -n "$wp" ]] || wp="$(find "$dir" -maxdepth 1 -type f -print -quit 2>/dev/null)"
  if [[ -z "$wp" ]]; then
    warn "No hay wallpapers en $dir; colores del prompt no generados."
    return 0
  fi

  title "Colores del prompt (matugen)"
  step "Generando $(basename "$out") desde $(basename "$wp")"
  if ! matugen image "$wp" -m dark; then
    warn "matugen falló con la config completa ($conf)."
  fi

  if [[ ! -s "$out" ]]; then
    # Sigue sin colors.toml (config completa incompleta): reintento con una
    # config mínima que sólo dibuja el prompt.
    local tmp; tmp="$(mktemp)"
    {
      printf '[config]\nprefix = "_"\nprefer = "saturation"\n\n'
      printf '[templates.bash_prompt]\n'
      printf 'input_path = "%s"\n' "$CONFIG_HOME/matugen/templates/aether-colors.toml"
      printf 'output_path = "%s"\n' "$out"
    } >"$tmp"
    step "Reintento sólo con el template del prompt"
    if ! matugen -c "$tmp" image "$wp" -m dark; then
      warn "No se pudieron generar los colores del prompt; el tema usará su paleta por defecto."
    fi
    rm -f "$tmp"
  fi

  if [[ -s "$out" ]]; then
    ok "Colores del prompt en $out"
  else
    warn "No se generó $out; el prompt usará su paleta por defecto."
  fi
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Tema SDDM (pixel)
# ─────────────────────────────────────────────────────────────────────────────
# instalar_tema_sddm — copia el tema a /usr/share/sddm/themes/pixel, genera el
#   fichero de configuración de SDDM y ajusta permisos (owner: $USER) para que
#   los scripts sync-* puedan escribir el fondo sin sudo.
instalar_tema_sddm() {
  local src="$PROJECT_DIR/sddm-theme/pixel"
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

  # assets/ para el fondo (los scripts sync-* escriben aquí background.png)
  sudo mkdir -p "$dst/assets"
  if [[ -f "$PROJECT_DIR/Wallpapers/default.png" ]]; then
    sudo cp -a "$PROJECT_DIR/Wallpapers/default.png" "$dst/assets/background.png"
  fi

  # Cambiar owner a $USER AL FINAL (tras crear assets/ y el fondo), para que
  # el usuario normal pueda escribir en todo el tema sin sudo.
  step "Cambiando permisos (owner: $USER)"
  sudo chown -R "$USER:$USER" "$dst"

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

  # Wallpapers y shell config (bashrc/zshrc) + frameworks de shell.
  # El orden importa: el instalador oficial de OMB escribe su plantilla en
  # ~/.bashrc, por eso instalar_oh_my_bash va ANTES de copiar_shell_config,
  # que instala el ~/.bashrc del proyecto (OSH_THEME="modern") encima.
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

  # Colores del prompt: completar templates de matugen (los zips traen sólo
  # los de su compositor) y generar colors.toml antes del primer arranque.
  asegurar_templates_matugen
  generar_colores_prompt

  # Autoconfiguración de resolución/salida de monitor según el hardware real
  # de cada PC (no fatal: si falla, los compositores usan su autoconfig).
  local autoconf="$PROJECT_DIR/.local/bin/autoconf-monitor.sh"
  if [[ -x "$autoconf" ]]; then
    step "Autoconfigurando resolución/salida de monitor"
    if ! "$autoconf" "${compositores[@]}"; then
      warn "autoconf-monitor.sh devolvió error; continúo sin reescribir el bloque de monitor."
    fi
  else
    warn "No encontré $autoconf; omito la autoconfig de monitores."
  fi

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
