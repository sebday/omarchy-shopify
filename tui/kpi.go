package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

const kpiColumns = 5
const kpiColGap = 1
const kpiRightPad = 2

type kpiCell struct {
	id    string
	icon  string
	label string
	value string
}

func (m model) renderKPIs(p Payload, width int, borderColor string) string {
	cur := p.Currency()
	d := p.TodayDetail
	days := p.Period.Days
	if days == 0 {
		days = 30
	}
	periodLabel := fmt.Sprintf("%dd Rev", days)
	prevLabel := fmt.Sprintf("%dd Prev", days)
	forecast := formatRevenue(p.Month.ForecastRevenue, cur)
	if p.Month.ForecastRevenue <= 0 {
		forecast = "—"
	}
	rows := [][]kpiCell{
		{
			{"revenue", "◆", "Rev.", formatRevenue(d.Revenue, cur)},
			{"orders", "⧉", "Orders", formatInt(d.Orders)},
			{"sessions", "◎", "Sess.", formatInt(d.Sessions)},
			{"cvr", "%", "CvR", formatPct(d.Cvr)},
			{"aov", "⊕", "AoV", formatAov(d, cur)},
		},
		{
			{"cos", "◐", "CoS", dashIfEmpty(d.Cos)},
			{"spend", "▸", "Spend", formatMoney(d.Spend, cur)},
			{"periodPrev", "▤", prevLabel, formatRevenue(p.Period.PrevRevenue, cur)},
			{"periodRevenue", "▤", periodLabel, formatRevenue(p.Period.Revenue, cur)},
			{"forecast", "⌁", "Fcast", forecast},
		},
	}
	colGap := (kpiColumns - 1) * kpiColGap
	budget := max(kpiColumns, width-kpiRightPad-colGap)
	colW := max(1, budget/kpiColumns)
	var lines []string
	for i, row := range rows {
		if i > 0 {
			lines = append(lines, "")
		}
		line := m.renderKPIRow(row, colW, borderColor)
		lines = append(lines, padLinesRight(line, kpiRightPad))
	}
	return strings.Join(lines, "\n")
}

func padLinesRight(s string, n int) string {
	if n < 1 {
		return s
	}
	pad := strings.Repeat(" ", n)
	lines := strings.Split(s, "\n")
	for i := range lines {
		lines[i] += pad
	}
	return strings.Join(lines, "\n")
}

func (m model) renderKPIRow(cells []kpiCell, colW int, borderColor string) string {
	labels := make([]string, kpiColumns)
	values := make([]string, kpiColumns)
	for i := 0; i < kpiColumns; i++ {
		if i < len(cells) {
			labels[i], values[i] = m.renderKPICellLines(cells[i], colW, borderColor)
		} else {
			labels[i] = strings.Repeat(" ", colW)
			values[i] = strings.Repeat(" ", colW)
		}
	}
	return joinKPICols(labels, colW) + "\n" + joinKPICols(values, colW)
}

func joinKPICols(cols []string, colW int) string {
	var b strings.Builder
	for i, col := range cols {
		if i > 0 {
			b.WriteString(strings.Repeat(" ", kpiColGap))
		}
		b.WriteString(col)
	}
	return b.String()
}

func (m model) renderKPICellLines(cell kpiCell, width int, borderColor string) (label, value string) {
	selected := cell.id != "" && cell.id == m.metric
	labelText := cell.label
	if cell.icon != "" {
		labelText = cell.icon + " " + labelText
	}
	labStyle := styleMuted()
	valStyle := styleText().Bold(true)
	lab := padLeftExact(labelText, width)
	val := padLeftExact(cell.value, width)
	if selected {
		return styleKPISelected(borderColor).Render(lab), valStyle.Render(val)
	}
	return labStyle.Render(lab), valStyle.Render(val)
}

func padLeftExact(s string, width int) string {
	if width < 1 {
		return s
	}
	w := lipgloss.Width(s)
	if w >= width {
		return lipgloss.NewStyle().MaxWidth(width).Render(s)
	}
	return strings.Repeat(" ", width-w) + s
}
