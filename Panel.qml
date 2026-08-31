import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.shopify"
  ipcTarget: "evo.shopify"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var palette: Model.chartPalette(accent, urgent)

  property int pollIntervalMinutes: 5
  readonly property int pollIntervalMs: Math.max(60000, pollIntervalMinutes * 60 * 1000)

  property var storeDefs: []
  property var storePayloads: ({})
  property bool storesLoading: false
  property string storesError: ""
  property bool snapshotRefreshing: false
  property bool pendingRefresh: false
  property bool pendingDemo: false
  property bool pollStarted: false
  property bool demoMode: false
  property string snapshotMode: "cache"
  property string lastRefreshedAt: ""

  property var liveStoreDefs: []
  property var liveStorePayloads: ({})

  readonly property var firstStoreData: storeDefs.length > 0
    ? (storePayloads[storeDefs[0].key] || null)
    : null
  readonly property bool hasStores: storeDefs.length > 0
  readonly property bool iconActive: Model.iconActiveFromStore(firstStoreData)
  readonly property bool iconError: storesError !== "" && !hasStores
  readonly property bool iconMuted: !hasStores && storesError === ""
  readonly property string barTooltip: Model.barTooltipFromStores(storeDefs, storePayloads)

  readonly property string statusScript: Qt.resolvedUrl("bin/shopify-status").toString().replace("file://", "")

  function payloadForStoreKey(key) {
    return storePayloads[String(key || "")] || null
  }

  function applySnapshot(raw) {
    var snap = Model.parseSnapshot(raw)
    var replace = snapshotMode === "demo" || snapshotMode === "refresh"
    if (snap.stores.length > 0) {
      storeDefs = snap.stores
      storesError = ""
    } else if (!hasStores && snapshotRefreshing) {
      storesError = "No stores"
    }

    if (replace) {
      storePayloads = snap.payloads || {}
    } else {
      var next = Object.assign({}, storePayloads)
      var src = snap.payloads || {}
      for (var key in src) {
        if (!Object.prototype.hasOwnProperty.call(src, key)) continue
        next[key] = src[key]
      }
      storePayloads = next
    }
    storesLoading = false
    if (snapshotMode === "refresh" && snap.stores.length > 0)
      lastRefreshedAt = Qt.formatDateTime(new Date(), "hh:mm")
  }

  function toggleDemo() {
    if (demoMode) {
      demoMode = false
      pendingDemo = false
      if (liveStoreDefs.length > 0 || Object.keys(liveStorePayloads).length > 0) {
        storeDefs = liveStoreDefs
        storePayloads = liveStorePayloads
      }
      liveStoreDefs = []
      liveStorePayloads = {}
      return
    }
    liveStoreDefs = storeDefs.slice()
    liveStorePayloads = Object.assign({}, storePayloads)
    demoMode = true
    pendingRefresh = false
    runSnapshot("demo")
  }

  function runSnapshot(mode) {
    if (!statusScript) return
    if (mode === "refresh" && demoMode) return
    if (snapshotProc.running) {
      if (mode === "demo") pendingDemo = true
      else if (mode === "refresh") pendingRefresh = true
      return
    }
    snapshotMode = mode
    snapshotRefreshing = mode === "refresh"
    if ((snapshotRefreshing || mode === "demo") && !hasStores)
      storesLoading = true
    snapshotProc.command = ["bash", statusScript, mode]
    snapshotProc.running = true
  }

  function loadCache() {
    runSnapshot("cache")
  }

  function refreshInBackground() {
    if (demoMode) return
    runSnapshot("refresh")
  }

  function startPolling() {
    if (!pollStarted) {
      pollStarted = true
      refreshInBackground()
    }
    pollTimer.running = true
  }

  function loadShellConfig() {
    if (!statusScript) return
    shellConfigProc.command = [
      "bash",
      "-c",
      "jq -r '(.shopify.pollIntervalMinutes // 5)' \"${OMARCHY_SHELL_CONFIG:-$HOME/.config/omarchy/shell.json}\" 2>/dev/null || echo 5",
    ]
    shellConfigProc.running = true
  }

  function refresh() {
    if (demoMode)
      toggleDemo()
    refreshInBackground()
  }

  function open() {
    root.controller.show()
    startPolling()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Component.onCompleted: {
    loadShellConfig()
    loadCache()
    startPolling()
  }

  onOpenedChanged: {
    if (opened) {
      Qt.callLater(function() { popupKeyCatcher.forceActiveFocus() })
      refreshInBackground()
    }
  }

  Process {
    id: shellConfigProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var mins = parseInt(String(text || "").trim(), 10)
        if (!isNaN(mins) && mins > 0)
          root.pollIntervalMinutes = mins
      }
    }
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        var mode = root.snapshotMode
        root.snapshotRefreshing = false
        if (raw && (mode === "demo" || !root.demoMode))
          root.applySnapshot(raw)
        else if (!raw)
          root.storesLoading = false
        if (root.pendingDemo && root.demoMode) {
          root.pendingDemo = false
          root.runSnapshot("demo")
          return
        }
        if (root.pendingRefresh && !root.demoMode) {
          root.pendingRefresh = false
          root.refreshInBackground()
        }
      }
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Timer {
    id: pollTimer
    interval: root.pollIntervalMs
    running: root.pollStarted
    repeat: true
    onTriggered: root.refreshInBackground()
  }

  onPollIntervalMinutesChanged: pollTimer.restart()

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.startPolling(); return "ok" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: popupKeyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(popupColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: popupKeyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "d" || t === "D")
          root.toggleDemo()
        else if (t === "r" || t === "R")
          root.refresh()
      }

      Flickable {
        id: popupFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: popupColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: popupColumn
          width: popupFlick.width
          spacing: Style.space(16)

          Text {
            width: parent.width
            visible: root.storesLoading && !root.hasStores
            text: "Loading stores…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            width: parent.width
            visible: !root.storesLoading && !root.hasStores
            text: root.storesError || "No stores configured"
            color: root.urgent
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            visible: !root.storesLoading && !root.hasStores
            text: "Set shopify.apiUrl and pass show omarchy/ecommerce-data/api-token, or shopify.dataPath / shopify.stores."
            color: root.dim
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: root.hasStores && root.lastRefreshedAt !== ""
            text: "Updated " + root.lastRefreshedAt
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Column {
            width: parent.width
            visible: root.hasStores
            spacing: 0

            Repeater {
              model: root.storeDefs

              Column {
                required property var modelData
                required property int index

                width: parent.width
                spacing: Style.space(12)

                PanelSeparator {
                  width: parent.width
                  visible: index > 0
                  foreground: root.foreground
                }

                PopupStoreCard {
                  width: parent.width
                  title: root.demoMode ? "DEMO MODE" : String(modelData.title || modelData.key || "")
                  adminSlug: String(modelData.adminSlug || "")
                  iconPath: String(modelData.iconPath || "")
                  externalPayload: root.payloadForStoreKey(modelData.key)
                  foreground: root.foreground
                  urgent: root.urgent
                  accent: root.accent
                  dim: root.dim
                  surface: root.surface
                  fontFamily: root.fontFamily
                  palette: root.palette
                }
              }
            }
          }
        }
      }
    }
  }
}
