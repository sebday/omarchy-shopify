package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m model) View() string {
	if m.width < 8 || m.height < 5 {
		return "evoshopify"
	}
	return m.renderBody(m.height)
}

func (m model) contentWidth() int {
	return max(20, m.width)
}

func (m model) active(p panel) bool {
	return m.focus == p
}

func (m model) renderBody(height int) string {
	w := m.contentWidth()
	if len(m.stores) == 0 {
		msg := "No stores — set shopify.dataPath in shell.json"
		if m.err != "" {
			msg = m.err
		}
		if m.loading {
			msg = "loading…"
		}
		return fieldset("stores", styleMuted().Render(msg), w, height, false, 0, 2, "")
	}
	if m.twoCol() {
		gap := 1
		colW := (w - gap) / 2
		leftIdx := m.storeIdx
		rightIdx := (m.storeIdx + 1) % len(m.stores)
		left := m.renderStore(m.stores[leftIdx], leftIdx, colW, height, true)
		right := m.renderStore(m.stores[rightIdx], rightIdx, w-gap-colW, height, false)
		return lipgloss.JoinHorizontal(lipgloss.Top, left, " ", right)
	}
	store, _ := m.currentStore()
	return m.renderStore(store, m.storeIdx, w, height, true)
}

func (m model) renderStore(store Store, storeIdx, width, height int, focused bool) string {
	payload := m.payloads[store.Key]
	borderColor := storeBorderColor(store.Key, storeIdx)
	kpiH := 9
	chTotal := payload.Channels.Total()
	chH := 0
	if chTotal > 0 {
		chH = 8
	}
	if kpiH+chH+6 > height {
		kpiH = 8
		if chH > 0 {
			chH = 7
		}
	}
	chartH := max(6, height-kpiH-chH)
	if kpiH+chartH+chH > height {
		chartH = max(4, height-kpiH-chH)
	}

	title := store.Title
	if title == "" {
		title = store.Key
	}
	if m.demo {
		title = "DEMO MODE"
	}
	meta := kpiHeroMeta(payload.TodayDetail)
	innerW := max(8, width-4)
	kpis := m.renderKPIs(payload, innerW, borderColor)
	if !payload.OK() {
		kpis = styleWarn().Render(payload.ErrorText())
	}
	kpiPulse := 0.0
	kpiActive := false
	if focused {
		kpiActive = m.active(panelKPI)
	}
	kpiBox := fieldsetPad(title, kpis, width, kpiH, kpiActive, kpiPulse, 1, 1, meta, hint("tab", "to switch"), 1, borderColor)

	def := metricByID(m.metric)
	days := payload.Period.Days
	if days == 0 {
		days = len(payload.Bars)
	}
	if days == 0 {
		days = 30
	}
	chartLegend := fmt.Sprintf("%d day %s", days, def.Label)
	bars := payload.barsFor(m.metric)
	innerChartW := max(8, width-4)
	innerChartH := max(1, chartH-4)
	chart := renderChart(bars, innerChartW, innerChartH, def.ChartStyle, borderColor)
	chartPulse := 0.0
	chartActive := false
	if focused {
		chartActive = m.active(panelChart)
	}
	hover := chartHoverLabel(bars, def, payload.Currency())
	chartBox := fieldsetPad(chartLegend, chart, width, chartH, chartActive, chartPulse, 1, 1, "", hover, 2, borderColor)

	parts := []string{kpiBox, chartBox}
	if chH > 0 {
		chPulse := 0.0
		chActive := false
		if focused {
			chActive = m.active(panelChannels)
		}
		chBody := m.renderChannels(payload, max(8, width-4), borderColor)
		chBody = "\n" + chBody
		chBox := fieldsetPad(fmt.Sprintf("channels %d days", days), chBody, width, chH, chActive, chPulse, 0, 1, "", "", 3, borderColor)
		parts = append(parts, chBox)
	}
	return strings.Join(parts, "\n")
}

func (m model) renderChannels(p Payload, width int, accent string) string {
	type row struct {
		label string
		value float64
	}
	rows := []row{
		{"Paid", p.Channels.Paid},
		{"Organic", p.Channels.Organic},
		{"Direct", p.Channels.Direct},
		{"Email", p.Channels.Email},
	}
	total := p.Channels.Total()
	labelW := 8
	valueW := 10
	barW := max(4, width-labelW-valueW-2)
	var lines []string
	for _, r := range rows {
		share := 0.0
		if total > 0 {
			share = r.value / total
		}
		label := styleMuted().Render(fmt.Sprintf("%-*s", labelW, r.label))
		bar := renderDottedShareBar(share, barW, accent)
		val := styleText().Render(fmt.Sprintf("%*s", valueW, formatRevenue(r.value, p.Currency())))
		lines = append(lines, lipgloss.JoinHorizontal(lipgloss.Bottom, label, " ", bar, " ", val))
	}
	lines = append(lines, "")
	return strings.Join(lines, "\n")
}
