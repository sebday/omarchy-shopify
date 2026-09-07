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
- `pass show omarchy/ecommerce-data/api-token`

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

`apiUrl` points at the Worker and must be `https://`. Auth is bearer-only from `pass show omarchy/ecommerce-data/api-token`.

On each poll the panel `POST`s `/v1/sync/today` (1-day Shopify/Ads/GA4, at most every 4 minutes), then reads `GET /v1/sites/:site/kpi/summary`. Stores come from `GET /v1/sites` when `stores` is omitted. Optional `adminSlug` links to the Shopify admin. Favicon files in `~/.cache/omarchy/shopify-icons/` are named `{iconKey}.favicon.png` (defaults to lowercase `key`).

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

## Removing

```bash
omarchy plugin remove evo.shopify
```

That deletes the plugin directory. It does not delete:

- `~/.cache/omarchy/bar/*.json` shopify caches
- `~/.cache/omarchy/shopify-icons/`
- `pass` entry `omarchy/ecommerce-data/api-token`

Network: the configured HTTPS worker origin.
