package tui

import (
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"
)

func commaInt(n int) string {
	s := strconv.Itoa(n)
	if n < 0 {
		s = s[1:]
	}
	var b strings.Builder
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(c)
	}
	out := b.String()
	if n < 0 {
		return "-" + out
	}
	return out
}

func formatRevenue(val float64, symbol string) string {
	if symbol == "" {
		symbol = "£"
	}
	return symbol + commaInt(int(math.Round(val)))
}

func formatMoney(val *float64, symbol string) string {
	if val == nil || *val <= 0 {
		return "—"
	}
	return formatRevenue(*val, symbol)
}

func formatPct(val *float64) string {
	if val == nil {
		return "—"
	}
	return fmt.Sprintf("%.1f%%", *val*100)
}

func formatInt(n int) string {
	if n == 0 {
		return "0"
	}
	return commaInt(n)
}

func formatAov(detail TodayDetail, symbol string) string {
	if detail.Orders <= 0 {
		return "—"
	}
	return formatRevenue(detail.Revenue/float64(detail.Orders), symbol)
}

func formatDay(dateStr string) string {
	text := strings.TrimSpace(dateStr)
	if text == "" {
		return ""
	}
	t, err := time.Parse("2006-01-02", text)
	if err != nil {
		return text
	}
	return t.Format("Jan 2")
}

func kpiHeroMeta(detail TodayDetail) string {
	date := strings.TrimSpace(detail.Date)
	cal := strings.TrimSpace(detail.CalendarDate)
	if date != "" && cal != "" && date != cal {
		if label := formatDay(date); label != "" {
			return "As of " + label
		}
	}
	return ""
}

func dashIfEmpty(s string) string {
	if strings.TrimSpace(s) == "" || s == "—" {
		return "—"
	}
	return s
}
