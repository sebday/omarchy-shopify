package tui

import (
	"encoding/json"
	"fmt"
	"strconv"
)

// flexFloat unmarshals JSON numbers or numeric strings (legacy bar cache).
type flexFloat float64

func (f *flexFloat) UnmarshalJSON(b []byte) error {
	if string(b) == "null" {
		*f = 0
		return nil
	}
	var n float64
	if err := json.Unmarshal(b, &n); err == nil {
		*f = flexFloat(n)
		return nil
	}
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return fmt.Errorf("flexFloat: %q", s)
	}
	*f = flexFloat(v)
	return nil
}

func (f flexFloat) Float() float64 {
	return float64(f)
}
