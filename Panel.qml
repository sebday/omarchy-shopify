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

  readonly property int pollIntervalMs: 300000

  property var storeDefs: []
  property var storePayloads: ({})
  property bool storesLoading: false
  property string storesError: ""
  property bool snapshotRefreshing: false
  property bool pendingRefresh: false
  property bool pollStarted: false

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
    if (snap.stores.length > 0) {
      storeDefs = snap.stores
      storesError = ""
    } else if (!hasStores && snapshotRefreshing) {
      storesError = "No stores"
    }

    var next = Object.assign({}, storePayloads)
    var src = snap.payloads || {}
    for (var key in src) {
      if (!Object.prototype.hasOwnProperty.call(src, key)) continue
      next[key] = src[key]
    }
    storePayloads = next
    storesLoading = false
  }

  function runSnapshot(mode) {
    if (!statusScript) return
    if (snapshotProc.running) {
      if (mode === "refresh") pendingRefresh = true
      return
    }
    snapshotRefreshing = mode === "refresh"
    if (snapshotRefreshing && !hasStores)
      storesLoading = true
    snapshotProc.command = ["bash", statusScript, mode]
    snapshotProc.running = true
  }

  function loadCache() {
    runSnapshot("cache")
  }

  function refreshInBackground() {
    runSnapshot("refresh")
  }

  function startPolling() {
    if (!pollStarted) {
      pollStarted = true
      refreshInBackground()
      pollTimer.running = true
    }
  }

  function refresh() {
    loadCache()
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

  Component.onCompleted: loadCache()

  onOpenedChanged: {
    if (opened)
      Qt.callLater(function() { popupKeyCatcher.forceActiveFocus() })
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw)
          root.applySnapshot(raw)
        else
          root.storesLoading = false
        root.snapshotRefreshing = false
        if (root.pendingRefresh) {
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
    running: false
    repeat: true
    onTriggered: root.refreshInBackground()
  }

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
            text: "Set shopify.dataPath in shell.json, or list stores under shopify.stores."
            color: root.dim
            wrapMode: Text.WordWrap
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
                  title: String(modelData.title || modelData.key || "")
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
