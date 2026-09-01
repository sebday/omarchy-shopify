package tui

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

type Store struct {
	Key       string `json:"key"`
	Title     string `json:"title"`
	AdminSlug string `json:"adminSlug"`
	IconKey   string `json:"iconKey"`
	SqliteKey string `json:"sqliteKey,omitempty"` // legacy alias for iconKey
	IconPath  string `json:"iconPath"`
}

type Bar struct {
	Date       string  `json:"date"`
	Value      float64 `json:"value"`
	Orders     int     `json:"orders"`
	Level      int     `json:"level"`
	ColorLevel int     `json:"colorLevel"`
	Color      string  `json:"color"`
}

type TodayDetail struct {
	Date         string   `json:"date"`
	CalendarDate string   `json:"calendarDate"`
	Revenue      float64  `json:"revenue"`
	Orders       int      `json:"orders"`
	Sessions     int      `json:"sessions"`
	Cos          string   `json:"cos"`
	Spend        *float64 `json:"spend"`
	Cvr          *float64 `json:"cvr"`
}

type Period struct {
	Days        int      `json:"days"`
	Revenue     float64  `json:"revenue"`
	PrevRevenue float64  `json:"prevRevenue"`
	Orders      int      `json:"orders"`
	Sessions    int      `json:"sessions"`
	Spend       *float64 `json:"spend"`
}

type Channels struct {
	Paid    float64 `json:"paid"`
	Organic float64 `json:"organic"`
	Direct  float64 `json:"direct"`
	Email   float64 `json:"email"`
}

type Month struct {
	MtdRevenue      float64 `json:"mtdRevenue"`
	ForecastRevenue float64 `json:"forecastRevenue"`
	Day             int     `json:"day"`
	DaysInMonth     int     `json:"daysInMonth"`
}

type Payload struct {
	Text        string      `json:"text"`
	Label       string      `json:"label"`
	Symbol      string      `json:"symbol"`
	Orders      int         `json:"orders"`
	Cos         string      `json:"cos"`
	Revenue     flexFloat   `json:"revenue"`
	TodayDetail TodayDetail `json:"todayDetail"`
	Period      Period      `json:"period"`
	Channels    Channels    `json:"channels"`
	Month       Month       `json:"month"`
	Bars        []Bar       `json:"bars"`
	OrderBars   []Bar       `json:"orderBars"`
	SessionBars []Bar       `json:"sessionBars"`
	SpendBars   []Bar       `json:"spendBars"`
	CvrBars     []Bar       `json:"cvrBars"`
	AovBars     []Bar       `json:"aovBars"`
	CosBars     []Bar       `json:"cosBars"`
}

type Snapshot struct {
	Stores   []Store            `json:"stores"`
	Payloads map[string]Payload `json:"payloads"`
}

func (p Payload) OK() bool {
	if p.TodayDetail.Date != "" || len(p.Bars) > 0 {
		return true
	}
	if p.Revenue.Float() != 0 || p.Orders != 0 {
		return true
	}
	return false
}

func (p Payload) ErrorText() string {
	if p.OK() {
		return ""
	}
	if p.Text != "" {
		return p.Text
	}
	if p.Label != "" {
		return p.Label
	}
	return "No data"
}

func (p Payload) Currency() string {
	if p.Symbol != "" {
		return p.Symbol
	}
	return "£"
}

func (c Channels) Total() float64 {
	return c.Paid + c.Organic + c.Direct + c.Email
}

func pluginRoot() string {
	if v := os.Getenv("EVOSHOPIFY_ROOT"); v != "" {
		return v
	}
	exe, err := os.Executable()
	if err == nil {
		exe, _ = filepath.EvalSymlinks(exe)
		dir := filepath.Dir(exe)
		for _, c := range []string{dir, filepath.Join(dir, ".."), filepath.Join(dir, "..", "..")} {
			if _, err := os.Stat(filepath.Join(c, "bin", "shopify-status")); err == nil {
				return c
			}
			if _, err := os.Stat(filepath.Join(c, "go.mod")); err == nil {
				if _, err := os.Stat(filepath.Join(c, "bin", "shopify-status")); err == nil {
					return c
				}
			}
		}
	}
	if cwd, err := os.Getwd(); err == nil {
		for d := cwd; d != "/" && d != "."; d = filepath.Dir(d) {
			if _, err := os.Stat(filepath.Join(d, "bin", "shopify-status")); err == nil {
				return d
			}
		}
	}
	home, _ := os.UserHomeDir()
	plugin := filepath.Join(home, ".config", "omarchy", "plugins", "evo.shopify")
	if _, err := os.Stat(filepath.Join(plugin, "bin", "shopify-status")); err == nil {
		return plugin
	}
	return "."
}

func statusScript() (string, error) {
	path := filepath.Join(pluginRoot(), "bin", "shopify-status")
	if _, err := os.Stat(path); err != nil {
		return "", fmt.Errorf("shopify-status not found at %s", path)
	}
	return path, nil
}

func runStatus(script string, args ...string) ([]byte, error) {
	cmd := exec.Command("bash", append([]string{script}, args...)...)
	cmd.Env = os.Environ()
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("shopify-status %v: %s", args, ee.Stderr)
		}
		return nil, err
	}
	return out, nil
}

func parseSnapshot(raw []byte) (Snapshot, error) {
	var snap Snapshot
	if err := json.Unmarshal(raw, &snap); err != nil {
		return Snapshot{}, err
	}
	if snap.Payloads == nil {
		snap.Payloads = map[string]Payload{}
	}
	return snap, nil
}

func loadSnapshot(script, mode string) (Snapshot, error) {
	raw, err := runStatus(script, mode)
	if err != nil {
		return Snapshot{}, err
	}
	return parseSnapshot(raw)
}

const pollInterval = 5 * time.Minute
