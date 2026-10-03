#!/usr/bin/env bash
# autoconf-monitor.sh — detecta las salidas de vídeo del equipo y reescribe,
# de forma idempotente, el bloque de monitor de las configs de los compositores
# hypr / sway / umbriel / niri.
#
# El bloque vive siempre entre marcadores y TODO lo que hay entre ellos
# (inclusive) se regenera en cada ejecución:
#   hypr    -- >>> autoconf-monitor >>>  /  -- <<< autoconf-monitor <<<
#   sway    #  >>> autoconf-monitor >>>  /  #  <<< autoconf-monitor <<<
#   umbriel #  >>> autoconf-monitor >>>  /  #  <<< autoconf-monitor <<<
#   niri    // >>> autoconf-monitor >>>  /  // <<< autoconf-monitor <<<
#
# Detección (por prioridad):
#   1. Sesión activa del compositor: hyprctl monitors -j / swaymsg -t get_outputs
#      / niri msg outputs -j / umbriel outputs
#   2. wlr-randr y xrandr --query (último recurso con sesión)
#   3. /sys/class/drm (o siempre con --headless): conectadas + MÁXIMO modo
# Selección por salida: máxima resolución (mayor área; empate → modo
# "preferred"/nativo si el backend lo marca) y refresh óptimo para esa
# resolución: 120 si está disponible, si no 60, si no el mayor disponible
# (59.996 → 60; siempre entero, sin decimales). En headless el fichero DRM
# `modes` solo trae resoluciones (sin refresh): se usa 60 salvo evidencia
# de que el panel soporta 120 (EDID de este equipo: una sola DTD a 60 Hz).
# Si no se detecta nada, la región queda SOLO con marcadores (el compositor
# hace autoconfig en vez de usar los nombres hardcodeados del portátil).
#
# Uso: autoconf-monitor.sh [--dry-run] [--headless] [hypr|sway|umbriel|niri]...
#       (sin compositores = los cuatro)
# Respeta XDG_CONFIG_HOME (por defecto ~/.config).

set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY_RUN=0
HEADLESS=0
COMPS=()

OUT_NAME=()
OUT_W=()
OUT_H=()
OUT_R=()
OUT_S=()
POS_X=()
POS_Y=()
DETECT_SRC=""
JSON_BACKEND=""

# ─────────────────────────────────────────────────────────────────────────────
# Logging (estilo simple, el script puede vivir en ~/.local/bin sin lib/)
# ─────────────────────────────────────────────────────────────────────────────
log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'EOF'
Uso: autoconf-monitor.sh [--dry-run] [--headless] [hypr|sway|umbriel|niri]...

  --dry-run   Muestra lo que cambiaría sin escribir nada.
  --headless  Fuerza la detección por /sys/class/drm (ignora sesión gráfica).

Sin compositores se aplican los cuatro (hypr, sway, umbriel, niri).
Respeta XDG_CONFIG_HOME (por defecto ~/.config).
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Normalización de valores
# ─────────────────────────────────────────────────────────────────────────────
# norm_refresh <n> — Hz canónico como ENTERO (sin decimales: 60, no 59.996).
# Acepta mHz (>1000) y lo convierte. 120/60 con tolerancia ±1 Hz; si no,
# redondeo al entero más cercano. Default 60.
norm_refresh() {
  awk -v r="${1:-60}" 'BEGIN{
    r = r + 0
    if (r > 1000) r /= 1000.0
    if (r <= 0)   r = 60
    d120 = (r >= 120 ? r - 120 : 120 - r)
    d60  = (r >= 60  ? r - 60  : 60 - r)
    if (d120 <= 1.0)      r = 120
    else if (d60 <= 1.0)  r = 60
    else                  r = int(r + 0.5)
    print r
  }'
}

# norm_scale <n> — 1 / 1.25 / ...
norm_scale() {
  awk -v s="${1:-1}" 'BEGIN{
    v = s + 0
    if (v <= 0) v = 1
    t = sprintf("%.6f", v)
    if (index(t, ".") > 0) { sub(/0+$/, "", t); sub(/\.$/, "", t) }
    if (t == "") t = "1"
    print t
  }'
}

# ─────────────────────────────────────────────────────────────────────────────
# Parsers JSON (python3 > jq > awk) y de texto
# ─────────────────────────────────────────────────────────────────────────────
init_json_backend() {
  if have python3; then
    JSON_BACKEND="python3"
  elif have jq; then
    JSON_BACKEND="jq"
  else
    JSON_BACKEND="awk"
    log "Sin python3 ni jq: se usa el parser JSON awk (best effort)."
  fi
}

json_parse() {
  case "$JSON_BACKEND" in
    python3) json_parse_python ;;
    jq)      json_parse_jq ;;
    *)       json_parse_awk ;;
  esac
}

# Entrada: JSON de hyprctl/swaymsg/niri por stdin.
# Salida:  nombre|ancho|alto|refresh|scale  (una línea por salida conectada)
# Selección por salida: máxima resolución (mayor área; empate → modo
# "preferred"/nativo) y, para esa resolución, 120 si está disponible, si no
# 60, si no el mayor disponible (siempre entero: 59.996 → 60).
json_parse_python() {
  local prog
  prog='
import json, sys, re

def fnum(v):
    try:
        v = float(v)
    except Exception:
        return None
    if v > 1000:
        v /= 1000.0
    if v <= 0:
        return None
    return v

def rint(v):
    if abs(v - 120) <= 1.0:
        return "120"
    if abs(v - 60) <= 1.0:
        return "60"
    return str(int(v + 0.5))

def fscale(v):
    try:
        v = float(v)
    except Exception:
        v = 1.0
    if v <= 0:
        v = 1.0
    t = "%.6f" % v
    if "." in t:
        t = t.rstrip("0").rstrip(".")
    return t or "1"

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if isinstance(data, dict):
    data = [data]
if not isinstance(data, list):
    sys.exit(1)
for o in data:
    if not isinstance(o, dict):
        continue
    if o.get("active") is False or o.get("disabled") is True:
        continue
    name = o.get("name")
    if not isinstance(name, str) or not name:
        continue
    cands = []  # (w, h, refresh|None, preferred)
    modes = o.get("modes")
    if isinstance(modes, list):
        for m in modes:
            if not isinstance(m, dict):
                continue
            w, h = m.get("width"), m.get("height")
            if not isinstance(w, (int, float)) or not isinstance(h, (int, float)):
                continue
            r = m.get("refresh")
            if r is None:
                r = m.get("refresh_rate")
            cands.append((int(w), int(h), fnum(r),
                          bool(m.get("preferred") or m.get("is_preferred"))))
    amodes = o.get("availableModes")  # hyprctl: ["1920x1080@60", ...]
    if isinstance(amodes, list):
        for s in amodes:
            if not isinstance(s, str):
                continue
            mm = re.match(r"\s*(\d+)\s*x\s*(\d+)\s*@\s*([\d.]+)", s)
            if mm:
                cands.append((int(mm.group(1)), int(mm.group(2)),
                              fnum(mm.group(3)), False))
    if not cands:
        cm = o.get("current_mode")
        if isinstance(cm, int) and isinstance(modes, list) and 0 <= cm < len(modes):
            cm = modes[cm]
        if isinstance(cm, dict):
            w, h = cm.get("width"), cm.get("height")
            if isinstance(w, (int, float)) and isinstance(h, (int, float)):
                r = cm.get("refresh")
                if r is None:
                    r = cm.get("refresh_rate")
                cands.append((int(w), int(h), fnum(r), True))
    if not cands:
        rect = o.get("rect") if isinstance(o.get("rect"), dict) else {}
        w = o.get("width") or rect.get("width")
        h = o.get("height") or rect.get("height")
        if not isinstance(w, (int, float)) or not isinstance(h, (int, float)):
            continue
        cands.append((int(w), int(h), None, False))
    best = max(range(len(cands)),
               key=lambda i: (cands[i][0] * cands[i][1], cands[i][3]))
    bw, bh = cands[best][0], cands[best][1]
    rs = [c[2] for c in cands if c[0] == bw and c[1] == bh and c[2] is not None]
    top = o.get("refreshRate")
    if top is None:
        top = o.get("refresh")
    if fnum(top) is not None and all(c[2] is None for c in cands):
        rs.append(fnum(top))
    if any(abs(v - 120) <= 1.0 for v in rs):
        r = "120"
    elif any(abs(v - 60) <= 1.0 for v in rs):
        r = "60"
    elif rs:
        r = rint(max(rs))
    else:
        r = "60"
    print("%s|%d|%d|%s|%s" % (name, bw, bh, r, fscale(o.get("scale"))))
'
  python3 -c "$prog"
}

json_parse_jq() {
  local prog
  prog='
(if type == "array" then . else [.] end)
| .[]
| select(type == "object")
| select(((.name // "") | type) == "string" and ((.name // "") != ""))
| select(((.active // true) != false) and ((.disabled // false) != true))
| . as $o
| (((($o.modes // []) | if type == "array" then . else [] end)
    | map(select(type == "object"))
    | map(select(((.width // null) | type) == "number"
                 and ((.height // null) | type) == "number"))
    | map({w: .width, h: .height,
            r: (.refresh // .refresh_rate // $o.refreshRate // $o.refresh // 60),
            p: (if .preferred // .is_preferred // false then 1 else 0 end)}))
   + (if ((($o.current_mode // null) | type) == "object"
          and ((($o.current_mode.width // null) | type) == "number"
          and ((($o.current_mode.height // null) | type) == "number"))
        then [{w: $o.current_mode.width, h: $o.current_mode.height,
               r: ($o.current_mode.refresh // $o.current_mode.refresh_rate
                   // $o.refreshRate // $o.refresh // 60), p: 0}]
        else [] end)
   + (if (((($o.modes // []) | if type == "array" then . else [] end) | length) == 0
          and ((($o.width // $o.rect.width // null) | type) == "number"
          and ((($o.height // $o.rect.height // null) | type) == "number"))
        then [{w: ($o.width // $o.rect.width), h: ($o.height // $o.rect.height),
               r: ($o.refreshRate // $o.refresh // 60), p: 0}]
        else [] end)) as $c
| select(($c | length) > 0)
| ($c | max_by([(.w * .h), .p])) as $b
| ([$c[] | select(.w == $b.w and .h == $b.h)
    | (.r | (tonumber? // 60) | if . > 1000 then . / 1000 else . end)]
   | if any(.[]; . >= 119 and . <= 121) then 120
     elif any(.[]; . >= 59 and . <= 61) then 60
     else (max | round) end) as $rr
| "\($o.name)|\($b.w)|\($b.h)|\($rr)|\($o.scale // 1)"
'
  jq -r "$prog"
}

# Parser awk autocontenido (fallback sin python3/jq): recorre el JSON carácter
# a carácter, extrae name/width/height/refresh*/scale/active/disabled y emite
# un registro al cerrar cada objeto de primer nivel.
json_parse_awk() {
  awk '
    function resetrec() { name = ""; w = ""; h = ""; r = ""; sc = ""; act = ""; dis = "" }
    function handle_val() {
      if (pk == "") { num = ""; word = ""; vt = ""; return }
      if (vt == "num") {
        if (pk == "width" && w == "") w = num + 0
        else if (pk == "height" && h == "") h = num + 0
        else if ((pk == "refreshRate" || pk == "refresh" || pk == "refresh_rate") && r == "") r = num + 0
        else if (pk == "scale" && sc == "") sc = num + 0
      } else if (vt == "word") {
        if (pk == "active") act = sv
        else if (pk == "disabled") dis = sv
      } else if (vt == "str") {
        if (pk == "name") name = sv
        else if (pk == "active") act = sv
        else if (pk == "disabled") dis = sv
      }
      pk = ""; num = ""; word = ""; vt = ""; sv = ""
    }
    function flush() {
      if (name != "" && act != "false" && dis != "true" && w != "" && h != "")
        printf "%s|%s|%s|%s|%s\n", name, w, h, (r == "" ? 60 : r), (sc == "" ? 1 : sc)
      resetrec()
    }
    function flushval() {
      if (num != "" || word != "") {
        vt = (num != "" ? "num" : "word")
        if (vt == "word") sv = word
        handle_val()
      }
      num = ""; word = ""
    }
    BEGIN { depth = 0; instr = 0; esc = 0; pk = ""; num = ""; word = ""; vt = ""; sv = ""; sbuf = "" }
    {
      line = $0
      n = length(line)
      for (i = 1; i <= n; i++) {
        ch = substr(line, i, 1)
        if (instr) {
          if (esc) { sbuf = sbuf ch; esc = 0; continue }
          if (ch == "\\") { esc = 1; continue }
          if (ch == "\"") {
            instr = 0
            j = i + 1
            while (j <= n && substr(line, j, 1) ~ /[ \t]/) j++
            nxt = (j <= n ? substr(line, j, 1) : "")
            if (nxt == ":") { pk = sbuf; num = ""; word = ""; vt = "" }
            else { sv = sbuf; vt = "str"; handle_val() }
            sbuf = ""
            continue
          }
          sbuf = sbuf ch
          continue
        }
        if (ch == "\"") { instr = 1; sbuf = ""; continue }
        if (ch == "{") { depth++; continue }
        if (ch == "}") {
          flushval()
          depth--
          if (depth <= 0) { flush(); depth = 0 }
          continue
        }
        if (ch == ",") { flushval(); continue }
        if (ch == ":") continue
        if (pk != "" && ch ~ /[0-9.+\-eE]/) { num = num ch; continue }
        if (pk != "" && ch ~ /[A-Za-z_]/)    { word = word ch; continue }
        flushval()
      }
    }
    END { flush() }
  '
}

# Parser estilo wlr-randr / umbriel outputs (texto con sangrías).
# Acumula TODOS los modos de cada salida y elige: máxima resolución (mayor
# área; empate → "preferred"/nativo) y refresh 120 si está, si no 60, si no
# el mayor (siempre entero).
parse_wlr_style() {
  awk '
    function resetrec() { name = ""; enabled = ""; scale = ""; n = 0 }
    function addmode(w, h, r, tag) {
      n++
      W[n] = w; H[n] = h; R[n] = r
      P[n] = (tag ~ /preferred/ ? 1 : 0)
    }
    function abs(x) { return (x < 0 ? -x : x) }
    function flush(   i, best, bestarea, area, bw, bh, has120, has60, maxr, r) {
      if (name == "" || enabled == "no" || n == 0) { resetrec(); return }
      best = 1; bestarea = W[1] * H[1]
      for (i = 2; i <= n; i++) {
        area = W[i] * H[i]
        if (area > bestarea || (area == bestarea && P[i] && !P[best])) {
          best = i; bestarea = area
        }
      }
      bw = W[best]; bh = H[best]
      has120 = 0; has60 = 0; maxr = 0
      for (i = 1; i <= n; i++) {
        if (W[i] != bw || H[i] != bh) continue
        r = R[i] + 0
        if (r > 1000) r /= 1000
        if (abs(r - 120) <= 1) has120 = 1
        if (abs(r - 60) <= 1)  has60 = 1
        if (r > maxr) maxr = r
      }
      if (has120)      r = 120
      else if (has60)  r = 60
      else             r = int(maxr + 0.5)
      printf "%s|%s|%s|%s|%s\n", name, bw, bh, r, (scale == "" ? 1 : scale)
      resetrec()
    }
    BEGIN { resetrec(); inmodes = 0 }
    {
      if ($0 ~ /^[^ \t]/) {
        flush()
        name = $1
        inmodes = 0
        next
      }
      if ($0 ~ /^[ \t]*Enabled:/) { enabled = tolower($2); next }
      if ($0 ~ /^[ \t]*Scale:/)   { scale = $2; next }
      if ($0 ~ /^[ \t]*Modes:/)   { inmodes = 1; next }
      if (inmodes && $0 ~ /x[0-9]+/ && $0 ~ /Hz/) {
        ln = $0
        if (!match(ln, /[0-9]+x[0-9]+/)) next
        sz = substr(ln, RSTART, RLENGTH)
        rest = substr(ln, RSTART + RLENGTH)
        if (!match(rest, /[0-9]+(\.[0-9]+)?[ \t]*Hz/)) next
        rf = substr(rest, RSTART, RLENGTH)
        sub(/[ \t]*Hz/, "", rf)
        split(sz, a, "x")
        addmode(a[1], a[2], rf, ln)
        next
      }
    }
    END { flush() }
  '
}

# Parser de `niri msg outputs` (salida texto, cuando -j no está disponible).
parse_niri_text() {
  awk '
    function flush() {
      if (name != "" && nw != "")
        printf "%s|%s|%s|%s|%s\n", name, nw, nh, nr, (scale == "" ? 1 : scale)
      name = ""; nw = ""; nh = ""; nr = ""; scale = ""
    }
    {
      if ($0 ~ /^Output "/) { flush(); name = $2; gsub(/"/, "", name); next }
      if ($0 ~ /^[ \t]*Current mode:/) {
        if (match($0, /[0-9]+x[0-9]+/)) {
          sz = substr($0, RSTART, RLENGTH)
          rest = substr($0, RSTART + RLENGTH)
          r = "60"
          if (match(rest, /[0-9]+(\.[0-9]+)?/)) r = substr(rest, RSTART, RLENGTH)
          split(sz, a, "x")
          nw = a[1]; nh = a[2]; nr = r
        }
        next
      }
      if ($0 ~ /^[ \t]*Scale:/) { scale = $2; next }
    }
    END { flush() }
  '
}

# Parser de `xrandr --query` (último recurso).
# Acumula todos los modos (todas las tasas de cada línea) y elige: máxima
# resolución (mayor área; empate → marcada `+` = preferred) y refresh 120
# si está, si no 60, si no el mayor (siempre entero).
parse_xrandr() {
  awk '
    function resetrec() { name = ""; n = 0 }
    function addmode(w, h, r, p) { n++; W[n] = w; H[n] = h; R[n] = r; P[n] = p }
    function abs(x) { return (x < 0 ? -x : x) }
    function flush(   i, best, bestarea, area, bw, bh, has120, has60, maxr, r) {
      if (name == "" || n == 0) { resetrec(); return }
      best = 1; bestarea = W[1] * H[1]
      for (i = 2; i <= n; i++) {
        area = W[i] * H[i]
        if (area > bestarea || (area == bestarea && P[i] && !P[best])) {
          best = i; bestarea = area
        }
      }
      bw = W[best]; bh = H[best]
      has120 = 0; has60 = 0; maxr = 0
      for (i = 1; i <= n; i++) {
        if (W[i] != bw || H[i] != bh) continue
        r = R[i] + 0
        if (r > 1000) r /= 1000
        if (abs(r - 120) <= 1) has120 = 1
        if (abs(r - 60) <= 1)  has60 = 1
        if (r > maxr) maxr = r
      }
      if (has120)      r = 120
      else if (has60)  r = 60
      else             r = int(maxr + 0.5)
      printf "%s|%s|%s|%s|1\n", name, bw, bh, r
      resetrec()
    }
    {
      if ($2 == "connected")    { flush(); name = $1; next }
      if ($2 == "disconnected") { flush(); name = ""; next }
      if (name != "" && $1 ~ /^[0-9]+x[0-9]+/ && NF >= 2) {
        split($1, a, "x")
        pref = ($0 ~ /\+/ ? 1 : 0)
        for (f = 2; f <= NF; f++) {
          fld = $f
          if (fld ~ /^[0-9]/) {
            r = fld
            sub(/[^0-9.].*$/, "", r)
            if (r != "") addmode(a[1], a[2], r, pref)
          }
        }
      }
    }
    END { flush() }
  '
}

# ─────────────────────────────────────────────────────────────────────────────
# Fuentes de detección (imprimen nombre|w|h|refresh|scale)
# ─────────────────────────────────────────────────────────────────────────────
run_hyprctl() {
  have hyprctl || return 1
  local out
  out="$(hyprctl monitors -j 2>/dev/null)" || return 1
  case "$out" in [\{\[]*) ;; *) return 1 ;; esac
  printf '%s\n' "$out" | json_parse
}

run_swaymsg() {
  have swaymsg || return 1
  local out
  out="$(swaymsg -t get_outputs -j 2>/dev/null)" || out=""
  case "$out" in
    [\{\[]*) ;;
    *) out="$(swaymsg -t get_outputs 2>/dev/null)" || return 1 ;;
  esac
  case "$out" in [\{\[]*) ;; *) return 1 ;; esac
  printf '%s\n' "$out" | json_parse
}

run_niri() {
  have niri || return 1
  local out
  out="$(niri msg -j outputs 2>/dev/null)" || out=""
  case "$out" in
    [\{\[]*) printf '%s\n' "$out" | json_parse; return $? ;;
  esac
  out="$(niri msg outputs -j 2>/dev/null)" || out=""
  case "$out" in
    [\{\[]*) printf '%s\n' "$out" | json_parse; return $? ;;
  esac
  out="$(niri msg outputs 2>/dev/null)" || return 1
  [[ -n "$out" ]] || return 1
  case "$out" in
    [\{\[]*) printf '%s\n' "$out" | json_parse ;;
    *)       printf '%s\n' "$out" | parse_niri_text ;;
  esac
}

run_umbriel() {
  have umbriel || return 1
  local out
  out="$(umbriel outputs 2>/dev/null)" || return 1
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out" | parse_wlr_style
}

run_wlr_randr() {
  have wlr-randr || return 1
  local out
  out="$(wlr-randr 2>/dev/null)" || return 1
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out" | parse_wlr_style
}

run_xrandr() {
  have xrandr || return 1
  local out
  out="$(xrandr --query 2>/dev/null)" || return 1
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out" | parse_xrandr
}

# Fallback headless: /sys/class/drm/card*-{NAME}/status == connected.
# El fichero `modes` solo trae resoluciones (sin refresh): se elige la
# MÁXIMA por área (antes: la primera línea). Refresh 60, salvo evidencia
# de que el panel soporta 120 (EDID/modetest; este equipo expone una sola
# DTD a 59.996 Hz → 60).
detect_drm() {
  local st status name m wh w h found=0 bw bh
  for st in /sys/class/drm/card*-*; do
    [[ -f "$st/status" ]] || continue
    read -r status < "$st/status" || continue
    [[ "$status" == "connected" ]] || continue
    name="$(basename "$st")"
    name="${name#card*-}"
    [[ -f "$st/modes" ]] || continue
    bw=0; bh=0
    while IFS= read -r m || [[ -n "$m" ]]; do
      m="${m//$'\r'/}"
      [[ -n "$m" ]] || continue
      if [[ "$m" == *@* ]]; then wh="${m%%@*}"; else wh="$m"; fi
      w="${wh%%x*}"
      h="${wh##*x}"
      [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || continue
      if (( w * h > bw * bh )); then bw="$w"; bh="$h"; fi
    done < "$st/modes"
    (( bw > 0 && bh > 0 )) || continue
    printf '%s|%s|%s|60|1\n' "$name" "$bw" "$bh"
    found=1
  done
  (( found ))
}

# ─────────────────────────────────────────────────────────────────────────────
# Carga de resultados y empaquetado de posiciones
# ─────────────────────────────────────────────────────────────────────────────
load_lines() {
  local n w h r s i seen
  while IFS='|' read -r n w h r s; do
    [[ -n "${n:-}" ]] || continue
    [[ "${w:-}" =~ ^[0-9]+$ && "${h:-}" =~ ^[0-9]+$ ]] || continue
    seen=0
    for i in ${OUT_NAME[@]+"${OUT_NAME[@]}"}; do
      [[ "$i" == "$n" ]] && { seen=1; break; }
    done
    (( seen )) && continue
    OUT_NAME+=("$n")
    OUT_W+=("$w")
    OUT_H+=("$h")
    OUT_R+=("$(norm_refresh "${r:-60}")")
    OUT_S+=("$(norm_scale "${s:-1}")")
  done
}

# attempt <etiqueta> <función> — intenta una fuente y carga sus líneas.
attempt() {
  local label="$1" fn="$2" out
  out="$("$fn")" || out=""
  [[ -n "$out" ]] || return 1
  load_lines <<< "$out"
  if (( ${#OUT_NAME[@]} > 0 )); then
    DETECT_SRC="$label"
    return 0
  fi
  return 1
}

# pack_positions — x acumula anchos, y = 0 (empaquetado secuencial).
pack_positions() {
  POS_X=()
  POS_Y=()
  local i x=0
  for ((i = 0; i < ${#OUT_NAME[@]}; i++)); do
    POS_X[i]="$x"
    POS_Y[i]=0
    x=$((x + OUT_W[i]))
  done
}

detect_for() {
  local comp="$1"
  OUT_NAME=(); OUT_W=(); OUT_H=(); OUT_R=(); OUT_S=()
  POS_X=(); POS_Y=()
  DETECT_SRC=""

  if (( ! HEADLESS )); then
    case "$comp" in
      hypr)
        [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && attempt "hyprctl" run_hyprctl
        ;;
      sway)
        [[ -n "${SWAYSOCK:-}" ]] && attempt "swaymsg" run_swaymsg
        ;;
      niri)
        [[ -n "${NIRI_SOCKET:-}" ]] && attempt "niri msg" run_niri
        ;;
      umbriel)
        attempt "umbriel outputs" run_umbriel
        ;;
    esac
    if (( ${#OUT_NAME[@]} == 0 )); then attempt "umbriel outputs" run_umbriel; fi
    if (( ${#OUT_NAME[@]} == 0 )); then attempt "wlr-randr" run_wlr_randr; fi
    if (( ${#OUT_NAME[@]} == 0 )); then attempt "xrandr" run_xrandr; fi
  fi

  if (( ${#OUT_NAME[@]} == 0 )); then attempt "/sys/class/drm" detect_drm; fi

  if (( ${#OUT_NAME[@]} == 0 )); then
    DETECT_SRC="(ninguna)"
    warn "No se detectaron salidas para '$comp': la región quedará vacía y el compositor hará autoconfig."
    return 1
  fi
  pack_positions
  log "$comp: ${#OUT_NAME[@]} salida(s) detectada(s) vía $DETECT_SRC"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Rutas y marcadores por compositor
# ─────────────────────────────────────────────────────────────────────────────
config_file() {
  case "$1" in
    hypr)    printf '%s\n' "$CONFIG_HOME/hypr/hyprland.lua" ;;
    sway)    printf '%s\n' "$CONFIG_HOME/sway/config" ;;
    umbriel) printf '%s\n' "$CONFIG_HOME/umbriel/config.toml" ;;
    niri)    printf '%s\n' "$CONFIG_HOME/niri/config.d/90-user-extra.kdl" ;;
  esac
}

config_dir() {
  case "$1" in
    hypr)    printf '%s\n' "$CONFIG_HOME/hypr" ;;
    sway)    printf '%s\n' "$CONFIG_HOME/sway" ;;
    umbriel) printf '%s\n' "$CONFIG_HOME/umbriel" ;;
    niri)    printf '%s\n' "$CONFIG_HOME/niri" ;;
  esac
}

marker_open() {
  case "$1" in
    hypr)           printf '%s\n' '-- >>> autoconf-monitor >>>' ;;
    sway|umbriel)   printf '%s\n' '# >>> autoconf-monitor >>>' ;;
    niri)           printf '%s\n' '// >>> autoconf-monitor >>>' ;;
  esac
}

marker_close() {
  case "$1" in
    hypr)           printf '%s\n' '-- <<< autoconf-monitor <<<' ;;
    sway|umbriel)   printf '%s\n' '# <<< autoconf-monitor <<<' ;;
    niri)           printf '%s\n' '// <<< autoconf-monitor <<<' ;;
  esac
}

mode_of() {
  printf '%sx%s@%s' "${OUT_W[$1]}" "${OUT_H[$1]}" "${OUT_R[$1]}"
}

# gen_region <comp> — marcadores + bloque(s) generados.
# Sin salidas detectadas: solo marcadores (región vacía).
gen_region() {
  local comp="$1" i n
  n=${#OUT_NAME[@]}
  marker_open "$comp"
  case "$comp" in
    hypr)
      for ((i = 0; i < n; i++)); do
        printf 'hl.monitor({\n    output   = "%s",\n    mode     = "%s",\n    position = "%sx%s",\n    scale    = "%s",\n})\n' \
          "${OUT_NAME[i]}" "$(mode_of "$i")" "${POS_X[i]}" "${POS_Y[i]}" "${OUT_S[i]}"
      done
      ;;
    sway)
      for ((i = 0; i < n; i++)); do
        printf 'output %s resolution %sx%s@%sHz position %s,%s scale %s\n' \
          "${OUT_NAME[i]}" "${OUT_W[i]}" "${OUT_H[i]}" "${OUT_R[i]}" \
          "${POS_X[i]}" "${POS_Y[i]}" "${OUT_S[i]}"
      done
      ;;
    umbriel)
      for ((i = 0; i < n; i++)); do
        printf '[output."%s"]\nenabled = true\nmode = "%s"\nposition = [%s, %s]\nscale = %s\n' \
          "${OUT_NAME[i]}" "$(mode_of "$i")" "${POS_X[i]}" "${POS_Y[i]}" "${OUT_S[i]}"
      done
      ;;
    niri)
      for ((i = 0; i < n; i++)); do
        printf 'output "%s" {\n    mode "%s"\n    scale %s\n    position x=%s y=%s\n}\n' \
          "${OUT_NAME[i]}" "$(mode_of "$i")" "${OUT_S[i]}" "${POS_X[i]}" "${POS_Y[i]}"
      done
      ;;
  esac
  marker_close "$comp"
}

# ─────────────────────────────────────────────────────────────────────────────
# Reescritura idempotente
# ─────────────────────────────────────────────────────────────────────────────
has_markers() {
  local file="$1" open="$2" close="$3" ol cl
  [[ -f "$file" ]] || return 1
  ol="$(grep -n -F -x -- "$open" "$file" 2>/dev/null | head -n 1 | cut -d: -f1)"
  cl="$(grep -n -F -x -- "$close" "$file" 2>/dev/null | head -n 1 | cut -d: -f1)"
  [[ -n "$ol" && -n "$cl" && "$cl" -gt "$ol" ]]
}

hardcode_present() {
  local comp="$1" file="$2"
  [[ -f "$file" ]] || return 1
  case "$comp" in
    hypr)    grep -q '^[[:space:]]*hl\.monitor[[:space:]]*(' "$file" ;;
    sway)    grep -q '^[[:space:]]*output[[:space:]]' "$file" ;;
    umbriel) grep -q '^[[:space:]]*#[[:space:]]*\[output\.' "$file" ;;
    niri)    grep -q '^[[:space:]]*output[[:space:]]*"' "$file" ;;
    *)       return 1 ;;
  esac
}

# write_via_awk <archivo> <programa-awk> <region>
write_via_awk() {
  local file="$1" prog="$2" region="$3" tmp
  tmp="$(mktemp)" || return 1
  printf '%s\n' "$region" > "$tmp"
  if awk -v rf="$tmp" "$prog" "$file" > "$tmp.out"; then
    cat "$tmp.out" > "$file"
    rm -f "$tmp" "$tmp.out"
    return 0
  fi
  rm -f "$tmp" "$tmp.out"
  return 1
}

AWK_BUF='BEGIN { while ((getline l < rf) > 0) buf = buf l "\n"; close(rf) }'

replace_markers() {
  local file="$1" open="$2" close="$3" region="$4"
  local prog
  prog="$AWK_BUF"'
    {
      if (!done && $0 == o) { printf "%s", buf; skip = 1; done = 1; next }
      if (skip) { if ($0 == c) skip = 0; next }
      print
    }
    END { exit (done ? 0 : 1) }'
  local tmp
  tmp="$(mktemp)" || return 1
  printf '%s\n' "$region" > "$tmp"
  if awk -v o="$open" -v c="$close" -v rf="$tmp" "$prog" "$file" > "$tmp.out"; then
    cat "$tmp.out" > "$file"
    rm -f "$tmp" "$tmp.out"
    return 0
  fi
  rm -f "$tmp" "$tmp.out"
  return 1
}

replace_hardcode() {
  local comp="$1" file="$2" region="$3" prog
  case "$comp" in
    hypr)
      prog="$AWK_BUF"'
        {
          if (!done && $0 ~ /^[ \t]*hl\.monitor[ \t]*\(/) { printf "%s", buf; skip = 1; done = 1; next }
          if (skip) { if ($0 ~ /^[ \t]*}\)[ \t]*$/) skip = 0; next }
          print
        }
        END { exit (done ? 0 : 1) }'
      ;;
    sway)
      prog="$AWK_BUF"'
        {
          if (!done && $0 ~ /^[ \t]*output[ \t]+/) { printf "%s", buf; done = 1; next }
          print
        }
        END { exit (done ? 0 : 1) }'
      ;;
    umbriel)
      prog="$AWK_BUF"'
        {
          if (!done && $0 ~ /^[ \t]*#[ \t]*\[output\./) { printf "%s", buf; skip = 1; done = 1; next }
          if (skip) {
            if ($0 ~ /^# .*─/ || ($0 !~ /^[ \t]*#/ && $0 ~ /[^ \t]/)) { skip = 0; print }
            next
          }
          print
        }
        END { exit (done ? 0 : 1) }'
      ;;
    niri)
      prog="$AWK_BUF"'
        {
          if (!done && $0 ~ /^[ \t]*output[ \t]+"/) { printf "%s", buf; skip = 1; done = 1; next }
          if (skip) { if ($0 ~ /^[ \t]*}[ \t]*$/) skip = 0; next }
          print
        }
        END { exit (done ? 0 : 1) }'
      ;;
    *) return 1 ;;
  esac
  write_via_awk "$file" "$prog" "$region"
}

# insert_after_header — si hay cabecera "MONITORS", inserta la región tras ella.
insert_after_header() {
  local file="$1" region="$2" prog
  grep -q 'MONITORS' "$file" 2>/dev/null || return 1
  prog="$AWK_BUF"'
    {
      print
      if (!done && $0 ~ /MONITORS/) { printf "%s", buf; done = 1 }
    }
    END { exit (done ? 0 : 1) }'
  write_via_awk "$file" "$prog" "$region"
}

# structure_ok <file> <comp> — comprueba que la estructura está balanceada
# antes de añadir la región al final (importante en hyprland.lua).
structure_ok() {
  local file="$1" comp="$2"
  case "$comp" in
    umbriel) return 0 ;;  # TOML: añadir una tabla al final siempre es válido
    hypr)
      awk '{
        l = $0; gsub(/"[^"]*"/, "", l); sub(/--.*$/, "", l)
        no += gsub(/\{/, "", l); nc += gsub(/\}/, "", l)
        po += gsub(/\(/, "", l); pc += gsub(/\)/, "", l)
        bo += gsub(/\[/, "", l); bc += gsub(/\]/, "", l)
      } END { exit !((no == nc) && (po == pc) && (bo == bc)) }' "$file"
      ;;
    sway)
      awk '{
        l = $0; gsub(/"[^"]*"/, "", l); sub(/#.*$/, "", l)
        no += gsub(/\{/, "", l); nc += gsub(/\}/, "", l)
      } END { exit !(no == nc) }' "$file"
      ;;
    niri)
      awk '{
        l = $0; gsub(/"[^"]*"/, "", l); sub(/\/\/.*$/, "", l)
        no += gsub(/\{/, "", l); nc += gsub(/\}/, "", l)
        po += gsub(/\(/, "", l); pc += gsub(/\)/, "", l)
      } END { exit !((no == nc) && (po == pc)) }' "$file"
      ;;
    *) return 1 ;;
  esac
}

append_region() {
  local file="$1" region="$2"
  printf '\n' >> "$file"
  printf '%s\n' "$region" >> "$file"
}

process_file() {
  local comp="$1" file cdir open close region how
  file="$(config_file "$comp")"
  cdir="$(config_dir "$comp")"
  open="$(marker_open "$comp")"
  close="$(marker_close "$comp")"
  region="$(gen_region "$comp")"

  if (( DRY_RUN )); then
    if has_markers "$file" "$open" "$close"; then
      how="reemplazaría la región marcada"
    elif [[ -f "$file" ]] && hardcode_present "$comp" "$file"; then
      how="sustituiría el bloque hardcodeado y lo envolvería con marcadores"
    elif [[ -f "$file" ]]; then
      how="añadiría la región marcada en ubicación sintácticamente válida"
    else
      how="crearía el fichero con la región marcada"
    fi
    log "--dry-run [$comp] $file — $how"
    printf '%s\n' "$region" | sed 's/^/    /'
    return 0
  fi

  if [[ ! -f "$file" ]]; then
    if [[ -d "$cdir" ]]; then
      mkdir -p "$(dirname "$file")"
      printf '%s\n' "$region" > "$file"
      log "$comp: creado $file (no existía) con la región autoconf."
      return 0
    fi
    warn "$comp: no existe $file ni $cdir; se omite (el compositor usará autoconfig)."
    return 1
  fi

  if has_markers "$file" "$open" "$close"; then
    if replace_markers "$file" "$open" "$close" "$region"; then
      log "$comp: región marcada regenerada en $file"
      return 0
    fi
    warn "$comp: fallo al regenerar la región marcada de $file"
    return 1
  fi

  if replace_hardcode "$comp" "$file" "$region"; then
    log "$comp: bloque hardcodeado sustituido (ahora con marcadores) en $file"
    return 0
  fi

  if [[ "$comp" == "hypr" || "$comp" == "sway" ]] && insert_after_header "$file" "$region"; then
    log "$comp: región insertada tras la cabecera MONITORS de $file"
    return 0
  fi

  if ! structure_ok "$file" "$comp"; then
    warn "$comp: $file tiene la estructura no balanceada; no se añade la región (revísala a mano)."
    return 1
  fi
  append_region "$file" "$region"
  log "$comp: región marcada añadida al final de $file"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
main() {
  while (( $# > 0 )); do
    case "$1" in
      --dry-run)  DRY_RUN=1 ;;
      --headless) HEADLESS=1 ;;
      -h|--help)  usage; exit 0 ;;
      hypr|sway|umbriel|niri) COMPS+=("$1") ;;
      *) printf '[ERROR] Argumento desconocido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done

  if (( ${#COMPS[@]} == 0 )); then
    COMPS=(hypr sway umbriel niri)
  fi

  init_json_backend
  log "Config home: $CONFIG_HOME"
  (( DRY_RUN )) && log "Modo --dry-run: no se escribe nada."
  (( HEADLESS )) && log "Modo --headless: detección por /sys/class/drm."

  local comp rc=0
  for comp in "${COMPS[@]}"; do
    detect_for "$comp" || true   # sin salidas: región vacía + warn (no fatal)
    process_file "$comp" || rc=1
  done

  if (( rc == 0 )); then
    log "autoconf-monitor completado (${#COMPS[@]} compositor(es))."
  else
    warn "autoconf-monitor terminó con avisos/errores (ver mensajes anteriores)."
  fi
  exit "$rc"
}

# Solo ejecuta main si se invoca como script (permite source para tests).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
