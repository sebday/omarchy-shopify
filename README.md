# Omarchy Shopify Plugin

![TUI dashboard](preview.png)

![Bar popup](preview2.png)

Bar widget for Shopify store revenue: today's KPIs and a sparkline for every store in the data source.

## Install

```bash
omarchy plugin add https://github.com/sebday/omarchy-shopify.git
omarchy plugin enable evo.shopify
```

## Requirements

- `jq` and `curl` on `PATH`
- `pass show omarchy/ecommerce-data/api-token` (or `ECOMMERCE_API_TOKEN` in `~/work/ecommerce-data/.env`)

### Worker API

```json
"shopify": {
  "apiUrl": "https://data.day.marketing",
  "pollIntervalMinutes": 5,
  "timezone": "Europe/London",
  "stores": [
    { "key": "DIY", "title": "DIY" },
    { "key": "TGS", "title": "TGS" }
  ]
}
```

`apiUrl` points at the Worker. You can omit it if `ECOMMERCE_API_URL` is set in `~/work/ecommerce-data/.env`. Auth is bearer-only — token from `pass show omarchy/ecommerce-data/api-token`, `~/work/ecommerce-data/.env`, or `shopify.apiToken` in `shell.json`.

Stores are discovered from `GET /v1/sites` when `stores` is omitted. Optional `adminSlug` links to the Shopify admin. Favicon files in `~/.cache/omarchy/shopify-icons/` are named `{iconKey}.favicon.png` (defaults to lowercase `key`).

## Dashboard

```bash
go build -o ~/.local/bin/evoshopify ./cmd/evoshopify
evoshopify
```

| Key | Action |
|---|---|
| `q` / `esc` | Quit |
| `r` | Refresh |
| `d` | Toggle demo data from `demo.json` |
| Tab | Previous / next stat |

Demo data lives in `demo.json` at the plugin root. `shopify-status demo` prints the same snapshot for the bar popup and TUI.

## IPC

```bash
omarchy-shell shell toggle evo.shopify '{}'
omarchy-shell evo.shopify refresh
```
