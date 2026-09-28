import QtQuick
import qs.Commons
import "../Model.js" as Model

Item {
  id: root

  property var payload: null
  property string metric: "revenue"
  property string title: ""
  property color borderColor: "#89dceb"
  property color backgroundColor: "#1a1b26"
  property color mutedColor: "#565f89"
  property color textColor: "#a9b1d6"
  property color brightColor: "#c0caf5"
  property color hintColor: "#b9f27c"
  property color warnColor: "#f7768e"
  property string fontFamily: "monospace"

  signal metricChosen(string id)

  readonly property var safePayload: Model.asPayload(payload)
  readonly property bool payloadOk: safePayload.ok === true
  readonly property var cells: Model.kpiCells(safePayload, metric)
  readonly property var chartBars: Model.barsFor(safePayload, metric)
  readonly property string chartStyle: Model.metricById(metric).chartStyle
  readonly property string hoverLabel: Model.chartHoverLabel(chartBars, metric, Model.currency(safePayload))
  readonly property var channels: Model.channelRows(safePayload)
  readonly property real channelTotal: channels.total
  readonly property int kpiHeight: (Style.font.caption + Style.font.body + Style.space(10)) * 2 + Style.space(36)
  readonly property int channelHeight: Style.font.bodySmall * 4 + Style.space(64)

  Fieldset {
    id: kpiBox
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.kpiHeight
    number: 1
    legend: root.title
    borderColor: root.borderColor
    backgroundColor: root.backgroundColor
    mutedColor: root.mutedColor
    hintColor: root.hintColor
    fontFamily: root.fontFamily
    bottomLeft: root.payloadOk ? Model.kpiHeroMeta(root.safePayload.today) : ""
    hintKey: root.payloadOk ? "tab" : ""
    hintRest: root.payloadOk ? "to switch" : ""

    Text {
      anchors.fill: parent
      visible: !root.payloadOk
      textFormat: Text.PlainText
      text: root.safePayload.error || "No data"
      wrapMode: Text.WordWrap
      color: root.warnColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    KpiGrid {
      anchors.fill: parent
      visible: root.payloadOk
      cells: root.cells
      accent: root.borderColor
      backgroundColor: root.backgroundColor
      mutedColor: root.mutedColor
      textColor: root.textColor
      fontFamily: root.fontFamily
      onChosen: function(id) { root.metricChosen(id) }
    }
  }

  Fieldset {
    id: channelBox
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: root.channelTotal > 0 ? root.channelHeight : 0
    visible: root.channelTotal > 0
    number: 3
    legend: Model.channelsTitle(root.safePayload)
    borderColor: root.borderColor
    backgroundColor: root.backgroundColor
    mutedColor: root.mutedColor
    hintColor: root.hintColor
    fontFamily: root.fontFamily

    ChannelBars {
      anchors.fill: parent
      rows: root.channels.rows
      accent: root.borderColor
      bright: root.brightColor
      mutedColor: root.mutedColor
      textColor: root.textColor
      fontFamily: root.fontFamily
    }
  }

  Fieldset {
    anchors.top: kpiBox.bottom
    anchors.topMargin: Style.space(10)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: channelBox.visible ? channelBox.height + Style.space(10) : 0
    anchors.left: parent.left
    anchors.right: parent.right
    number: 2
    legend: Model.chartTitle(root.safePayload, root.metric)
    borderColor: root.borderColor
    backgroundColor: root.backgroundColor
    mutedColor: root.mutedColor
    hintColor: root.hintColor
    fontFamily: root.fontFamily
    bottomRight: root.hoverLabel

    Text {
      anchors.centerIn: parent
      visible: !root.chartBars || root.chartBars.length === 0
      textFormat: Text.PlainText
      text: "no data"
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    DotChart {
      anchors.fill: parent
      visible: root.chartBars && root.chartBars.length > 0
      bars: root.chartBars
      chartStyle: root.chartStyle
      accent: root.borderColor
      bright: root.brightColor
      muted: root.mutedColor
    }
  }
}
