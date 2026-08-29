package tui

import "testing"

func TestFlexFloatUnmarshal(t *testing.T) {
	snap, err := parseSnapshot([]byte(`{
		"stores":[{"key":"DIY","title":"DIY"}],
		"payloads":{"DIY":{"revenue":"4263.69","orders":22,"todayDetail":{"date":"2026-08-29","revenue":100,"orders":1}}}
	}`))
	if err != nil {
		t.Fatal(err)
	}
	if snap.Payloads["DIY"].Revenue.Float() != 4263.69 {
		t.Fatalf("string revenue got %v", snap.Payloads["DIY"].Revenue.Float())
	}

	snap, err = parseSnapshot([]byte(`{
		"stores":[{"key":"DIY","title":"DIY"}],
		"payloads":{"DIY":{"revenue":123.45,"orders":1,"todayDetail":{"date":"x","revenue":1,"orders":1}}}
	}`))
	if err != nil {
		t.Fatal(err)
	}
	if snap.Payloads["DIY"].Revenue.Float() != 123.45 {
		t.Fatalf("number revenue got %v", snap.Payloads["DIY"].Revenue.Float())
	}
}
