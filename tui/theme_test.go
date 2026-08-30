package tui

import (
	"strings"
	"testing"
)

func TestFieldsetLegendNotch(t *testing.T) {
	got := fieldsetPad("DIY", "hello", 40, 6, false, 0, 1, 1, "", "", 1, "6")
	if !strings.Contains(got, "DIY") {
		t.Fatalf("want legend DIY, got %q", got)
	}
	if !strings.Contains(got, "╭") || !strings.Contains(got, "┌") {
		t.Fatalf("want notched fieldset, got %q", got)
	}
	if !strings.Contains(got, "¹") {
		t.Fatalf("want panel number 1, got %q", got)
	}
	if !strings.Contains(got, "hello") {
		t.Fatalf("want body, got %q", got)
	}
}

func TestFieldsetInlineBottomLegend(t *testing.T) {
	got := fieldsetPad("SHOPIFY", "DIY  OTHER", 48, 5, true, 0.2, 0, 1, "", "q quit", 1, "10")
	if !strings.Contains(got, "SHOPIFY") {
		t.Fatalf("want top legend, got %q", got)
	}
	if !strings.Contains(got, "q quit") {
		t.Fatalf("want bottom legend, got %q", got)
	}
	if !strings.Contains(got, "¹") {
		t.Fatalf("want panel number, got %q", got)
	}
}

func TestHintTabToSwitch(t *testing.T) {
	got := hint("tab", "to switch")
	if !strings.Contains(got, "tab") || !strings.Contains(got, "to switch") {
		t.Fatalf("want tab to switch, got %q", got)
	}
}
