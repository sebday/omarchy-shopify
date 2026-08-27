import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.shopify"

  readonly property string statusScript: Qt.resolvedUrl("bin/shopify-status").toString().replace("file://", "")
  readonly property int pollIntervalMs: 300000

  property var storeDefs: []
  property bool storesLoading: true
  property string storesError: ""
  property var storePayloads: []
  property int payloadGen: 0
  property int payloadIndex: 0
  property int activePayloadGen: 0

  readonly property var firstStoreData: storePayloads.length > 0 ? storePayloads[0] : null
  readonly property bool hasStores: storeDefs.length > 0
  readonly property bool iconActive: Model.iconActiveFromStore(firstStoreData)
  readonly property bool iconError: !storesLoading && storesError !== ""
  readonly property bool iconBusy: storesLoading && !hasStores
  readonly property bool iconMuted: !storesLoading && !hasStores && storesError === ""
  readonly property string tooltip: Model.barTooltipFromStores(storePayloads)

  readonly property bool opened: false
  readonly property bool popoutSwitchClosing: false

  function refresh() {
    refreshStores()
    refreshStorePayloads()
  }

  function togglePanel() {}
  function open() {}
  function close() {}
  function closeForPopoutSwitch() {}

  function refreshStores() {
    if (!statusScript || storesProc.running) return
    storesLoading = true
    storesProc.command = ["bash", statusScript, "stores"]
    storesProc.running = true
  }

  function refreshStorePayloads() {
    if (!statusScript || !hasStores) return
    payloadGen += 1
    payloadIndex = 0
    if (!storePayloadProc.running)
      fetchNextStorePayload()
  }

  function fetchNextStorePayload() {
    if (!statusScript || !hasStores || payloadIndex >= storeDefs.length) return
    activePayloadGen = payloadGen
    storePayloadProc.command = ["bash", statusScript, String(storeDefs[payloadIndex].key), "14"]
    storePayloadProc.running = true
  }

  function applyStores(raw) {
    storesLoading = false
    var parsed = Model.parseStoresList(raw)
    if (parsed.ok) {
      storeDefs = parsed.stores
      storesError = ""
      storePayloads = []
      refreshStorePayloads()
    } else {
      storesError = parsed.error || "No stores"
      storeDefs = []
      storePayloads = []
    }
  }

  function applyStorePayload(raw) {
    var parsed = Model.parseStorePayload(raw)
    var next = storePayloads.slice()
    next[payloadIndex] = parsed
    if (payloadIndex + 1 >= storeDefs.length)
      next = next.slice(0, storeDefs.length)
    storePayloads = next
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  Component.onCompleted: refreshStores()

  Process {
    id: storesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.storesLoading = false
          root.storesError = "No stores"
          return
        }
        root.applyStores(raw)
      }
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: storePayloadProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.activePayloadGen !== root.payloadGen) {
          root.payloadIndex = 0
          root.fetchNextStorePayload()
          return
        }
        var raw = String(text || "").trim()
        if (raw)
          root.applyStorePayload(raw)
        root.payloadIndex += 1
        if (root.payloadIndex < root.storeDefs.length)
          root.fetchNextStorePayload()
      }
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Timer {
    interval: root.pollIntervalMs
    running: true
    repeat: true
    onTriggered: root.refreshStorePayloads()
  }

  IpcHandler {
    target: "evo.shopify"
    function refresh(): string { root.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒚"
    active: root.iconActive || root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: root.tooltip

    onPressed: function() {
      if (!root.bar) return
      root.refresh()
    }
  }
}
