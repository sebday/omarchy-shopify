package tui

import (
	"math"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestFormatRevenue(t *testing.T) {
	if got := formatRevenue(1234, "£"); got != "£1,234" {
		t.Fatalf("got %q", got)
	}
}

func TestFormatPct(t *testing.T) {
	v := 0.123
	if got := formatPct(&v); got != "12.3%" {
		t.Fatalf("got %q", got)
	}
	if got := formatPct(nil); got != "—" {
		t.Fatalf("got %q", got)
	}
}

func TestFormatDay(t *testing.T) {
	if got := formatDay("2026-08-29"); got != "Aug 29" {
		t.Fatalf("got %q", got)
	}
}

func TestNextMetricSkipsEmpty(t *testing.T) {
	p := Payload{Bars: []Bar{{Value: 1}}, OrderBars: []Bar{{Value: 2}}}
	if got := nextMetric(p, "revenue", 1); got != "orders" {
		t.Fatalf("revenue+1 = %q", got)
	}
	if got := nextMetric(p, "orders", 1); got != "periodPrev" {
		t.Fatalf("orders+1 = %q", got)
	}
	if got := nextMetric(p, "periodPrev", 1); got != "periodRevenue" {
		t.Fatalf("periodPrev+1 = %q", got)
	}
	if got := nextMetric(p, "periodRevenue", 1); got != "forecast" {
		t.Fatalf("periodRevenue+1 = %q", got)
	}
	if got := nextMetric(p, "forecast", 1); got != "revenue" {
		t.Fatalf("forecast+1 = %q", got)
	}
	if got := nextMetric(p, "orders", -1); got != "revenue" {
		t.Fatalf("orders-1 = %q", got)
	}
}

func TestNextMetricWalksKPIOrder(t *testing.T) {
	bar := []Bar{{Value: 1}}
	p := Payload{
		Bars: bar, OrderBars: bar, SessionBars: bar, CvrBars: bar,
		AovBars: bar, CosBars: bar, SpendBars: bar,
	}
	want := []string{
		"orders", "sessions", "cvr", "aov", "cos",
		"spend", "periodPrev", "periodRevenue", "forecast", "revenue",
	}
	cur := "revenue"
	for i, id := range want {
		got := nextMetric(p, cur, 1)
		if got != id {
			t.Fatalf("step %d: %s+1 = %q want %q", i, cur, got, id)
		}
		cur = got
	}
}

func TestResampleBars(t *testing.T) {
	bars := make([]Bar, 10)
	for i := range bars {
		bars[i].Value = float64(i)
	}
	got := resampleBars(bars, 5)
	if len(got) != 5 {
		t.Fatalf("len %d", len(got))
	}
	if math.Abs(got[0].Value-0) > 0.01 {
		t.Fatalf("first %v", got[0].Value)
	}
	got = resampleBars(bars, 20)
	if len(got) != 20 {
		t.Fatalf("upsample len %d", len(got))
	}
}

func TestPadChartLines(t *testing.T) {
	got := padChartLines("abc", 8)
	if lipgloss.Width(got) != 8 {
		t.Fatalf("width %d", lipgloss.Width(got))
	}
}
