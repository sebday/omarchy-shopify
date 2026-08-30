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
	loading    bool
	refreshing bool
	demo       bool
	liveSnap   Snapshot
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
	return tea.Batch(loadCacheCmd(m.script), pollTick())
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

func pollTick() tea.Cmd {
	return tea.Tick(pollInterval, func(time.Time) tea.Msg {
		return pollMsg{}
	})
}

func (m model) applySnap(snap Snapshot) model {
	if m.demo {
		return m
	}
	return m.setSnap(snap)
}

func (m model) setSnap(snap Snapshot) model {
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

func (m model) toggleDemo() model {
	if m.demo {
		m.demo = false
		if len(m.liveSnap.Stores) > 0 || len(m.liveSnap.Payloads) > 0 {
			m = m.setSnap(m.liveSnap)
		}
		m.liveSnap = Snapshot{}
		m.err = ""
		return m
	}
	m.liveSnap = Snapshot{
		Stores:   append([]Store(nil), m.stores...),
		Payloads: copyPayloads(m.payloads),
	}
	m.demo = true
	m.loading = false
	m.err = ""
	snap, err := loadSnapshot(m.script, "demo")
	if err != nil {
		m.demo = false
		m.liveSnap = Snapshot{}
		m.err = err.Error()
		return m
	}
	return m.setSnap(snap)
}

func copyPayloads(src map[string]Payload) map[string]Payload {
	if src == nil {
		return map[string]Payload{}
	}
	dst := make(map[string]Payload, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
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
		if m.demo {
			return m, nil
		}
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
		if m.demo {
			return m, nil
		}
		if msg.err != nil {
			if len(m.stores) == 0 {
				m.err = msg.err.Error()
			}
			return m, nil
		}
		m = m.applySnap(msg.snap)
		return m, nil

	case pollMsg:
		if m.demo {
			return m, pollTick()
		}
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
		if m.demo {
			m = m.toggleDemo()
		}
		if m.refreshing {
			return m, nil
		}
		m.refreshing = true
		return m, refreshCmd(m.script)
	case "d":
		m = m.toggleDemo()
		return m, nil
	case "tab":
		m.metric = nextMetric(m.currentPayload(), m.metric, 1)
		return m, nil
	case "n":
		if len(m.stores) > 0 {
			m.storeIdx = (m.storeIdx + 1) % len(m.stores)
		}
		return m, nil
	case "shift+tab":
		m.metric = nextMetric(m.currentPayload(), m.metric, -1)
		return m, nil
	case "p":
		if len(m.stores) > 0 {
			m.storeIdx = (m.storeIdx - 1 + len(m.stores)) % len(m.stores)
		}
		return m, nil
	}
	return m, nil
}
