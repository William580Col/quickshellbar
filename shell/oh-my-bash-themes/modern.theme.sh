#! bash oh-my-bash.module
# modern — a clean two-line prompt with nerd-font glyphs and git status.
# Segments: user@host  directory  (git branch)  time
#
# Colors are read from Aether (~/.config/aether/theme/colors.toml) so the
# prompt follows the wallpaper palette; falls back to a built-in palette
# when that file is not available.
#
# NOTE: no se usan arrays asociativos con claves como "red"/"cyan" porque
# colisionan con los namerefs de colores deprecados de OMB y bash intenta
# evaluarlos como aritmética.

AETHER_COLORS="${AETHER_COLORS:-$HOME/.config/aether/theme/colors.toml}"

PROMPT_DIRTRIM=2

_aether_keycache=""
_aether_mtime=""

_aether_reload() {
  local conf="$AETHER_COLORS" line mt
  [[ -r $conf ]] || { _aether_keycache=""; _aether_mtime=""; return 1; }
  mt=$(stat -c %Y "$conf" 2>/dev/null)
  if [[ -n $_aether_mtime && $_aether_mtime == "$mt" ]]; then
    return 0
  fi
  _aether_keycache=""
  while IFS= read -r line; do
    if [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\"#([0-9a-fA-F]{6})\" ]]; then
      _aether_keycache+=" ${BASH_REMATCH[1]}=#${BASH_REMATCH[2]}"
    fi
  done < "$conf"
  _aether_mtime=$mt
  [[ -n $_aether_keycache ]]
}

_aether_get() { # _aether_get KEY FALLBACK_HEX
  local key=$1 fallback=$2 rest
  rest=${_aether_keycache#*" $key="#}
  if [[ $rest != "$_aether_keycache" ]]; then
    echo "#${rest:0:6}"
    return
  fi
  echo "$fallback"
}

_aether_col() { # _aether_col HEX [38|48] [attrs]
  local h=$1 m=${2:-38} a=${3:-} p=
  [[ -n $a ]] && p="${a};"
  printf '\e[%s%s;2;%d;%d;%dm' "$p" "$m" $((16#${h:1:2})) $((16#${h:3:2})) $((16#${h:5:2}))
}

function _omb_theme_PROMPT_COMMAND() {
  local rc=$?
  local S=$'\x01' E=$'\x02'
  local r=$'\e[0m'
  local dim="${S}\e[2m${E}"

  local cw pur txt ok err
  local b_user b_user_fg b_dir b_dir_fg b_git b_git_fg b_time b_time_fg

  if _aether_reload; then
    local lbg=$(_aether_get lighter_bg "#241f1d")
    local mbg=$(_aether_get bg "#0c0604")
    local dbg=$(_aether_get dark_bg "#090503")
    local kbg=$(_aether_get darker_bg "#060302")

    cw="${S}$(_aether_col "$(_aether_get foreground '#EEAB61')" 38 1)${E}"
    pur="${S}$(_aether_col "$(_aether_get accent '#b4666c')" 38 1)${E}"
    txt="${S}$(_aether_col "$(_aether_get color15 '#fef3ec')")${E}"
    ok="${S}$(_aether_col "$(_aether_get green '#edb96e')" 38 1)${E}"
    err="${S}$(_aether_col "$(_aether_get red '#c48465')" 38 1)${E}"

    b_user="${S}$(_aether_col "$lbg" 48)${E}";  b_user_fg="${S}$(_aether_col "$lbg" 38)${E}"
    b_dir="${S}$(_aether_col "$mbg" 48)${E}";   b_dir_fg="${S}$(_aether_col "$mbg" 38)${E}"
    b_git="${S}$(_aether_col "$dbg" 48)${E}";   b_git_fg="${S}$(_aether_col "$dbg" 38)${E}"
    b_time="${S}$(_aether_col "$kbg" 48)${E}";  b_time_fg="${S}$(_aether_col "$kbg" 38)${E}"
  else
    cw="${S}\e[1;38;5;255m${E}"
    pur="${S}\e[38;5;141m${E}"
    txt="${S}\e[38;5;253m${E}"
    ok="${S}\e[1;38;5;82m${E}"
    err="${S}\e[1;38;5;203m${E}"
    b_user="${S}\e[48;5;24m${E}";    b_user_fg="${S}\e[38;5;24m${E}"
    b_dir="${S}\e[48;5;239m${E}";    b_dir_fg="${S}\e[38;5;239m${E}"
    b_git="${S}\e[48;5;236m${E}";    b_git_fg="${S}\e[38;5;236m${E}"
    b_time="${S}\e[48;5;235m${E}";   b_time_fg="${S}\e[38;5;235m${E}"
  fi

  # nerd-font glyphs
  local i_user=$'\uf007'   #  user
  local i_dir=$'\uf07c'    #  folder
  local i_git=$'\ue725'    #  git branch
  local i_time=$'\uf017'   #  clock
  local sep=$'\ue0b0'      #  powerline right triangle
  local x=$'\u2715'        # ✕ dirty
  local arr=$'\u276f'      # ❯ prompt
  local dot=$'\u25cf'      # ● error dot

  local userchip="${b_user}${cw} ${i_user} \u@\h "
  local dirchip="${b_dir}${cw} ${i_dir} \w "
  local timechip="${dim}${txt} ${i_time} \t${E}${r}"

  local git_seg="" time_git=""
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch; branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z $branch ]] && branch="HEAD"
    local dirty=""
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      dirty="${err} ${x}"
    fi
    git_seg="${b_dir_fg}${b_git}${sep}"
    git_seg+="${b_git} ${pur}${i_git} ${branch}${dirty} "
    time_git=""
  else
    git_seg=""
    time_git=""
  fi

  if [[ $rc -eq 0 ]]; then
    local arrow="${ok}${arr}${E}"
  else
    local arrow="${err}${arr}${E}${err}${dot}${E} ${rc}"
  fi

  PS1="${userchip}${b_user_fg}${b_dir}${sep}${dirchip}${git_seg}${time_git}${timechip}\n${arrow} ${r}"

  history -a
}

_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND