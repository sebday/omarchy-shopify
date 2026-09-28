.pragma library

var MAX_STORES = 16
var MAX_BARS = 400
var MAX_TEXT = 80

var KPI_ORDER = [
  "revenue", "orders", "sessions", "cvr", "aov",
  "cos", "spend", "periodPrev", "periodRevenue", "forecast"
]

var CHARTS = {
  revenue: { id: "revenue", label: "revenue", valueKind: "currency", chartStyle: "bar" },
  orders: { id: "orders", label: "orders", valueKind: "integer", chartStyle: "bar" },
  sessions: { id: "sessions", label: "sessions", valueKind: "integer", chartStyle: "line" },
  cvr: { id: "cvr", label: "CVR", valueKind: "percent", chartStyle: "line" },
  aov: { id: "aov", label: "AoV", valueKind: "currency", chartStyle: "line" },
  cos: { id: "cos", label: "CoS", valueKind: "percent", chartStyle: "line" },
  spend: { id: "spend", label: "ad spend", valueKind: "currency", chartStyle: "line" },
  periodPrev: { id: "periodPrev", label: "prev", valueKind: "currency", chartStyle: "bar" },
  periodRevenue: { id: "periodRevenue", label: "revenue", valueKind: "currency", chartStyle: "bar" },
  forecast: { id: "forecast", label: "forecast", valueKind: "currency", chartStyle: "bar" }
}

var STORE_COLOR_NAMES = { DIY: "cyan", TGS: "bright_green" }
var STORE_COLOR_FALLBACK = ["cyan", "bright_green", "blue", "yellow", "magenta"]
var COLOR_KEYS = [
  "cyan", "bright_green", "blue", "yellow", "magenta",
  "muted", "foreground", "bright_foreground", "background"
]

function plain(value, maxLen) {
  var s = String(value == null ? "" : value)
  var max = maxLen || MAX_TEXT
  var out = ""
  for (var i = 0; i < s.length && out.length < max; i++) {
    var code = s.charCodeAt(i)
    if (code < 32 || (code >= 127 && code < 160)) continue
    if (code >= 0x202A && code <= 0x202E) continue
    if (code >= 0x2066 && code <= 0x2069) continue
    var c = s.charAt(i)
    if (c === "<" || c === ">" || c === "&") continue
    out += c
  }
  return out
}

function finite(v) {
  if (typeof v === "boolean" || v === null || v === undefined) return NaN
  if (typeof v === "string") {
    if (v.length === 0 || v.length > 32) return NaN
    if (!/^-?\d+(\.\d+)?$/.test(v)) return NaN
  } else if (typeof v !== "number") {
    return NaN
  }
  var n = typeof v === "number" ? v : Number(v)
  if (!isFinite(n) || Math.abs(n) > 1e12) return NaN
  return n
}

function finiteOrNull(v) {
  if (v === null || v === undefined || v === "") return null
  var n = finite(v)
  return isFinite(n) ? n : null
}

function intOf(v) {
  var n = finite(v)
  if (!isFinite(n)) return 0
  return Math.round(n)
}

function pickColor(hex, fallback) {
  if (typeof hex === "string" && /^#[0-9A-Fa-f]{6}$/.test(hex)) return hex
  return fallback
}

function sanitizeColors(raw) {
  var out = {}
  if (!raw || typeof raw !== "object") return out
  for (var i = 0; i < COLOR_KEYS.length; i++) {
    var key = COLOR_KEYS[i]
    var hex = pickColor(raw[key], "")
    if (hex) out[key] = hex
  }
  return out
}

function storeColor(key, index, colors, fallback) {
  var k = String(key || "").toUpperCase().replace(/^\s+|\s+$/g, "")
  var name = STORE_COLOR_NAMES[k]
  if (!name) {
    var i = parseInt(index, 10)
    if (!isFinite(i) || i < 0) i = 0
    name = STORE_COLOR_FALLBACK[i % STORE_COLOR_FALLBACK.length]
  }
  return pickColor(colors && colors[name], fallback)
}

function emptyChannels() {
  return { paid: 0, organic: 0, direct: 0, email: 0 }
}

function emptyPayload() {
  return {
    ok: false,
    error: "No data",
    symbol: "£",
    today: { date: "", calendarDate: "", revenue: 0, orders: 0, sessions: 0, cos: "", spend: null, cvr: null },
    period: { days: 0, revenue: 0, prevRevenue: 0 },
    channels: emptyChannels(),
    month: { forecastRevenue: 0 },
    bars: [],
    orderBars: [],
    sessionBars: [],
    spendBars: [],
    cvrBars: [],
    aovBars: [],
    cosBars: []
  }
}

function dateOf(v) {
  var text = plain(v, 32)
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : ""
}

function barsOf(list) {
  if (!Array.isArray(list)) return []
  if (list.length > MAX_BARS) return null
  var out = []
  for (var i = 0; i < list.length; i++) {
    var b = list[i]
    if (!b || typeof b !== "object") continue
    var value = finite(b.value)
    if (!isFinite(value) || value < 0) value = 0
    out.push({ date: dateOf(b.date), value: value })
  }
  return out
}

function normalizePayload(json) {
  var empty = emptyPayload()
  if (!json || typeof json !== "object" || Array.isArray(json)) return empty

  var bars = barsOf(json.bars)
  var orderBars = barsOf(json.orderBars)
  var sessionBars = barsOf(json.sessionBars)
  var spendBars = barsOf(json.spendBars)
  var cvrBars = barsOf(json.cvrBars)
  var aovBars = barsOf(json.aovBars)
  var cosBars = barsOf(json.cosBars)
  if (!bars || !orderBars || !sessionBars || !spendBars || !cvrBars || !aovBars || !cosBars)
    return empty

  var today = json.todayDetail && typeof json.todayDetail === "object" ? json.todayDetail : {}
  var period = json.period && typeof json.period === "object" ? json.period : {}
  var channels = json.channels && typeof json.channels === "object" ? json.channels : {}
  var month = json.month && typeof json.month === "object" ? json.month : {}
  var days = intOf(period.days)
  if (days < 0) days = 0
  if (days > 366) days = 366

  var symbol = plain(json.symbol, 4)
  if (!symbol) symbol = "£"

  var payload = {
    ok: false,
    error: "",
    symbol: symbol,
    today: {
      date: dateOf(today.date),
      calendarDate: dateOf(today.calendarDate),
      revenue: finite(today.revenue) || 0,
      orders: Math.max(0, intOf(today.orders)),
      sessions: Math.max(0, intOf(today.sessions)),
      cos: plain(today.cos, 16),
      spend: finiteOrNull(today.spend),
      cvr: finiteOrNull(today.cvr)
    },
    period: {
      days: days,
      revenue: finite(period.revenue) || 0,
      prevRevenue: finite(period.prevRevenue) || 0
    },
    channels: {
      paid: Math.max(0, finite(channels.paid) || 0),
      organic: Math.max(0, finite(channels.organic) || 0),
      direct: Math.max(0, finite(channels.direct) || 0),
      email: Math.max(0, finite(channels.email) || 0)
    },
    month: { forecastRevenue: Math.max(0, finite(month.forecastRevenue) || 0) },
    bars: bars,
    orderBars: orderBars,
    sessionBars: sessionBars,
    spendBars: spendBars,
    cvrBars: cvrBars,
    aovBars: aovBars,
    cosBars: cosBars
  }

  var revenue = finite(json.revenue) || 0
  var orders = intOf(json.orders)
  payload.ok = payload.today.date !== "" || payload.bars.length > 0 || revenue !== 0 || orders !== 0
  if (!payload.ok) {
    var err = plain(json.text || json.label || "No data", 160)
    payload.error = err || "No data"
  }
  return payload
}

function storeKeyOk(key) {
  if (key === "__proto__" || key === "constructor" || key === "prototype") return false
  return /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(key)
}

function parseSnapshot(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  var empty = { stores: [], payloads: {} }
  if (!text) return empty
  var json
  try { json = JSON.parse(text) } catch (e) { return empty }
  if (!json || typeof json !== "object" || Array.isArray(json)) return empty

  var list = Array.isArray(json.stores) ? json.stores : []
  if (list.length > MAX_STORES) return empty
  var stores = []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i] || {}
    var key = plain(entry.key, 64).replace(/^\s+|\s+$/g, "")
    if (!storeKeyOk(key)) continue
    var title = plain(entry.title || key, MAX_TEXT).replace(/^\s+|\s+$/g, "")
    stores.push({ key: key, title: title || key })
  }

  var src = json.payloads && typeof json.payloads === "object" && !Array.isArray(json.payloads)
    ? json.payloads : {}
  var payloads = {}
  for (var s = 0; s < stores.length; s++) {
    var storeKey = stores[s].key
    payloads[storeKey] = Object.prototype.hasOwnProperty.call(src, storeKey)
      ? normalizePayload(src[storeKey])
      : emptyPayload()
  }
  return { stores: stores, payloads: payloads }
}

function asPayload(p) {
  if (!p || typeof p !== "object" || !Array.isArray(p.bars)) return emptyPayload()
  return p
}

function currency(p) {
  var payload = asPayload(p)
  return payload.symbol || "£"
}

function commaInt(n) {
  var rounded = Math.round(n)
  var neg = rounded < 0
  var s = String(Math.abs(rounded))
  var out = ""
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += ","
    out += s.charAt(i)
  }
  return (neg ? "-" : "") + out
}

function formatRevenue(val, symbol) {
  var n = finite(val)
  if (!isFinite(n)) n = 0
  return (symbol || "£") + commaInt(n)
}

function formatMoney(val, symbol) {
  if (val === null || val === undefined || !isFinite(val) || val <= 0) return "—"
  return formatRevenue(val, symbol)
}

function formatPct(val) {
  if (val === null || val === undefined || !isFinite(val)) return "—"
  return (val * 100).toFixed(1) + "%"
}

function formatInt(n) {
  var v = finite(n)
  if (!isFinite(v)) v = 0
  return commaInt(v)
}

function formatAov(detail, symbol) {
  if (!detail || !detail.orders) return "—"
  return formatRevenue(detail.revenue / detail.orders, symbol)
}

function formatDay(dateStr) {
  var text = String(dateStr || "").replace(/^\s+|\s+$/g, "")
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!m) return ""
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var month = parseInt(m[2], 10)
  var day = parseInt(m[3], 10)
  if (month < 1 || month > 12 || day < 1 || day > 31) return ""
  return months[month - 1] + " " + day
}

function dashIfEmpty(s) {
  var text = String(s || "").replace(/^\s+|\s+$/g, "")
  if (!text || text === "—") return "—"
  return plain(text, 16)
}

function kpiHeroMeta(detail) {
  if (!detail) return ""
  var date = String(detail.date || "")
  var cal = String(detail.calendarDate || "")
  if (date && cal && date !== cal) {
    var label = formatDay(date)
    if (label) return "As of " + label
  }
  return ""
}

function metricById(id) {
  return CHARTS[id] || CHARTS.revenue
}

function barsFor(payload, id) {
  var p = asPayload(payload)
  if (id === "orders") return p.orderBars
  if (id === "sessions") return p.sessionBars
  if (id === "cvr") return p.cvrBars
  if (id === "aov") return p.aovBars
  if (id === "cos") return p.cosBars
  if (id === "spend") return p.spendBars
  return p.bars
}

function metricClickable(payload, id) {
  var p = asPayload(payload)
  if (!p.ok) return false
  if (id === "periodPrev" || id === "periodRevenue" || id === "forecast")
    return p.bars.length > 0
  return barsFor(p, id).length > 0
}

function nextMetric(payload, current, dir) {
  var step = dir === 0 || dir === undefined ? 1 : dir
  var idx = 0
  for (var i = 0; i < KPI_ORDER.length; i++) {
    if (KPI_ORDER[i] === current) { idx = i; break }
  }
  var n = KPI_ORDER.length
  for (var j = 0; j < n; j++) {
    idx = (idx + step + n) % n
    if (metricClickable(payload, KPI_ORDER[idx])) return KPI_ORDER[idx]
  }
  return current
}

function chartHoverLabel(bars, id, symbol) {
  if (!bars || !bars.length) return ""
  var last = bars[bars.length - 1]
  var day = formatDay(last.date)
  var def = metricById(id)
  var value
  if (def.valueKind === "integer") value = formatInt(Math.round(last.value))
  else if (def.valueKind === "percent") value = formatPct(last.value)
  else value = formatRevenue(last.value, symbol)
  return day ? (day + "  " + value) : value
}

function periodDays(p) {
  if (p.period.days > 0) return p.period.days
  if (p.bars.length > 0) return p.bars.length
  return 30
}

function kpiCells(payload, metricId) {
  var p = asPayload(payload)
  if (!p.ok) return []
  var cur = currency(p)
  var d = p.today
  var days = periodDays(p)
  var forecast = p.month.forecastRevenue > 0 ? formatRevenue(p.month.forecastRevenue, cur) : "—"
  var specs = [
    ["revenue", "◆", "Rev.", formatRevenue(d.revenue, cur)],
    ["orders", "⧉", "Orders", formatInt(d.orders)],
    ["sessions", "◎", "Sess.", formatInt(d.sessions)],
    ["cvr", "%", "CvR", formatPct(d.cvr)],
    ["aov", "⊕", "AoV", formatAov(d, cur)],
    ["cos", "◐", "CoS", dashIfEmpty(d.cos)],
    ["spend", "▸", "Spend", formatMoney(d.spend, cur)],
    ["periodPrev", "▤", days + "d Prev", formatRevenue(p.period.prevRevenue, cur)],
    ["periodRevenue", "▤", days + "d Rev", formatRevenue(p.period.revenue, cur)],
    ["forecast", "⌁", "Fcast", forecast]
  ]
  var out = []
  for (var i = 0; i < specs.length; i++) {
    var spec = specs[i]
    out.push({
      id: spec[0],
      label: spec[1] + " " + spec[2],
      value: spec[3],
      selected: spec[0] === metricId,
      clickable: metricClickable(p, spec[0])
    })
  }
  return out
}

function channelRows(payload) {
  var p = asPayload(payload)
  var cur = currency(p)
  var ch = p.channels
  var total = ch.paid + ch.organic + ch.direct + ch.email
  function row(label, value) {
    return {
      label: label,
      share: total > 0 ? value / total : 0,
      text: formatRevenue(value, cur)
    }
  }
  return {
    total: total,
    rows: [
      row("Paid", ch.paid),
      row("Organic", ch.organic),
      row("Direct", ch.direct),
      row("Email", ch.email)
    ]
  }
}

function chartTitle(payload, metricId) {
  var p = asPayload(payload)
  var def = metricById(metricId)
  return periodDays(p) + " day " + def.label
}

function channelsTitle(payload) {
  return "channels " + periodDays(asPayload(payload)) + " days"
}
