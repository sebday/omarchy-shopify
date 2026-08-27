#!/usr/bin/env bash
# Local cache and heatmap helpers for evo.shopify.

EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/bar}"
EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"

declare -gA GITHUB_COLORS=()

evo_bar_load_heatmap_colors() {
  declare -gA GITHUB_COLORS=()
  local i color
  if [[ -f "$EVO_BAR_THEME_CSS" ]]; then
    for i in {0..4}; do
      color=$(grep "@define-color github-$i" "$EVO_BAR_THEME_CSS" | awk '{print $3}' | tr -d ';' || true)
      [[ -n "$color" ]] && GITHUB_COLORS[$i]="$color"
    done
  fi
  : "${GITHUB_COLORS[0]:=#45475a}"
  : "${GITHUB_COLORS[1]:=#89b4fa}"
  : "${GITHUB_COLORS[2]:=#74c7ec}"
  : "${GITHUB_COLORS[3]:=#89dceb}"
  : "${GITHUB_COLORS[4]:=#cba6f7}"
}

evo_bar_cache_path() {
  printf '%s/%s.json' "$EVO_BAR_CACHE_DIR" "$1"
}

evo_bar_cache_read() {
  local key="$1" ttl="${2:-60}"
  local path now mtime age content
  path="$(evo_bar_cache_path "$key")"
  [[ -f "$path" ]] || return 1
  content="$(cat "$path")"
  [[ -n "${content//[[:space:]]/}" ]] || return 1
  now=$(date +%s)
  mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
  age=$((now - mtime))
  (( age < ttl )) || return 1
  printf '%s' "$content"
}

evo_bar_cache_write() {
  local key="$1" path tmp
  mkdir -p "$EVO_BAR_CACHE_DIR"
  path="$(evo_bar_cache_path "$key")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat >"$tmp"
  mv "$tmp" "$path"
}

evo_resolve_icon_path() {
  local sqlite_key="$1" base="$2"
  local path
  [[ -n "$sqlite_key" && -n "$base" ]] || return 1
  path="${base%/}/${sqlite_key}.favicon.png"
  [[ -f "$path" ]] || return 1
  readlink -f "$path"
}
