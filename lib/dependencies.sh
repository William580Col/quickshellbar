#!/usr/bin/env bash
# dependencies.sh — definición e instalación de dependencias por distro.
# Se ejecuta con `source` desde install.sh.

set -u

# Paquetes adicionales seleccionados (ver install.sh → menu_paquetes).
# "all" instala todos; si no, lista de grupos separada por comas.
PAQUETES="${PAQUETES:-all}"

# paquete_activo <grupo> — ¿está seleccionado el grupo?
paquete_activo() {
  local g="$1"
  [[ "$PAQUETES" == "all" || ",${PAQUETES}," == *",${g},"* ]] && return 0 || return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Definición de paquetes por distro
#
# Cada función `pkgs_<grupo>` imprime los paquetes (uno por línea o en lista
# separada por espacios) para la distro detectada.
# ─────────────────────────────────────────────────────────────────────────────

# --- Compositores (sección 9/10/11 del README) --------------------------------
pkgs_compositor() {
  local comp="$1" d
  d="$(detect_distro)"
  case "$comp" in
    hypr)
      if [[ "$d" == "arch" ]]; then echo "hyprland hyprpaper xdg-desktop-portal-hyprland"
      else echo "hyprland hyprpaper xdg-desktop-portal-hyprland"; fi
      ;;
    sway)
      echo "sway swayidle swaylock"
      ;;
    niri)
      if [[ "$d" == "arch" ]]; then echo "__AUR__ niri"
      else echo "__MANUAL__ niri (ver README: revisa apt search niri o releases de GitHub)"; fi
      ;;
    umbriel)
      if [[ "$d" == "arch" ]]; then echo "xwayland-satellite __AUR__ umbriel-git"
      else echo "__MANUAL__ umbriel + xwayland-satellite (ver docs.noctalia.dev; xwayland-satellite vía cargo o binarios GitHub)"; fi
      ;;
  esac
}

# --- Quickshell (el shell en sí) ----------------------------------------------
pkgs_quickshell() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "__AUR__ quickshell-git"
  else echo "quickshell"; fi
}

# --- Dependencias universales (las 3 variantes las necesitan) -----------------
pkgs_universal() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then
    echo "brightnessctl wl-clipboard networkmanager wlsunset imagemagick libnotify wireplumber curl swaybg"
  else
    echo "brightnessctl wl-clipboard network-manager wlsunset imagemagick libnotify-bin wireplumber curl swaybg"
  fi
}

# --- Portapapeles con historial (cliphist) ------------------------------------
pkgs_cliphist() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "__AUR__ cliphist"
  else echo "__MANUAL__ cliphist (binario desde GitHub)"; fi
}

# --- Capturas de pantalla (grim + slurp) --------------------------------------
pkgs_grim() {
  echo "grim slurp"
}

# --- Rust/cargo -----------------------------------------------------------------
pkgs_rust() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "rust"
  else echo "cargo"; fi
}

# --- Complementarios (sección 12, opcionales) ----------------------------------
pkgs_optional() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then
    echo "fuzzel alacritty thunar playerctl network-manager-applet"
  else
    echo "fuzzel alacritty thunar playerctl network-manager-gnome"
  fi
}

# --- Herramientas base (dialog para el instalador, firefox para los binds) -----
pkgs_base() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "dialog firefox"
  else echo "dialog firefox-esr"; fi
}

# --- Fuentes (Roboto + símbolos Nerd Font que pide la barra de Quickshell) -----
pkgs_fonts() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "ttf-roboto ttf-nerd-fonts-symbols"
  else echo "fonts-roboto"; fi
}

# --- SDDM (gestor de sesiones) ------------------------------------------------
pkgs_sddm() {
  local d; d="$(detect_distro)"
  # El tema 'pixel' usa Qt5Compat.GraphicalEffects, que requiere qt6-5compat.
  if [[ "$d" == "arch" ]]; then echo "sddm qt6-5compat"
  else echo "sddm qml6-module-qt5compat-graphicaleffects"; fi
}

# --- Herramientas de compresión ------------------------------------------------
pkgs_compresion() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then echo "unzip 7zip unrar"
  else echo "unzip 7zip unrar-free"; fi
}

# --- Thunar (gestor de archivos) y dependencias completas ---------------------
pkgs_thunar() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then
    echo "thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin tumbler ffmpegthumbnailer gvfs gvfs-mtp gvfs-smb file-roller"
  else
    echo "thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer gvfs gvfs-backends gvfs-fuse file-roller"
  fi
}

# --- Aplicaciones adicionales --------------------------------------------------
pkgs_aplicaciones() {
  local d; d="$(detect_distro)"
  if [[ "$d" == "arch" ]]; then
    echo "firefox evince peazip geany gnome-calculator flatpak mpv papirus-icon-theme adw-gtk-theme nwg-look qt5ct qt6ct __AUR__ onlyoffice-bin __AUR__ darkly-bin __AUR__ tela-icon-theme __AUR__ pacseek-bin"
  else
    echo "firefox-esr evince geany gnome-calculator flatpak mpv papirus-icon-theme qt5ct qt6ct __MANUAL__ Peazip (https://peazip.github.io/), Tela icon (github.com/vinceliuice/Tela-icon-theme), adw-gtk3 (gitlab.com/julianfairfax/package-repo), nwg-look (compilar desde source), OnlyOffice (flatpak: flatpak install flathub org.onlyoffice.desktopeditors), Darkly (github.com/Bali10050/Darkly)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Instaladores primitivos
# ─────────────────────────────────────────────────────────────────────────────

# instalar_pacman <pkgs...>  — usa sudo pacman -S --needed
instalar_pacman() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "pacman: ${pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

# instalar_aur <pkgs...> — usa paru o yay
instalar_aur() {
  local pkgs=("$@") helper
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  helper="$(aur_helper)"
  if [[ "$helper" == "none" ]]; then
    err "No se encontró paru ni yay. Instala un helper AUR primero."
    warn "Paquetes AUR pendientes: ${pkgs[*]}"
    return 1
  fi
  step "AUR ($helper): ${pkgs[*]}"
  "$helper" -S --needed --noconfirm "${pkgs[@]}"
}

# instalar_yay_si_falta — instala yay desde AUR si no hay ningún helper
instalar_yay_si_falta() {
  local d; d="$(detect_distro)"
  [[ "$d" == "arch" ]] || return 0   # solo aplica a Arch
  local helper; helper="$(aur_helper)"
  [[ "$helper" != "none" ]] && { info "Helper AUR ya disponible: $helper"; return 0; }

  title "Instalando yay (helper AUR)"
  step "No se encontró paru ni yay. Instalando yay desde AUR..."
  if ! have git; then
    sudo pacman -S --needed --noconfirm git
  fi
  sudo pacman -S --needed --noconfirm base-devel

  local tmp; tmp="$(mktemp -d)"
  (
    cd "$tmp" || exit 1
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit 1
    makepkg -si --noconfirm
  )
  rm -rf "$tmp"

  if have yay; then
    ok "yay instalado correctamente."
  else
    err "No se pudo instalar yay. Deberás instalarlo manualmente."
  fi
}

# instalar_apt <pkgs...>
instalar_apt() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "apt: ${pkgs[*]}"
  sudo apt-get install -y "${pkgs[@]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Instalación "manual" (no empaquetada en la distro)
# ─────────────────────────────────────────────────────────────────────────────

# Nerd Font (universal, vía curl) — sección 8
instalar_nerd_font() {
  title "Nerd Font (JetBrainsMono)"
  step "Descargando e instalando en ~/.local/share/fonts"
  mkdir -p "$HOME/.local/share/fonts"
  local tmp; tmp="$(mktemp -d)"
  curl -fL -o "$tmp/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
    && unzip -o "$tmp/JetBrainsMono.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerd" >/dev/null \
    && fc-cache -fv >/dev/null 2>&1 \
    && ok "Nerd Font instalada" \
    || { err "Falló la instalación de la Nerd Font"; }
  rm -rf "$tmp"
}

# Símbolos Nerd Font para Debian (no están en apt) — los pide la barra de Quickshell
instalar_nerd_symbols_debian() {
  title "Nerd Font Symbols (Debian, vía GitHub)"
  step "Descargando NerdFontsSymbolsOnly..."
  mkdir -p "$HOME/.local/share/fonts"
  local tmp; tmp="$(mktemp -d)"
  if curl -fL -o "$tmp/Symbols.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip; then
    unzip -o "$tmp/Symbols.zip" -d "$HOME/.local/share/fonts/NerdFontsSymbolsOnly" >/dev/null
    fc-cache -fv >/dev/null 2>&1
    ok "Nerd Font Symbols instalados."
  else
    err "No se pudieron descargar los Nerd Font Symbols."
  fi
  rm -rf "$tmp"
}

# cliphist para Debian (binario manual) — sección 3
instalar_cliphist_debian() {
  title "cliphist (binario manual para Debian)"
  local tmp; tmp="$(mktemp -d)"
  step "Descargando cliphist desde GitHub"
  if curl -fL -o "$tmp/cliphist.tar.gz" \
    https://github.com/sentriz/cliphist/releases/latest/download/cliphist_linux_amd64.tar.gz; then
    tar -xzf "$tmp/cliphist.tar.gz" -C "$tmp"
    sudo install -m755 "$tmp/cliphist" /usr/local/bin/cliphist
    ok "cliphist instalado en /usr/local/bin"
  else
    err "No se pudo descargar cliphist."
  fi
  rm -rf "$tmp"
}

# matugen (cargo install) — sección 6
instalar_matugen_cargo() {
  title "matugen (vía cargo)"
  if ! have cargo; then
    err "cargo no está instalado. Ejecuta primero la instalación de Rust/cargo."
    return 1
  fi
  step "cargo install matugen (puede tardar)"
  cargo install matugen
  ok "matugen instalado (recuerda agregar ~/.cargo/bin a tu PATH)"
}

# awww para Debian (cargo install --git) — sección 7
instalar_awww_debian() {
  title "awww (vía cargo, no está en apt)"
  if ! have cargo; then
    err "cargo no está instalado."
    return 1
  fi
  step "cargo install --git https://codeberg.org/LGFae/awww awww"
  cargo install --git https://codeberg.org/LGFae/awww awww
  ok "awww instalado"
}

# --- OpenCode (AI coding agent) — se instala vía su script oficial ------------
instalar_opencode() {
  if have opencode; then
    info "opencode ya está instalado."
    return 0
  fi

  title "OpenCode (AI coding agent)"
  if ! have curl; then
    warn "curl no disponible; omitiendo opencode."
    return 0
  fi

  step "Instalando opencode vía script oficial..."
  curl -fsSL https://opencode.ai/install | bash
  if have opencode; then
    ok "opencode instalado correctamente."
  else
    warn "El script de opencode terminó; verifica la instalación."
  fi
}

# --- Configuración automática de tema oscuro (GTK + Qt) -----------------------
# Configura adw-gtk3-dark, Tela-dark, color-scheme prefer-dark, qt5ct/qt6ct con
# paleta oscura y variables de entorno (environment.d). Respalda archivos existentes.
configurar_tema_oscuro() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  local gtk_theme="adw-gtk3-dark"
  local icon_theme="Tela-dark"
  local qt_palette
  qt_palette="$(mktemp)"

  title "Tema oscuro automático (GTK + Qt)"

  # --- Paleta oscura para qt5ct/qt6ct (basada en Breeze Dark) ----------------
  cat > "$qt_palette" <<'PALETTE'
[ColorScheme]
active_highlight=49,140,231
active_highlight_text=255,255,255
active_text=252,252,252
active_window=49,54,59
active_window_text=239,240,241
active_base=35,38,41
active_base_text=239,240,241
active_button=49,54,59
active_button_text=239,240,241
active_tooltip=247,247,247
active_tooltip_text=49,54,59
active_link=29,153,243
active_visited=155,89,182
inactive_highlight=49,140,231
inactive_highlight_text=255,255,255
inactive_text=239,240,241
inactive_window=49,54,59
inactive_window_text=239,240,241
inactive_base=35,38,41
inactive_base_text=239,240,241
inactive_button=49,54,59
inactive_button_text=239,240,241
inactive_tooltip=247,247,247
inactive_tooltip_text=49,54,59
inactive_link=29,153,243
inactive_visited=155,89,182
disabled_text=127,130,137
disabled_window_text=127,130,137
disabled_base_text=127,130,137
disabled_button=49,54,59
disabled_button_text=127,130,137
disabled_tooltip=247,247,247
disabled_tooltip_text=127,130,137
disabled_highlight=100,100,100
disabled_highlight_text=127,130,137
disabled_link=29,153,243
disabled_visited=155,89,182
PALETTE

  # --- Qt5: qt5ct -----------------------------------------------------------
  mkdir -p "$cfg/qt5ct/colors"
  backup_target "$cfg/qt5ct/qt5ct.conf"
  cp "$qt_palette" "$cfg/qt5ct/colors/dark.conf"
  cat > "$cfg/qt5ct/qt5ct.conf" <<QT5CT
[Appearance]
custom_palette=true
color_scheme_path=$cfg/qt5ct/colors/dark.conf
icon_theme=$icon_theme
style=Fusion
standard_dialogs=default
ui_style=default
QT5CT
  ok "qt5ct configurado (tema oscuro, paleta Breeze Dark)"

  # --- Qt6: qt6ct -----------------------------------------------------------
  mkdir -p "$cfg/qt6ct/colors"
  backup_target "$cfg/qt6ct/qt6ct.conf"
  cp "$qt_palette" "$cfg/qt6ct/colors/dark.conf"
  cat > "$cfg/qt6ct/qt6ct.conf" <<QT6CT
[Appearance]
custom_palette=true
color_scheme_path=$cfg/qt6ct/colors/dark.conf
icon_theme=$icon_theme
style=Fusion
standard_dialogs=default
QT6CT
  ok "qt6ct configurado (tema oscuro, paleta Breeze Dark)"
  rm -f "$qt_palette"

  # --- environment.d: variables de entorno para Qt y GTK --------------------
  mkdir -p "$cfg/environment.d"
  backup_target "$cfg/environment.d/theme.conf"
  cat > "$cfg/environment.d/theme.conf" <<ENVEOF
QT_QPA_PLATFORMTHEME=qt5ct
GTK_THEME=$gtk_theme
ENVEOF
  ok "environment.d/theme.conf escrito (QT_QPA_PLATFORMTHEME, GTK_THEME)"

  # --- GTK 3.0 settings.ini ------------------------------------------------
  mkdir -p "$cfg/gtk-3.0"
  backup_target "$cfg/gtk-3.0/settings.ini"
  cat > "$cfg/gtk-3.0/settings.ini" <<GTK3
[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=$icon_theme
gtk-color-scheme=prefer-dark
gtk-application-prefer-dark-theme=1
GTK3
  ok "gtk-3.0/settings.ini configurado (tema oscuro)"

  # --- GTK 4.0 settings.ini ------------------------------------------------
  mkdir -p "$cfg/gtk-4.0"
  backup_target "$cfg/gtk-4.0/settings.ini"
  cat > "$cfg/gtk-4.0/settings.ini" <<GTK4
[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=$icon_theme
gtk-color-scheme=prefer-dark
gtk-application-prefer-dark-theme=1
GTK4
  ok "gtk-4.0/settings.ini configurado (tema oscuro)"

  # --- gsettings (si hay sesión GNOME / DE que lo soporte) -----------------
  if have gsettings; then
    step "Aplicando gsettings (color-scheme, gtk-theme, icon-theme)..."
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
    ok "gsettings aplicado (errores ignorados si no hay sesión)."
  fi

  ok "Tema oscuro configurado: GTK=$gtk_theme | Iconos=$icon_theme | Qt=paleta oscura (qt5ct/qt6ct)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Instalación orquestada de un grupo de paquetes, resolviendo AUR/manual
# ─────────────────────────────────────────────────────────────────────────────
# instalar_grupo <nombre> <fn_pkgs> [args...]
#   - llama a fn_pkgs, separa en __AUR__, __MANUAL__ y normales, e instala.
instalar_grupo() {
  local nombre="$1" fn="$2"; shift 2
  local out normal=() aur=() manual=()

  out="$("$fn" "$@")"
  # Separar tokens especiales
  local -a tokens
  read -r -a tokens <<< "$out"
  local i=0 tok
  while [[ $i -lt ${#tokens[@]} ]]; do
    tok="${tokens[$i]}"
    case "$tok" in
      __AUR__)    i=$((i+1)); [[ $i -lt ${#tokens[@]} ]] && aur+=("${tokens[$i]}") ;;
      __MANUAL__) manual+=("${out}"); break ;;   # el resto es texto informativo
      *)          normal+=("$tok") ;;
    esac
    i=$((i+1))
  done

  title "$nombre"

  if [[ ${#normal[@]} -gt 0 ]]; then
    case "$(pkg_manager)" in
      pacman) instalar_pacman "${normal[@]}" ;;
      apt)    instalar_apt "${normal[@]}" ;;
      *)      err "Sin gestor de paquetes soportado."; return 1 ;;
    esac
  fi

  if [[ ${#aur[@]} -gt 0 ]]; then
    instalar_aur "${aur[@]}"
  fi

  if [[ ${#manual[@]} -gt 0 ]]; then
    warn "Instalación manual requerida: ${manual[*]}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Flujo completo de dependencias (para uno o varios compositores)
# ─────────────────────────────────────────────────────────────────────────────
# instalar_dependencias <comp> [<comp> ...]
#   Las dependencias compartidas (quickshell, universales, nerd font, cliphist,
#   rust, matugen, awww) se instalan una sola vez; las específicas del
#   compositor se repiten por cada compositor.
instalar_dependencias() {
  local compositores=("$@")
  [[ ${#compositores[@]} -eq 0 ]] && { err "Falta el compositor."; return 1; }
  local d; d="$(detect_distro)"
  local manager; manager="$(pkg_manager)"
  local helper; helper="$(aur_helper)"

  if [[ "$manager" == "none" ]]; then
    die "Distro no soportada ($(distro_name)). Solo se soporta Arch y Debian."
  fi

  step "Distro detectada: $(distro_name)"
  step "Gestor: $manager | Helper AUR: $helper"

  # 0. Helper AUR: instalar yay si no hay ninguno (solo Arch)
  instalar_yay_si_falta

  # 0b. Herramientas base (dialog para el instalador, firefox para los binds)
  instalar_grupo "Herramientas base" pkgs_base

  # 0c. Fuentes (Roboto + símbolos Nerd Font que pide la barra de Quickshell)
  instalar_grupo "Fuentes" pkgs_fonts
  if [[ "$d" == "debian" ]]; then
    instalar_nerd_symbols_debian
  fi

  # 1. Compositores (uno por cada seleccionado)
  local comp
  for comp in "${compositores[@]}"; do
    instalar_grupo "Compositor: $comp" pkgs_compositor "$comp"
  done

  # 2. Quickshell
  instalar_grupo "Quickshell" pkgs_quickshell

  # 3. Dependencias universales
  instalar_grupo "Dependencias universales" pkgs_universal

  # 4. Nerd Font (universal)
  instalar_nerd_font

  # 5. cliphist
  case "$d" in
    arch)   instalar_grupo "cliphist" pkgs_cliphist ;;
    debian) instalar_cliphist_debian ;;
  esac

  # 6. grim + slurp (Niri usa capturas nativas; solo si hay algún no-niri)
  local necesita_grim=0
  for comp in "${compositores[@]}"; do
    [[ "$comp" != "niri" ]] && necesita_grim=1
  done
  if [[ "$necesita_grim" -eq 1 ]]; then
    instalar_grupo "grim + slurp (capturas)" pkgs_grim
  else
    info "Solo Niri seleccionado: omitiendo grim+slurp (usa capturas nativas)."
  fi

  # 7. Rust/cargo
  instalar_grupo "Rust/cargo" pkgs_rust

  # 8. matugen
  case "$d" in
    arch)   instalar_aur matugen-bin ;;   # evita compilar (alternativa: cargo)
    debian) instalar_matugen_cargo ;;
  esac

  # 9. awww (wallpaper con transición)
  case "$d" in
    arch)   instalar_aur awww ;;
    debian) instalar_awww_debian ;;
  esac

  # 10. SDDM (gestor de sesiones) si no está instalado
  if have sddm; then
    info "SDDM ya está instalado."
  else
    instalar_grupo "SDDM (gestor de sesiones)" pkgs_sddm
  fi

  # 11. Complementarios opcionales
  if paquete_activo complementarios; then
    instalar_grupo "Complementarios" pkgs_optional
  else
    info "Omitiendo complementarios (no seleccionados)."
  fi

  # 12. Herramientas de compresión (unzip/7zip/unrar)
  if paquete_activo compresion; then
    instalar_grupo "Compresión (unzip / 7zip / unrar)" pkgs_compresion
  else
    info "Omitiendo herramientas de compresión."
  fi

  # 13. Thunar (gestor de archivos) y sus dependencias
  if paquete_activo thunar; then
    instalar_grupo "Thunar (gestor de archivos)" pkgs_thunar
  else
    info "Omitiendo Thunar y sus dependencias."
  fi

  # 14. Aplicaciones adicionales (Office, lectores, iconos, temas, Qt...)
  if paquete_activo aplicaciones; then
    instalar_grupo "Aplicaciones" pkgs_aplicaciones

    # Flatpak: añadir el repositorio Flathub si se acaba de instalar
    if have flatpak; then
      if flatpak remotes --user 2>/dev/null | grep -qi flathub; then
        info "Flathub (usuario) ya está añadido."
      else
        step "Añadiendo repositorio Flathub..."
        flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
          && ok "Flathub añadido." \
          || warn "No se pudo añadir Flathub (revisa si flatpak está funcionando)."
      fi
    fi
  else
    info "Omitiendo aplicaciones adicionales."
  fi

  # 15. OpenCode (vía script oficial de opencode.ai)
  if paquete_activo opencode; then
    instalar_opencode
  else
    info "Omitiendo OpenCode."
  fi

  # 16. Tema oscuro automático (GTK + Qt)
  if paquete_activo tema_oscuro; then
    configurar_tema_oscuro
  else
    info "Omitiendo configuración de tema oscuro."
  fi

  ok "Dependencias instaladas para: ${compositores[*]}"
}
