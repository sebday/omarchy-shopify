#!/usr/bin/env bash
# Local cache and heatmap helpers for evo.shopify.

EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/bar}"
EVO_SHOPIFY_ICON_DIR="${EVO_SHOPIFY_ICON_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/shopify-icons}"
EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"

declare -gA GITHUB_COLORS=()

evo_worker_api_token() {
  local token=""
  token="$(pass show omarchy/ecommerce-data/api-token 2>/dev/null || true)"
  [[ -n "$token" ]] || return 1
  case "$token" in *'"'*|*\\*|$'\n'*) return 1 ;; esac
  printf '%s' "$token"
}

evo_worker_curl() {
  local url=$1 token max=1048576 resp
  token="$(evo_worker_api_token)" || return 1
  [[ $url == https://* ]] || return 1
  resp=$(
    printf '%s\n' "header = \"Authorization: Bearer ${token}\"" \
      | /usr/bin/curl -q -sS --fail --config - \
          --proto '=https' --proto-redir '=https' \
          --max-time 25 --connect-timeout 5 --max-filesize "$max" --noproxy '*' \
          -- "$url" \
      | /usr/bin/head -c $((max + 1))
  ) || return 1
  [ ${#resp} -le "$max" ] || return 1
  printf '%s' "$resp"
}

evo_worker_post() {
  local url=$1 token max=1048576 resp
  token="$(evo_worker_api_token)" || return 1
  [[ $url == https://* ]] || return 1
  resp=$(
    printf '%s\n' \
      "header = \"Authorization: Bearer ${token}\"" \
      'header = "Content-Type: application/json"' \
      | /usr/bin/curl -q -sS --fail --config - \
          --proto '=https' --proto-redir '=https' \
          --max-time 120 --connect-timeout 5 --max-filesize "$max" --noproxy '*' \
          -X POST -- "$url" \
      | /usr/bin/head -c $((max + 1))
  ) || return 1
  [ ${#resp} -le "$max" ] || return 1
  printf '%s' "$resp"
}

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

evo_private_dir() {
  local dir="$1"
  mkdir -p -m 700 "$dir" || return 1
  [[ ! -L "$dir" ]] || return 1
  [[ -d "$dir" ]] || return 1
  [[ "$(stat -c %u "$dir")" == "$(id -u)" ]] || return 1
  find "$dir" -mindepth 1 -maxdepth 1 ! -type f -exec rm -rf -- {} + 2>/dev/null || true
  find "$dir" -mindepth 1 -maxdepth 1 -type f -exec chmod 600 -- {} + 2>/dev/null || true
}

evo_read_bounded() {
  local file="$1" max="${2:-65536}" data
  [[ -e "$file" ]] || return 1
  data=$(/usr/bin/dd if="$file" iflag=nofollow,nonblock,count_bytes,fullblock bs=1 count=$((max + 1)) status=none) || return 1
  [ ${#data} -le "$max" ] || return 1
  printf '%s' "$data"
}

evo_bar_cache_read_any() {
  local key="$1" path content
  path="$(evo_bar_cache_path "$key")"
  content="$(evo_read_bounded "$path")" || return 1
  [[ -n "${content//[[:space:]]/}" ]] || return 1
  printf '%s' "$content"
}

evo_bar_cache_read() {
  local key="$1" ttl="${2:-60}"
  local path now mtime age content
  path="$(evo_bar_cache_path "$key")"
  [[ -e "$path" ]] || return 1
  now=$(date +%s)
  mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
  age=$((now - mtime))
  (( age < ttl )) || return 1
  content="$(evo_read_bounded "$path")" || return 1
  [[ -n "${content//[[:space:]]/}" ]] || return 1
  printf '%s' "$content"
}

evo_bar_cache_write() {
  local key="$1" path tmp
  evo_private_dir "$EVO_BAR_CACHE_DIR" || return 1
  path="$(evo_bar_cache_path "$key")"
  umask 077
  tmp="$(/usr/bin/mktemp -p "$EVO_BAR_CACHE_DIR" .cache.XXXXXXXXXX)" || return 1
  cat >"$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -T -- "$tmp" "$path"
}

evo_resolve_icon_path() {
  local icon_key=$1
  local path cache_home
  [[ -n "$icon_key" ]] || return 1
  cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  for path in \
    "${EVO_SHOPIFY_ICON_DIR}/${icon_key}.favicon.png" \
    "${cache_home}/omarchy/shopify-icons/${icon_key}.favicon.png" \
    "${cache_home}/omarchy/shopify-data/${icon_key}.favicon.png"
  do
    [[ -n "$path" && -f "$path" ]] || continue
    readlink -f "$path"
    return 0
  done
  return 1
}

evo_valid_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}
