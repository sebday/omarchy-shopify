#!/usr/bin/env bash
# Local cache and heatmap helpers for evo.shopify.

EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/bar}"
EVO_SHOPIFY_ICON_DIR="${EVO_SHOPIFY_ICON_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/shopify-icons}"
EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"

EVO_SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8)

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

evo_bar_cache_read_any() {
  local key="$1" path content
  path="$(evo_bar_cache_path "$key")"
  [[ -f "$path" ]] || return 1
  content="$(cat "$path")"
  [[ -n "${content//[[:space:]]/}" ]] || return 1
  printf '%s' "$content"
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
  local sqlite_key=$1 base=${2:-}
  local path cache_home
  [[ -n "$sqlite_key" ]] || return 1
  cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  for path in \
    "${EVO_SHOPIFY_ICON_DIR}/${sqlite_key}.favicon.png" \
    "${cache_home}/omarchy/shopify-data/${sqlite_key}.favicon.png" \
    "${base:+${base%/}/${sqlite_key}.favicon.png}"
  do
    [[ -n "$path" && -f "$path" ]] || continue
    readlink -f "$path"
    return 0
  done
  return 1
}

evo_ssh_run() {
  local target=$1
  shift
  ssh "${EVO_SSH_OPTS[@]}" "$target" "$@"
}

# Produce a remote-shell path expression without expanding ~ locally.
evo_remote_path_expr() {
  local path=$1
  if [[ "$path" == "~/"* ]]; then
    printf '$HOME/%s' "${path:2}"
  elif [[ "$path" == "~" ]]; then
    printf '$HOME'
  else
    printf '%s' "$path"
  fi
}

evo_resolve_remote_dir() {
  local target=$1 dir=$2 expr resolved
  expr=$(evo_remote_path_expr "$dir")
  resolved=$(evo_ssh_run "$target" "readlink -f ${expr}" 2>/dev/null | tr -d '\r')
  [[ -n "$resolved" ]] || return 1
  printf '%s' "$resolved"
}

evo_valid_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}
