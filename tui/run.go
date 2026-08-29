package tui

import (
	tea "github.com/charmbracelet/bubbletea"
)

func Run() error {
	script, err := statusScript()
	if err != nil {
		return err
	}
	p := tea.NewProgram(newModel(script), tea.WithAltScreen())
	_, err = p.Run()
	return err
}
