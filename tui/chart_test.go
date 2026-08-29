package tui

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestBarSlots(t *testing.T) {
	slots := barSlots(50, 30)
	if len(slots) != 30 {
		t.Fatalf("len %d", len(slots))
	}
	sum := 0
	for _, w := range slots {
		sum += w
	}
	if sum != 50 {
		t.Fatalf("sum %d", sum)
	}
}

func TestRenderDottedBarChart(t *testing.T) {
	bars := make([]Bar, 30)
	for i := range bars {
		bars[i].Value = float64((i + 1) * 100)
		bars[i].Date = "2026-08-01"
	}
	out := renderDottedBarChart(bars, 40, 8, 3000, "6")
	lines := strings.Split(out, "\n")
	if len(lines) != 8 {
		t.Fatalf("height %d", len(lines))
	}
	if lipgloss.Width(lines[0]) != 40 {
		t.Fatalf("width %d", lipgloss.Width(lines[0]))
	}
	if !strings.Contains(out, "⣿") && !strings.Contains(out, "⣤") && !strings.Contains(out, "⠀") {
		// braille block should appear in output
		hasBraille := false
		for _, r := range out {
			if r >= 0x2800 && r <= 0x28ff {
				hasBraille = true
				break
			}
		}
		if !hasBraille {
			t.Fatalf("expected braille, got %q", out[:min(80, len(out))])
		}
	}
}

func TestRenderDottedShareBar(t *testing.T) {
	out := renderDottedShareBar(0.5, 20, "6")
	if strings.Contains(out, "\n") {
		t.Fatalf("expected single row, got %d lines", strings.Count(out, "\n")+1)
	}
	if lipgloss.Width(out) != 20 {
		t.Fatalf("width %d", lipgloss.Width(out))
	}
}

func TestPackedBarStart(t *testing.T) {
	if got := packedBarSpan(15); got != 29 {
		t.Fatalf("span %d", got)
	}
	if got := packedBarStart(40, 15); got != 5 {
		t.Fatalf("start %d", got)
	}
}

func TestDottedSeriesFitsWidth(t *testing.T) {
	bars := make([]Bar, 30)
	series := dottedSeries(bars, 40)
	if len(series) != 20 {
		t.Fatalf("series %d", len(series))
	}
}

func TestChartSeriesFitsWidth(t *testing.T) {
	bars := make([]Bar, 30)
	series := dottedSeries(bars, 48)
	if len(series) != 24 {
		t.Fatalf("series %d", len(series))
	}
	slots := barSlots(48, len(series))
	sum := 0
	for _, w := range slots {
		sum += w
	}
	if sum != 48 {
		t.Fatalf("slots sum %d", sum)
	}
}
