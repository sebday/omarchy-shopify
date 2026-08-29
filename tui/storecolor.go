package tui

import "strings"

var storeBorderColors = map[string]string{
	"DIY": "6", // cyan
	"TGS": "5", // magenta
}

var storeBorderFallback = []string{"6", "5", "2", "3", "4"}

func storeBorderColor(key string, index int) string {
	if c, ok := storeBorderColors[strings.ToUpper(strings.TrimSpace(key))]; ok {
		return c
	}
	if len(storeBorderFallback) == 0 {
		return string(colAccent)
	}
	return storeBorderFallback[index%len(storeBorderFallback)]
}
