package tui

import "testing"

func TestStoreBorderColor(t *testing.T) {
	if got := storeBorderColor("DIY", 0); got != "6" {
		t.Fatalf("DIY = %q", got)
	}
	if got := storeBorderColor("tgs", 1); got != "5" {
		t.Fatalf("TGS = %q", got)
	}
	if got := storeBorderColor("OTHER", 2); got != "2" {
		t.Fatalf("fallback = %q", got)
	}
}
