#!/usr/bin/env bash
# dependencies.sh — definición e instalación de dependencias por distro.
# Se ejecuta con `source` desde install.sh.

set -u

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

# --- SDDM (gestor de sesiones) ------------------------------------------------
pkgs_sddm() {
  echo "sddm"
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
  if confirm "¿Instalar también los complementarios (fuzzel, alacritty, thunar, playerctl, nm-applet)? [s/N] "; then
    instalar_grupo "Complementarios" pkgs_optional
  else
    info "Omitiendo complementarios."
  fi

  ok "Dependencias instaladas para: ${compositores[*]}"
}
