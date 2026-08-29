package tui

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type panel int

const (
	panelKPI panel = iota + 1
	panelChart
	panelChannels
)

type model struct {
	width      int
	height     int
	script     string
	stores     []Store
	payloads   map[string]Payload
	storeIdx   int
	metric     string
	focus      panel
	pulsePhase float64
	loading    bool
	refreshing bool
	err        string
}

type cacheMsg struct {
	snap Snapshot
	err  error
}

type refreshMsg struct {
	snap Snapshot
	err  error
}

type pulseMsg struct{}

type pollMsg struct{}

func newModel(script string) model {
	return model{
		script:   script,
		width:    80,
		height:   24,
		metric:   "revenue",
		focus:    panelKPI,
		payloads: map[string]Payload{},
		loading:  true,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(loadCacheCmd(m.script), pulseTick(), pollTick())
}

func loadCacheCmd(script string) tea.Cmd {
	return func() tea.Msg {
		snap, err := loadSnapshot(script, "cache")
		return cacheMsg{snap: snap, err: err}
	}
}

func refreshCmd(script string) tea.Cmd {
	return func() tea.Msg {
		snap, err := loadSnapshot(script, "refresh")
		return refreshMsg{snap: snap, err: err}
	}
}

func pulseTick() tea.Cmd {
	return tea.Tick(120*time.Millisecond, func(time.Time) tea.Msg {
		return pulseMsg{}
	})
}

func pollTick() tea.Cmd {
	return tea.Tick(pollInterval, func(time.Time) tea.Msg {
		return pollMsg{}
	})
}

func (m model) applySnap(snap Snapshot) model {
	if len(snap.Stores) > 0 {
		m.stores = snap.Stores
	}
	if snap.Payloads != nil {
		m.payloads = snap.Payloads
	}
	if m.storeIdx >= len(m.stores) {
		m.storeIdx = 0
	}
	if cur := m.currentPayload(); !cur.metricClickable(m.metric) {
		m.metric = nextMetric(cur, m.metric, 1)
		if !cur.metricClickable(m.metric) {
			m.metric = "revenue"
		}
	}
	m.err = ""
	m.loading = false
	return m
}

func (m model) currentStore() (Store, bool) {
	if m.storeIdx < 0 || m.storeIdx >= len(m.stores) {
		return Store{}, false
	}
	return m.stores[m.storeIdx], true
}

func (m model) currentPayload() Payload {
	store, ok := m.currentStore()
	if !ok {
		return Payload{}
	}
	return m.payloads[store.Key]
}

func (m model) twoCol() bool {
	return m.width >= 120 && len(m.stores) >= 2
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case cacheMsg:
		if msg.err != nil {
			m.err = msg.err.Error()
			m.loading = false
			return m, refreshCmd(m.script)
		}
		m = m.applySnap(msg.snap)
		m.refreshing = true
		return m, refreshCmd(m.script)

	case refreshMsg:
		m.refreshing = false
		if msg.err != nil {
			if len(m.stores) == 0 {
				m.err = msg.err.Error()
			}
			return m, nil
		}
		m = m.applySnap(msg.snap)
		return m, nil

	case pulseMsg:
		m.pulsePhase += 0.05
		if m.pulsePhase >= 1 {
			m.pulsePhase -= 1
		}
		return m, pulseTick()

	case pollMsg:
		if m.refreshing {
			return m, pollTick()
		}
		m.refreshing = true
		return m, tea.Batch(refreshCmd(m.script), pollTick())

	case tea.KeyMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "esc", "ctrl+c":
		return m, tea.Quit
	case "r":
		if m.refreshing {
			return m, nil
		}
		m.refreshing = true
		return m, refreshCmd(m.script)
	case "tab":
		m.metric = nextMetric(m.currentPayload(), m.metric, 1)
		return m, nil
	case "]", "n":
		if len(m.stores) > 0 {
			m.storeIdx = (m.storeIdx + 1) % len(m.stores)
		}
		return m, nil
	case "shift+tab":
		m.metric = nextMetric(m.currentPayload(), m.metric, -1)
		return m, nil
	case "[", "p":
		if len(m.stores) > 0 {
			m.storeIdx = (m.storeIdx - 1 + len(m.stores)) % len(m.stores)
		}
		return m, nil
	}
	return m, nil
}
