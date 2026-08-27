# Omarchy Shopify Plugin

Bar widget for Shopify store revenue: today's KPIs and a sparkline for every store in the data directory.

## Install

A plugin is a git repo with a `manifest.json` at its root. Adding one clones it into `~/.config/omarchy/plugins/evo.shopify/`.

```bash
omarchy plugin add https://github.com/sebday/omarchy-plugin-shopify.git
omarchy plugin enable evo.shopify
```

A local path works the same way.

Plugins run as unsandboxed code inside `omarchy-shell`. Review the files before enabling.

## Requirements

- `sqlite3` and `jq` on `PATH`
- One `*.sqlite` file per store (ecommerce-data KPI dumps)
- Optional `shopify` block in `~/.config/omarchy/shell.json`:

```json
"shopify": {
  "sqliteDir": "~/.cache/omarchy/shopify-data",
  "timezone": "Europe/London",
  "remote": "user@host:~/projects/ecommerce-data/data"
}
```

Stores are discovered from `*.sqlite` files in `sqliteDir`. To set titles and admin links, list them under `shopify.stores`:

```json
"stores": [
  { "key": "DIY", "title": "DIY", "adminSlug": "your-store", "sqliteKey": "diy" }
]
```

`remote` is an `rsync` source used to refresh the local sqlite copies.

## Bar

| Click | Action |
|---|---|
| Left | Refresh status |

The bar icon follows theme colours:

| State | Appearance |
|---|---|
| Revenue today | Accent |
| Store or config error | Urgent |
| Loading | Busy |
| No stores | Dimmed |

Hover shows today's revenue and CoS for each store.

## IPC

```bash
omarchy-shell evo.shopify refresh
```

| Call | Action |
|---|---|
| `refresh` | Refresh status |
