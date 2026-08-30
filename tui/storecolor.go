package tui

import "strings"

var storeBorderColors = map[string]string{
	"DIY": "6", // cyan
	"TGS": "10", // bright green
}

var storeBorderFallback = []string{"6", "10", "4", "3", "5"}

func storeBorderColor(key string, index int) string {
	if c, ok := storeBorderColors[strings.ToUpper(strings.TrimSpace(key))]; ok {
		return c
	}
	if len(storeBorderFallback) == 0 {
		return string(colAccent)
	}
	return storeBorderFallback[index%len(storeBorderFallback)]
}
