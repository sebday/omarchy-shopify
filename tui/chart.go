package tui

import (
	"math"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type metricDef struct {
	ID         string
	Label      string
	ValueKind  string
	ChartStyle string
}

var kpiMetricOrder = []string{
	"revenue", "orders", "sessions", "cvr", "aov",
	"cos", "spend", "periodPrev", "periodRevenue", "forecast",
}

var chartMetrics = []metricDef{
	{ID: "revenue", Label: "revenue", ValueKind: "currency", ChartStyle: "bar"},
	{ID: "orders", Label: "orders", ValueKind: "integer", ChartStyle: "bar"},
	{ID: "sessions", Label: "sessions", ValueKind: "integer", ChartStyle: "line"},
	{ID: "cvr", Label: "CVR", ValueKind: "percent", ChartStyle: "line"},
	{ID: "aov", Label: "AoV", ValueKind: "currency", ChartStyle: "line"},
	{ID: "cos", Label: "CoS", ValueKind: "percent", ChartStyle: "line"},
	{ID: "spend", Label: "ad spend", ValueKind: "currency", ChartStyle: "line"},
	{ID: "periodPrev", Label: "prev", ValueKind: "currency", ChartStyle: "bar"},
	{ID: "periodRevenue", Label: "revenue", ValueKind: "currency", ChartStyle: "bar"},
	{ID: "forecast", Label: "forecast", ValueKind: "currency", ChartStyle: "bar"},
}

func metricByID(id string) metricDef {
	for _, m := range chartMetrics {
		if m.ID == id {
			return m
		}
	}
	return chartMetrics[0]
}

func (p Payload) barsFor(id string) []Bar {
	switch id {
	case "orders":
		return p.OrderBars
	case "sessions":
		return p.SessionBars
	case "cvr":
		return p.CvrBars
	case "aov":
		return p.AovBars
	case "cos":
		return p.CosBars
	case "spend":
		return p.SpendBars
	default:
		return p.Bars
	}
}

func (p Payload) metricClickable(id string) bool {
	switch id {
	case "periodPrev", "periodRevenue", "forecast":
		return len(p.Bars) > 0
	default:
		return len(p.barsFor(id)) > 0
	}
}

func nextMetric(p Payload, current string, dir int) string {
	if dir == 0 {
		dir = 1
	}
	idx := 0
	for i, id := range kpiMetricOrder {
		if id == current {
			idx = i
			break
		}
	}
	n := len(kpiMetricOrder)
	for i := 0; i < n; i++ {
		idx = (idx + dir + n) % n
		if p.metricClickable(kpiMetricOrder[idx]) {
			return kpiMetricOrder[idx]
		}
	}
	return current
}

// barSlots divides width cells evenly across n bars.
func barSlots(width, n int) []int {
	if n < 1 || width < 1 {
		return nil
	}
	slots := make([]int, n)
	rem := width
	for i := 0; i < n; i++ {
		slots[i] = rem / (n - i)
		rem -= slots[i]
	}
	return slots
}

func slotOffsets(slots []int) []int {
	off := make([]int, len(slots))
	for i := 1; i < len(slots); i++ {
		off[i] = off[i-1] + slots[i-1]
	}
	return off
}

func resampleBars(bars []Bar, width int) []Bar {
	if width < 1 || len(bars) == 0 {
		return nil
	}
	if len(bars) == 1 {
		out := make([]Bar, width)
		for i := range out {
			out[i] = bars[0]
		}
		return out
	}
	out := make([]Bar, width)
	denom := float64(width - 1)
	for i := 0; i < width; i++ {
		src := int(math.Round(float64(i) * float64(len(bars)-1) / denom))
		if src >= len(bars) {
			src = len(bars) - 1
		}
		out[i] = bars[src]
	}
	return out
}

func renderChart(bars []Bar, width, height int, style, accentColor string) string {
	if len(bars) == 0 || width < 1 || height < 1 {
		return styleMuted().Render("no data")
	}
	series := dottedSeries(bars, width)
	if len(series) == 0 {
		return styleMuted().Render("no data")
	}
	slots := barSlots(width, len(series))
	maxV := 0.0
	for _, b := range series {
		if b.Value > maxV {
			maxV = b.Value
		}
	}
	if maxV <= 0 {
		return styleMuted().Render(strings.Repeat("·", width))
	}
	if style == "line" {
		return padChartLines(renderLineChart(series, slots, height, maxV, accentColor), width)
	}
	return padChartLines(renderDottedBarChart(series, width, height, maxV, accentColor), width)
}

func padChartLines(s string, width int) string {
	if width < 1 {
		return s
	}
	lines := strings.Split(s, "\n")
	for i, line := range lines {
		lines[i] = padExact(line, width)
	}
	return strings.Join(lines, "\n")
}

const brailleRowsPerCell = 4
const chartBarStride = 2 // one bar column + one gap column

// brailleDot returns the bitmask for one dot in a braille cell.
func brailleDot(subRow, subCol int) byte {
	if subCol == 0 {
		return []byte{0x01, 0x02, 0x04, 0x40}[subRow]
	}
	return []byte{0x08, 0x10, 0x20, 0x80}[subRow]
}

func dottedSeries(bars []Bar, width int) []Bar {
	if len(bars) == 0 || width < 1 {
		return nil
	}
	maxBars := max(1, (width+1)/chartBarStride)
	series := bars
	if len(series) > maxBars {
		series = resampleBars(series, maxBars)
	}
	return series
}

func packedBarSpan(n int) int {
	if n < 1 {
		return 0
	}
	return n*chartBarStride - 1
}

func barColumnAt(start, barIndex int) int {
	return start + barIndex*chartBarStride
}

func isChartGapColumn(col, start, n int) bool {
	if n <= 1 {
		return false
	}
	span := packedBarSpan(n)
	if col < start || col >= start+span {
		return false
	}
	return (col-start)%chartBarStride == 1
}

func chartGapCell() string {
	return styleMuted().Faint(true).Render("·")
}

// packedBarStart returns the left offset for n bar columns with gaps between them.
func packedBarStart(width, n int) int {
	if n < 1 || width < 1 {
		return 0
	}
	return max(0, (width-packedBarSpan(n))/2)
}

// dotGradientStyle colours dots darker at the top of each bar, lighter toward the baseline.
func dotGradientStyle(rowFromTop, barHeight float64, accent string) lipgloss.Style {
	if barHeight <= 1 {
		return logoColor().NewStyle().Foreground(lipgloss.Color(accent)).Bold(true)
	}
	t := rowFromTop / (barHeight - 1)
	switch {
	case t < 0.35:
		return logoColor().NewStyle().Foreground(lipgloss.Color("15")).Bold(true)
	case t < 0.7:
		return logoColor().NewStyle().Foreground(lipgloss.Color(accent)).Bold(true)
	default:
		return logoColor().NewStyle().Foreground(lipgloss.Color(accent))
	}
}

func renderDottedBarChart(series []Bar, width, height int, maxV float64, accent string) string {
	n := len(series)
	plotCellsH := max(1, height)
	dotH := plotCellsH * brailleRowsPerCell
	start := packedBarStart(width, n)

	cells := make([][]byte, plotCellsH)
	for y := range cells {
		cells[y] = make([]byte, width)
	}

	for i, bar := range series {
		x := barColumnAt(start, i)
		if x < 0 || x >= width {
			continue
		}
		ratio := bar.Value / maxV
		fillDots := int(math.Round(ratio * float64(dotH)))
		if bar.Value > 0 && fillDots < 1 {
			fillDots = 1
		}
		if fillDots > dotH {
			fillDots = dotH
		}
		for d := 0; d < fillDots; d++ {
			dotRow := dotH - 1 - d
			cellRow := dotRow / brailleRowsPerCell
			subRow := dotRow % brailleRowsPerCell
			cells[cellRow][x] |= brailleDot(subRow, 0) | brailleDot(subRow, 1)
		}
	}

	rows := make([]string, height)
	for row := 0; row < plotCellsH; row++ {
		var b strings.Builder
		rowFromTop := float64(plotCellsH - 1 - row)
		for col := 0; col < width; col++ {
			pattern := cells[row][col]
			if pattern == 0 {
				if isChartGapColumn(col, start, n) {
					b.WriteString(chartGapCell())
				} else {
					b.WriteRune(' ')
				}
				continue
			}
			st := dotGradientStyle(rowFromTop, float64(plotCellsH), accent)
			b.WriteString(st.Render(string(rune(0x2800 + rune(pattern)))))
		}
		rows[row] = b.String()
	}

	return strings.Join(rows, "\n")
}

func renderLineChart(series []Bar, slots []int, height int, maxV float64, accent string) string {
	plotH := max(1, height-1)
	width := 0
	for _, w := range slots {
		width += w
	}
	grid := make([][]rune, plotH)
	levels := make([][]float64, plotH)
	for y := 0; y < plotH; y++ {
		grid[y] = make([]rune, width)
		levels[y] = make([]float64, width)
		for x := range grid[y] {
			grid[y][x] = ' '
		}
	}

	offsets := slotOffsets(slots)
	points := make([][2]int, len(series))
	for i, bar := range series {
		w := slots[i]
		x := offsets[i] + w/2
		if x >= width {
			x = width - 1
		}
		ratio := bar.Value / maxV
		y := plotH - 1 - int(math.Round(ratio*float64(plotH-1)))
		if y < 0 {
			y = 0
		}
		points[i] = [2]int{x, y}
	}

	lineStyle := logoColor().NewStyle().Foreground(lipgloss.Color(accent))
	dotStyle := logoColor().NewStyle().Foreground(lipgloss.Color(accent)).Bold(true)

	for i := 1; i < len(points); i++ {
		x0, y0 := points[i-1][0], points[i-1][1]
		x1, y1 := points[i][0], points[i][1]
		drawLine(grid, levels, x0, y0, x1, y1)
	}
	for _, p := range points {
		grid[p[1]][p[0]] = '●'
		levels[p[1]][p[0]] = 1
	}

	rows := make([]string, plotH+1)
	for y := 0; y < plotH; y++ {
		var b strings.Builder
		for x := 0; x < width; x++ {
			ch := grid[y][x]
			if ch == ' ' {
				b.WriteRune(' ')
				continue
			}
			if ch == '●' {
				b.WriteString(dotStyle.Render("●"))
			} else {
				b.WriteString(lineStyle.Render(string(ch)))
			}
		}
		rows[y] = b.String()
	}
	rows[plotH] = styleMuted().Render(strings.Repeat("▄", width))
	return strings.Join(rows, "\n")
}

func drawLine(grid [][]rune, levels [][]float64, x0, y0, x1, y1 int) {
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	sx := -1
	if x0 < x1 {
		sx = 1
	}
	sy := -1
	if y0 < y1 {
		sy = 1
	}
	err := dx + dy
	for {
		if y0 >= 0 && y0 < len(grid) && x0 >= 0 && x0 < len(grid[0]) && grid[y0][x0] == ' ' {
			grid[y0][x0] = '·'
			levels[y0][x0] = 0.5
		}
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

const shareBarDotRows = 2

func shareBarDotMask() byte {
	const startRow = 2 // bottom two braille rows — aligns with single-line labels
	var mask byte
	for row := startRow; row < startRow+shareBarDotRows; row++ {
		mask |= brailleDot(row, 0) | brailleDot(row, 1)
	}
	return mask
}

func renderDottedShareBar(share float64, width int, accent string) string {
	if width < 1 {
		return ""
	}
	filled := int(math.Round(share * float64(width)))
	if share > 0 && filled < 1 {
		filled = 1
	}
	if filled > width {
		filled = width
	}
	cell := string(rune(0x2800 + rune(shareBarDotMask())))
	parts := make([]string, width)
	for i := 0; i < width; i++ {
		if i < filled {
			parts[i] = dotGradientStyle(float64(i), float64(filled), accent).Render(cell)
		} else {
			parts[i] = " "
		}
	}
	return strings.Join(parts, "")
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func chartHoverLabel(bars []Bar, def metricDef, symbol string) string {
	if len(bars) == 0 {
		return ""
	}
	last := bars[len(bars)-1]
	day := formatDay(last.Date)
	switch def.ValueKind {
	case "integer":
		return strings.TrimSpace(day + "  " + formatInt(int(math.Round(last.Value))))
	case "percent":
		v := last.Value
		return strings.TrimSpace(day + "  " + formatPct(&v))
	default:
		return strings.TrimSpace(day + "  " + formatRevenue(last.Value, symbol))
	}
}
