#!/usr/bin/env bash
# =============================================================================
#  install.sh — Instalador de dotfiles para Niri, Sway, Hyprland y Umbriel
# =============================================================================
#  Instala dependencias (Arch/Debian) y copia los dotfiles usando menús
#  interactivos basados en `dialog` (con fallback a menús de consola).
#
#  Uso:
#      ./install.sh                          # menú interactivo
#      ./install.sh --compositor sway --deps     # solo dependencias
#      ./install.sh --compositor niri --dotfiles # solo dotfiles
#      ./install.sh --compositor hypr,sway --ambos
#      ./install.sh --todos --ambos              # los 4 compositores
#      ./install.sh --compositor sway --restaurar  # desinstalar/restaurar
#
#  Compositor válido: hypr | sway | niri | umbriel (o --todos para los 4)
# =============================================================================

set -u

# ─────────────────────────────────────────────────────────────────────────────
# Cargar bibliotecas
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
export PROJECT_DIR

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/dependencies.sh
source "$SCRIPT_DIR/lib/dependencies.sh"
# shellcheck source=lib/dotfiles.sh
source "$SCRIPT_DIR/lib/dotfiles.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Constantes
# ─────────────────────────────────────────────────────────────────────────────
COMPOSITORES=("hypr:Hyprland" "sway:Sway" "niri:Niri" "umbriel:Umbriel")
DIALOG_TITLE="Instalador de dotfiles — Quickshell"

# Verificar si un compositor es válido
compositor_valido() {
  local c
  for c in "${COMPOSITORES[@]}"; do
    [[ "${c%%:*}" == "$1" ]] && return 0
  done
  return 1
}

# Nombre legible del compositor
nombre_compositor() {
  local c
  for c in "${COMPOSITORES[@]}"; do
    [[ "${c%%:*}" == "$1" ]] && { echo "${c#*:}"; return 0; }
  done
  echo "$1"
}

# Lista de nombres legibles para una lista de códigos
nombres_compositores() {
  local codes=("$@") names=() c
  for c in "${codes[@]}"; do names+=("$(nombre_compositor "$c")"); done
  printf '%s' "${names[*]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Menús dialog (con fallback a consola)
# ─────────────────────────────────────────────────────────────────────────────
# dialog solo si está instalado Y hay TTY (stdin y stdout)
USAR_DIALOG=1
if ! have dialog || [[ ! -t 0 || ! -t 1 ]]; then
  USAR_DIALOG=0
fi

# Modo no interactivo: se activa cuando compositor y acción llegan por CLI
MODO_NO_INTERACTIVO=0

# Seleccionar compositores (multi-selección). Devuelve códigos separados por coma.
menu_compositor() {
  if [[ "$USAR_DIALOG" -eq 1 ]]; then
    local choice
    choice="$(dialog --stdout --title "$DIALOG_TITLE" --backtitle "Paso 1/3 — Comositor(es)" \
      --checklist "Selecciona uno o más compositores (espacio marca, enter confirma):" 0 0 4 \
      hypr    "Hyprland" off \
      sway    "Sway"     off \
      niri    "Niri"     off \
      umbriel "Umbriel"  off 2>/dev/null)"
    # dialog separa los marcados con espacios; normalizar a comas
    [[ -n "$choice" ]] && tr ' ' ',' <<< "$choice" | sed 's/,\{2,\}/,/g; s/^,//; s/,$//' || echo ""
  else
    echo ""
    echo "Compositores disponibles (elige varios separados por coma o espacio):"
    echo "  hypr   = Hyprland"
    echo "  sway   = Sway"
    echo "  niri   = Niri"
    echo "  umbriel= Umbriel"
    echo "  todos  = los 4"
    local ans
    read -r -p "Elige [ej: hypr,sway / todos]: " ans
    ans="$(tr ' ' ',' <<< "$ans")"
    [[ "$ans" == "todos" || "$ans" == "all" ]] && echo "hypr,sway,niri,umbriel" || echo "$ans"
  fi
}

# Seleccionar acción (devuelve: deps | dotfiles | ambos | restaurar)
menu_accion() {
  if [[ "$USAR_DIALOG" -eq 1 ]]; then
    dialog --stdout --title "$DIALOG_TITLE" --backtitle "Paso 2/3 — Acción" \
      --menu "¿Qué quieres hacer?" 0 0 0 \
      deps      "Instalar dependencias" \
      dotfiles  "Instalar dotfiles" \
      ambos     "Instalar ambas cosas" \
      restaurar "Desinstalar / restaurar dotfiles" 2>/dev/null
  else
    echo ""
    echo "Acción:"
    echo "  1) Instalar dependencias"
    echo "  2) Instalar dotfiles"
    echo "  3) Instalar ambas cosas"
    echo "  4) Desinstalar / restaurar dotfiles"
    local ans
    read -r -p "Elige [1-4]: " ans
    case "$ans" in
      1) echo "deps" ;;
      2) echo "dotfiles" ;;
      3) echo "ambos" ;;
      4) echo "restaurar" ;;
      *) echo "" ;;
    esac
  fi
}

# Confirmación final con resumen
menu_confirmacion() {
  local codes_str="$1" accion="$2"
  local -a codes; IFS=',' read -r -a codes <<< "$codes_str"
  local resumen=""
  resumen+="Compositor(es) : $(nombres_compositores "${codes[@]}")\n"
  resumen+="Distro         : $(distro_name)\n"
  resumen+="Gestor         : $(pkg_manager)"
  [[ "$(aur_helper)" != "none" ]] && resumen+=" | AUR: $(aur_helper)"
  resumen+="\nAcción          : $accion\n\n"
  resumen+="¿Proceder con la instalación?"

  if [[ "$USAR_DIALOG" -eq 1 ]]; then
    dialog --stdout --title "$DIALOG_TITLE" --backtitle "Paso 3/3 — Confirmar" \
      --yesno "$resumen" 0 0 2>/dev/null
    return $?
  else
    echo ""
    echo -e "  $resumen"
    confirm "¿Proceder? [s/N] " && return 0 || return 1
  fi
}

# Mostrar ayuda (siempre texto plano; dialog no aporta aquí)
mostrar_ayuda() {
  cat <<'EOF'
Instalador de dotfiles para Niri, Sway, Hyprland y Umbriel.

Uso:
  ./install.sh                                  # menú interactivo
  ./install.sh --compositor sway --deps         # dependencias de Sway
  ./install.sh --compositor hypr,sway --ambos   # varios a la vez
  ./install.sh --todos --dotfiles               # los 4 compositores
  ./install.sh --compositor niri --restaurar    # desinstalar/restaurar

Compositor: hypr | sway | niri | umbriel  (separados por coma, o --todos)

Acciones:
  --deps       instalar dependencias
  --dotfiles   instalar dotfiles
  --ambos      dependencias + dotfiles
  --restaurar  desinstalar dotfiles (restaura respaldos .bak-*)
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Ejecución de la acción elegida
# ─────────────────────────────────────────────────────────────────────────────
ejecutar() {
  local codes_str="$1" accion="$2"
  local -a codes; IFS=',' read -r -a codes <<< "$codes_str"

  case "$accion" in
    deps)
      instalar_dependencias "${codes[@]}"
      ;;
    dotfiles)
      instalar_dotfiles "${codes[@]}"
      ;;
    ambos)
      instalar_dependencias "${codes[@]}"
      instalar_dotfiles "${codes[@]}"
      ;;
    restaurar)
      restaurar_dotfiles "${codes[@]}"
      ;;
    *)
      err "Acción desconocida: $accion"
      return 1
      ;;
  esac
}

# Resumen final
resumen_final() {
  local codes_str="$1"
  local -a codes; IFS=',' read -r -a codes <<< "$codes_str"
  echo ""
  title "Instalación completada"
  echo "Resumen final:"
  echo "  Compositor(es): $(nombres_compositores "${codes[@]}")"
  echo "  Configs:    ~/.config/ (hypr|sway|niri|umbriel, alacritty, kitty, fuzzel, matugen)"
  echo "  Quickshell: ~/.config/quickshell"
  echo ""
  echo "Siguientes pasos:"
  for comp in "${codes[@]}"; do
    case "$comp" in
      hypr)    echo "  [Hyprland] Inicia sesión en Hyprland (quickshell arranca vía autostart)." ;;
      sway)    echo "  [Sway]     Inicia sesión en Sway (quickshell -c ~/.config/quickshell/sway)." ;;
      niri)    echo "  [Niri]     Inicia sesión en Niri (config modular en config.d/)." ;;
      umbriel) echo "  [Umbriel]  Valida: umbriel validate; luego quickshell -c ~/.config/quickshell/umbriel" ;;
    esac
  done
  echo "  - Si algo falla, revisa los .bak-* generados para restaurar."
}

# ─────────────────────────────────────────────────────────────────────────────
# Punto de entrada
# ─────────────────────────────────────────────────────────────────────────────
main() {
  # Parseo de argumentos CLI
  local codes_str="" accion="" arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      -h|--help)  mostrar_ayuda; exit 0 ;;
      --compositor)
        [[ $# -ge 2 ]] || die "Falta valor para --compositor"
        [[ -n "$codes_str" ]] && codes_str+=",$2" || codes_str="$2"
        shift 2 ;;
      --todos|--all)
        codes_str="hypr,sway,niri,umbriel"; shift ;;
      --deps)      accion="deps"; shift ;;
      --dotfiles)  accion="dotfiles"; shift ;;
      --ambos)     accion="ambos"; shift ;;
      --restaurar) accion="restaurar"; shift ;;
      *)
        err "Argumento desconocido: $arg"
        mostrar_ayuda
        exit 1
        ;;
    esac
  done

  # Normalizar lista de compositores
  if [[ -n "$codes_str" ]]; then
    # Reemplazar espacios por comas y limpiar
    codes_str="$(tr ' ' ',' <<< "$codes_str" | sed 's/,\{2,\}/,/g; s/^,//; s/,$//')"
    local -a codes; IFS=',' read -r -a codes <<< "$codes_str"
    local c valid=1
    for c in "${codes[@]}"; do
      compositor_valido "$c" || { err "Compositor no válido: $c (usa hypr|sway|niri|umbriel)"; valid=0; }
    done
    [[ "$valid" -eq 0 ]] && exit 1
  fi

  # Modo interactivo si no se pasaron argumentos completos
  if [[ -z "$codes_str" ]]; then
    [[ "$USAR_DIALOG" -eq 0 ]] && { err "Se necesita dialog (y una TTY) para el modo interactivo, o pasa --compositor y una acción."; exit 1; }
    codes_str="$(menu_compositor)"
    [[ -z "$codes_str" ]] && { echo "Cancelado."; exit 0; }
  fi

  if [[ -z "$accion" ]]; then
    [[ "$USAR_DIALOG" -eq 0 ]] && { err "Se necesita dialog (y una TTY) para el modo interactivo, o pasa una acción (--deps/--dotfiles/--ambos/--restaurar)."; exit 1; }
    accion="$(menu_accion)"
    [[ -z "$accion" ]] && { echo "Cancelado."; exit 0; }
  else
    MODO_NO_INTERACTIVO=1
  fi

  # Confirmación: solo en modo interactivo (dialog). En CLI se procede directo.
  if [[ "$MODO_NO_INTERACTIVO" -eq 0 ]]; then
    if ! menu_confirmacion "$codes_str" "$accion"; then
      echo "Cancelado por el usuario."
      exit 0
    fi
  else
    local -a codes; IFS=',' read -r -a codes <<< "$codes_str"
    echo "Compositor(es): $(nombres_compositores "${codes[@]}") | Acción: $accion | Distro: $(distro_name)"
  fi

  echo ""
  title "Iniciando instalación"
  ejecutar "$codes_str" "$accion"
  resumen_final "$codes_str"
}

main "$@"
