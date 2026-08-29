package tui

import "testing"

func TestParseSnapshot(t *testing.T) {
	raw := []byte(`{
		"stores":[{"key":"DIY","title":"DIY","adminSlug":"x","sqliteKey":"diy"}],
		"payloads":{
			"DIY":{
				"symbol":"£",
				"revenue":100,
				"orders":2,
				"todayDetail":{"date":"2026-08-28","calendarDate":"2026-08-29","revenue":100,"orders":2,"sessions":50,"cos":"10.0%","cvr":0.04},
				"period":{"days":30,"revenue":3000,"prevRevenue":2800},
				"channels":{"paid":10,"organic":20,"direct":5,"email":5},
				"month":{"forecastRevenue":4000},
				"bars":[{"date":"2026-08-01","value":10,"level":3,"colorLevel":2}]
			}
		}
	}`)
	snap, err := parseSnapshot(raw)
	if err != nil {
		t.Fatal(err)
	}
	if len(snap.Stores) != 1 || snap.Stores[0].Key != "DIY" {
		t.Fatalf("stores %#v", snap.Stores)
	}
	p := snap.Payloads["DIY"]
	if !p.OK() {
		t.Fatal("expected ok payload")
	}
	if p.TodayDetail.Sessions != 50 || p.Channels.Total() != 40 {
		t.Fatalf("payload %#v", p)
	}
	if p.Period.PrevRevenue != 2800 {
		t.Fatalf("prev revenue %v", p.Period.PrevRevenue)
	}
	if p.TodayDetail.Cvr == nil || *p.TodayDetail.Cvr != 0.04 {
		t.Fatalf("cvr %#v", p.TodayDetail.Cvr)
	}
}
