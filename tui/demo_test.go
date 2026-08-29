package tui

import "testing"

func TestDemoSnapshot(t *testing.T) {
	script, err := statusScript()
	if err != nil {
		t.Skip(err)
	}
	snap, err := loadSnapshot(script, "demo")
	if err != nil {
		t.Fatal(err)
	}
	if len(snap.Stores) != 2 {
		t.Fatalf("stores %d", len(snap.Stores))
	}
	if snap.Stores[0].Key != "DIY" || snap.Stores[1].Key != "TGS" {
		t.Fatalf("stores %#v", snap.Stores)
	}
	for _, key := range []string{"DIY", "TGS"} {
		p, ok := snap.Payloads[key]
		if !ok || !p.OK() {
			t.Fatalf("payload %s ok=%v", key, p.OK())
		}
		if len(p.Bars) != 30 || len(p.OrderBars) != 30 {
			t.Fatalf("%s bars %d orders %d", key, len(p.Bars), len(p.OrderBars))
		}
		if p.Channels.Total() <= 0 {
			t.Fatalf("%s channels empty", key)
		}
	}
}

func TestToggleDemo(t *testing.T) {
	script, err := statusScript()
	if err != nil {
		t.Skip(err)
	}
	m := newModel(script)
	m = m.setSnap(Snapshot{
		Stores:   []Store{{Key: "LIVE", Title: "Live"}},
		Payloads: map[string]Payload{"LIVE": {Text: "live"}},
	})
	m = m.toggleDemo()
	if !m.demo || len(m.stores) != 2 || m.stores[0].Key != "DIY" {
		t.Fatalf("demo on: demo=%v stores %#v err=%q", m.demo, m.stores, m.err)
	}
	m = m.toggleDemo()
	if m.demo || len(m.stores) != 1 || m.stores[0].Key != "LIVE" {
		t.Fatalf("demo off: demo=%v stores %#v", m.demo, m.stores)
	}
}
