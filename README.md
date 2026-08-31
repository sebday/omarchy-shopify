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
- For Worker API mode (recommended): `pass show omarchy/ecommerce-data/api-token`
- Legacy SQLite mode: `sqlite3`, optional `ssh` when `dataPath` is remote

### Worker API (recommended)

```json
"shopify": {
  "apiUrl": "https://data.day.marketing",
  "pollIntervalMinutes": 5,
  "timezone": "Europe/London",
  "stores": [
    { "key": "DIY", "title": "DIY", "sqliteKey": "diy" },
    { "key": "TGS", "title": "TGS", "sqliteKey": "tgs" }
  ]
}
```

`apiUrl` points at the Worker. You can omit it if `ECOMMERCE_API_URL` is set in `~/work/ecommerce-data/.env`. Auth is bearer-only — token from `pass show omarchy/ecommerce-data/api-token`, `~/work/ecommerce-data/.env`, or `shopify.apiToken` in `shell.json`.

### Legacy SQLite over SSH

```json
"shopify": {
  "dataPath": "server:~/work/ecommerce-data/data",
  "timezone": "Europe/London"
}
```

| `dataPath` | Behaviour |
|---|---|
| `host:~/path` | SSH to host |
| `/local/path` | Local read-only sqlite queries |

Stores are auto-discovered from `*.sqlite` files, or list them explicitly:

```json
"stores": [
  { "key": "STORE1", "title": "My Store", "adminSlug": "your-store", "sqliteKey": "store1" }
]
```

## Bar

| Click | Action |
|---|---|
| Left | Toggle status popup |

Left-click opens a compact popup with today's KPIs and a 30-day revenue chart for each store. The bar reads a local cache on startup, then refreshes from the Worker API every `pollIntervalMinutes` (default 5) while the shell is running. Set `shopify.pollIntervalMinutes` in `shell.json` to change the interval.

| State | Appearance |
|---|---|
| Revenue today | Accent |
| Store or config error | Urgent |
| No stores | Dimmed |


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
