.pragma library

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

function parseStoresList(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, stores: [], error: "No stores" }

  try {
    var parsed = JSON.parse(text)
  } catch (e) {
    return { ok: false, stores: [], error: "Invalid stores response" }
  }

  if (!Array.isArray(parsed)) {
    return { ok: false, stores: [], error: "Invalid stores response" }
  }

  var stores = []
  for (var i = 0; i < parsed.length; i++) {
    var entry = parsed[i] || {}
    var key = String(entry.key || "").trim()
    if (!key) continue
    stores.push({
      key: key,
      title: String(entry.title || key),
      adminSlug: String(entry.adminSlug || ""),
      sqliteKey: String(entry.sqliteKey || key.toLowerCase())
    })
  }

  return { ok: stores.length > 0, stores: stores, error: stores.length > 0 ? "" : "No stores configured" }
}

function parseStorePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data" }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response" }
  }

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
    revenue: parseFloat(json.revenue) || 0,
    todayDetail: json.todayDetail && typeof json.todayDetail === "object" ? json.todayDetail : {}
  }
}

function barTooltipFromStore(data) {
  if (!data || !data.ok) {
    if (data && data.error) return String(data.error).replace(/<[^>]+>/g, "").trim()
    return ""
  }
  if (data.label) return data.label
  if (data.text) return String(data.text).replace(/<[^>]+>/g, "").trim()
  return ""
}

function barTooltipFromStores(payloads) {
  if (!payloads || payloads.length === 0) return "Shopify"
  var lines = []
  for (var i = 0; i < payloads.length; i++) {
    var line = barTooltipFromStore(payloads[i])
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
