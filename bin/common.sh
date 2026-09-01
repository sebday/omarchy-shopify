#!/usr/bin/env bash
# Local cache and heatmap helpers for evo.shopify.

EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/bar}"
EVO_SHOPIFY_ICON_DIR="${EVO_SHOPIFY_ICON_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/shopify-icons}"
EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"

declare -gA GITHUB_COLORS=()

evo_load_shopify_env() {
  local f
  for f in \
    "${SHOPIFY_ENV_FILE:-}" \
    "${HOME}/work/ecommerce-data/.env" \
    "${HOME}/projects/ecommerce-data/.env"
  do
    [[ -n "$f" && -f "$f" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
    return 0
  done
  return 1
}

evo_load_shopify_env || true

evo_worker_api_token() {
  local cfg token
  cfg="$(cat "${OMARCHY_SHELL_CONFIG:-$HOME/.config/omarchy/shell.json}" 2>/dev/null || echo '{}')"
  token="$(jq -r '.shopify.apiToken // ""' <<<"$cfg")"
  [[ -n "$token" ]] || token="${ECOMMERCE_API_TOKEN:-}"
  [[ -n "$token" ]] || token="$(pass show omarchy/ecommerce-data/api-token 2>/dev/null || true)"
  [[ -n "$token" ]] || return 1
  printf '%s' "$token"
}

evo_worker_curl() {
  local url=$1 token
  token="$(evo_worker_api_token)" || return 1
  curl -sSf --max-time 25 \
    -H "Authorization: Bearer ${token}" \
    "$url"
}

evo_worker_post() {
  local url=$1 token
  token="$(evo_worker_api_token)" || return 1
  curl -sSf --max-time 120 -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    "$url"
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
