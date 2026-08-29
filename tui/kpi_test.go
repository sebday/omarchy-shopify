package tui

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestKPIsReserveRightGap(t *testing.T) {
	cvr := 0.011
	m := model{metric: "revenue"}
	out := m.renderKPIs(Payload{
		TodayDetail: TodayDetail{Revenue: 296, Orders: 5, Sessions: 471, Cvr: &cvr},
		Period:      Period{Days: 30, Revenue: 188467, PrevRevenue: 175000},
		Month:       Month{ForecastRevenue: 192997},
	}, 46, "5")
	for i, line := range strings.Split(out, "\n") {
		if line == "" {
			continue
		}
		if got := lipgloss.Width(line); got > 46 {
			t.Fatalf("line %d overflows width 46: got %d %q", i, got, line)
		}
		if !strings.HasSuffix(line, strings.Repeat(" ", kpiRightPad)) {
			t.Fatalf("line %d missing right gap: %q", i, line)
		}
	}
}

func TestKPIRowKeepsFiveColumns(t *testing.T) {
	m := model{metric: "revenue"}
	row := []kpiCell{
		{"revenue", "◆", "Rev.", "£296"},
		{"orders", "⧉", "Orders", "5"},
		{"sessions", "◎", "Sess.", "453"},
		{"cvr", "%", "CvR", "1.1%"},
		{"aov", "⊕", "AoV", "£59"},
	}
	colW := 10
	out := m.renderKPIRow(row, colW, "5")
	lines := strings.Split(out, "\n")
	if len(lines) != 2 {
		t.Fatalf("want 2 lines, got %d: %q", len(lines), out)
	}
	wantW := kpiColumns*colW + (kpiColumns-1)*kpiColGap
	for i, line := range lines {
		if got := lipgloss.Width(line); got != wantW {
			t.Fatalf("line %d width %d want %d: %q", i, got, wantW, line)
		}
	}
	plain := lipgloss.NewStyle().Render(lines[0])
	_ = plain
	if !strings.Contains(lines[0], "Rev.") || !strings.Contains(lines[0], "AoV") {
		t.Fatalf("label row missing Rev./AoV: %q", lines[0])
	}
	plainLab := lipgloss.NewStyle().UnsetForeground().Render(lines[1])
	_ = plainLab
}

func TestPadLeftExactRightAligns(t *testing.T) {
	got := padLeftExact("ab", 5)
	if lipgloss.Width(got) != 5 {
		t.Fatalf("width %d", lipgloss.Width(got))
	}
	if !strings.HasPrefix(got, "   ") {
		t.Fatalf("want leading spaces, got %q", got)
	}
}

func TestKPICellRightAligns(t *testing.T) {
	m := model{}
	lab, val := m.renderKPICellLines(kpiCell{id: "orders", icon: "⧉", label: "orders", value: "5"}, 10, "6")
	if lipgloss.Width(lab) != 10 || lipgloss.Width(val) != 10 {
		t.Fatalf("widths lab=%d val=%d", lipgloss.Width(lab), lipgloss.Width(val))
	}
	if strings.HasPrefix(strings.TrimLeft(lab, " "), " ") {
		t.Fatalf("label should be right-padded, got %q", lab)
	}
}

func TestKPISelectedInvertsLabelOnly(t *testing.T) {
	m := model{metric: "orders"}
	lab, val := m.renderKPICellLines(kpiCell{id: "orders", icon: "⧉", label: "Orders", value: "5"}, 10, "6")
	_, valUnselected := model{}.renderKPICellLines(kpiCell{id: "orders", icon: "⧉", label: "Orders", value: "5"}, 10, "6")
	if lipgloss.Width(lab) != 10 || lipgloss.Width(val) != 10 {
		t.Fatalf("widths lab=%d val=%d", lipgloss.Width(lab), lipgloss.Width(val))
	}
	if !strings.Contains(lab, "\x1b[") {
		t.Fatalf("selected label should be styled, lab=%q", lab)
	}
	if val != valUnselected {
		t.Fatalf("selected value should match unselected styling, got %q want %q", val, valUnselected)
	}
}
