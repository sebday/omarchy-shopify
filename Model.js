.pragma library

var DEFAULT_HEATMAP_COLORS = ["#45475a", "#89b4fa", "#74c7ec", "#89dceb", "#cba6f7"]

function heatmapColors(accent) {
  var accentColor = String(accent || "#89b4fa")
  return [
    DEFAULT_HEATMAP_COLORS[0],
    accentColor,
    DEFAULT_HEATMAP_COLORS[2],
    DEFAULT_HEATMAP_COLORS[3],
    DEFAULT_HEATMAP_COLORS[4]
  ]
}

function chartPalette(accent, urgent) {
  var colors = heatmapColors(accent)
  return [
    colors[1],
    colors[2],
    colors[3],
    String(urgent || "#f38ba8")
  ]
}

function formatRevenue(val, symbol) {
  var n = Math.round(parseFloat(val) || 0)
  var s = String(n)
  var out = ""
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += ","
    out += s.charAt(i)
  }
  return String(symbol || "£") + out
}

function formatDay(dateStr) {
  var text = String(dateStr || "").trim()
  if (!text) return ""
  var parts = text.split("-")
  if (parts.length !== 3) return text
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var month = parseInt(parts[1], 10)
  var day = parseInt(parts[2], 10)
  if (isNaN(month) || isNaN(day) || month < 1 || month > 12) return text
  return months[month - 1] + " " + day
}

function parseStorePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data" }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response" }
  }

  return normalizeStorePayload(json)
}

function normalizeStorePayload(json) {
  if (!json || typeof json !== "object") return { ok: false, error: "No data" }

  if (json.class === "error" || (json.text && !json.bars && json.revenue === undefined && !json.todayDetail)) {
    return {
      ok: false,
      error: String(json.tooltip || json.text || "Shopify error").replace(/<[^>]+>/g, "").trim()
    }
  }

  return {
    ok: true,
    text: String(json.text || ""),
    label: String(json.label || json.text || ""),
    symbol: String(json.symbol || "£"),
    orders: parseInt(json.orders, 10) || 0,
    cos: String(json.cos || ""),
    revenue: parseFloat(json.revenue) || 0,
    todayDetail: json.todayDetail && typeof json.todayDetail === "object" ? json.todayDetail : {},
    period: json.period && typeof json.period === "object" ? json.period : {},
    bars: Array.isArray(json.bars) ? json.bars : []
  }
}

function parseSnapshot(raw) {
  var text = String(raw || "").trim()
  if (!text) return { stores: [], payloads: {} }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { stores: [], payloads: {} }
  }

  var stores = []
  var list = Array.isArray(json.stores) ? json.stores : []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i] || {}
    var key = String(entry.key || "").trim()
    if (!key) continue
    stores.push({
      key: key,
      title: String(entry.title || key),
      adminSlug: String(entry.adminSlug || ""),
      sqliteKey: String(entry.sqliteKey || key.toLowerCase()),
      iconPath: String(entry.iconPath || "")
    })
  }

  var payloads = {}
  var src = json.payloads && typeof json.payloads === "object" ? json.payloads : {}
  for (var payloadKey in src) {
    if (!Object.prototype.hasOwnProperty.call(src, payloadKey)) continue
    payloads[payloadKey] = normalizeStorePayload(src[payloadKey])
  }

  return { stores: stores, payloads: payloads }
}

function themeBarArray(bars, palette) {
  if (!Array.isArray(bars)) return []
  var colors = palette && palette.length ? palette : DEFAULT_HEATMAP_COLORS
  var out = []
  for (var i = 0; i < bars.length; i++) {
    var bar = Object.assign({}, bars[i])
    var level = parseInt(bar.colorLevel, 10)
    if (!isNaN(level) && level >= 0 && level < colors.length)
      bar.color = colors[level]
    out.push(bar)
  }
  return out
}

function kpiHeroMeta(todayDetail, hasLiveAnalyticsLink) {
  var detail = todayDetail || {}
  var date = String(detail.date || "").trim()
  var calendarDate = String(detail.calendarDate || "").trim()
  var parts = []
  if (date && calendarDate && date !== calendarDate) {
    var label = formatDay(date)
    if (label) parts.push("As of " + label)
  }
  if (hasLiveAnalyticsLink) parts.push("Live analytics")
  return parts.length > 0 ? parts.join(" · ") : "Shopify"
}

function statTodayRevenue(storeData, todayDetail, currency) {
  var rev = todayDetail && todayDetail.revenue
  if (rev !== undefined && rev !== null) return formatRevenue(rev, currency)
  if (storeData && storeData.revenue !== undefined && storeData.revenue !== null)
    return formatRevenue(storeData.revenue, currency)
  return "—"
}

function statOrders(todayDetail, storeData) {
  if (todayDetail && todayDetail.orders !== undefined && todayDetail.orders !== null)
    return String(todayDetail.orders)
  if (storeData && storeData.orders !== undefined && storeData.orders !== null)
    return String(storeData.orders)
  return "—"
}

function barTooltipFromStore(data) {
  if (!data || !data.ok) {
    if (data && data.error) return String(data.error).replace(/<[^>]+>/g, "").trim()
    return ""
  }
  if (data.label) return data.label
  if (data.text) return String(data.text).replace(/<[^>]+>/g, "").trim()
  return "Shopify"
}

function barTooltipFromStores(storeDefs, payloads) {
  var defs = storeDefs || []
  var map = payloads || {}
  if (defs.length === 0) return "Shopify"
  var lines = []
  for (var i = 0; i < defs.length; i++) {
    var key = String(defs[i].key || "")
    var line = barTooltipFromStore(map[key])
    if (line) lines.push(line)
  }
  return lines.length > 0 ? lines.join("\n") : "Shopify"
}

function iconActiveFromStore(data) {
  if (!data || !data.ok) return false
  var rev = parseFloat(data.revenue)
  if (!isNaN(rev) && rev > 0) return true
  var today = data.todayDetail || {}
  var todayRev = parseFloat(today.revenue)
  return !isNaN(todayRev) && todayRev > 0
}

function iconFileUrl(path) {
  var p = String(path || "").trim()
  if (!p) return ""
  if (p.indexOf("file://") === 0) return p
  return "file://" + p
}
