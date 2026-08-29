import QtQuick
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var bars: []
  property string currency: "£"
  property int tooltipIndex: -1

  property color foreground: "#cdd6f4"
  property color accent: "#89b4fa"
  property color background: "#1e1e2e"
  property string fontFamily: "sans-serif"

  onBarsChanged: tooltipIndex = -1

  readonly property var tooltipBar: {
    if (tooltipIndex < 0 || tooltipIndex >= bars.length)
      return null
    return bars[tooltipIndex]
  }

  readonly property bool hasTooltip: tooltipBar !== null

  readonly property string tooltipLabel: {
    if (!tooltipBar)
      return ""
    var parts = []
    var date = tooltipDate(tooltipBar)
    if (date !== "")
      parts.push(date)
    var value = tooltipValue(tooltipBar)
    if (value !== "")
      parts.push(value)
    var orders = tooltipOrders(tooltipBar)
    if (orders !== "")
      parts.push(orders)
    return parts.join(" · ")
  }

  readonly property int padInset: 6
  readonly property int plotTopInset: padInset

  readonly property real plotWidth: Math.max(0, width - padInset * 2)

  readonly property real slotWidth: bars.length > 0 && plotWidth > 0
    ? plotWidth / bars.length
    : 0

  readonly property real effectiveBarWidth: Math.max(3, slotWidth - 2)

  function withOpacity(color, alpha) {
    var c = Qt.color(color)
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }

  function barColor(bar) {
    return Qt.color(bar && bar.color ? bar.color : accent)
  }

  function barColorAlpha(bar, alpha) {
    var c = barColor(bar)
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }

  function barScaleMax() {
    var pts = bars || []
    var maxV = 0
    for (var i = 0; i < pts.length; i++) {
      var v = parseFloat(pts[i] && pts[i].value)
      if (!isNaN(v) && v > maxV)
        maxV = v
    }
    return maxV > 0 ? maxV : 1
  }

  function barHeightFor(bar, plotH) {
    var val = parseFloat(bar && bar.value)
    if (isNaN(val) || val < 0)
      val = 0
    var maxV = barScaleMax()
    if (val <= 0)
      return Math.max(2, plotH * 0.02)
    return Math.max(2, plotH * val / maxV)
  }

  function barIsEmpty(bar) {
    var val = parseFloat(bar && bar.value)
    return isNaN(val) || val <= 0
  }

  function tooltipDate(bar) {
    if (!bar || !bar.date)
      return ""
    return Model.formatDay(bar.date)
  }

  function tooltipValue(bar) {
    if (!bar || bar.value === undefined || bar.value === null)
      return ""
    var n = parseFloat(bar.value)
    if (isNaN(n))
      return ""
    return Model.formatRevenue(n, currency)
  }

  function tooltipOrders(bar) {
    var n = parseInt(bar && bar.orders, 10)
    if (isNaN(n))
      return ""
    if (n <= 0)
      return "0 orders"
    return n + " orders"
  }

  Rectangle {
    visible: root.hasTooltip
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    z: 2
    implicitWidth: tooltipText.implicitWidth + Style.spacing.lg * 2
    implicitHeight: tooltipText.implicitHeight + Style.spacing.lg
    radius: Style.cornerRadius
    color: root.background

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: root.tooltipLabel
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Item {
    id: plotArea
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: padInset
    anchors.rightMargin: padInset
    anchors.bottomMargin: padInset
    anchors.topMargin: root.plotTopInset

    Repeater {
      model: 3

      Rectangle {
        required property int index
        anchors.left: parent.left
        anchors.right: parent.right
        y: parent.height * (index + 1) / 4
        height: 1
        color: root.withOpacity(root.foreground, 0.05)
      }
    }

    Row {
      id: chartRow
      anchors.fill: parent
      spacing: 0

      Repeater {
        model: root.bars

        Item {
          id: barCell
          required property var modelData
          required property int index

          width: root.slotWidth
          height: chartRow.height

          readonly property bool cellHovered: hitArea.containsMouse
            || root.tooltipIndex === index

          readonly property bool emptyDay: root.barIsEmpty(modelData)
          readonly property real plotH: plotArea.height

          Rectangle {
            anchors.fill: parent
            visible: barCell.cellHovered
            radius: Style.cornerRadius
            color: root.withOpacity(root.barColor(barCell.modelData), 0.1)
            border.width: 1
            border.color: root.withOpacity(root.barColor(barCell.modelData), 0.35)
          }

          Rectangle {
            visible: barCell.emptyDay
            width: Math.min(root.effectiveBarWidth, parent.width - 1)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            height: root.barHeightFor(modelData, barCell.plotH)
            radius: Style.cornerRadius
            color: root.withOpacity(root.foreground, barCell.cellHovered ? 0.28 : 0.14)
            border.width: barCell.cellHovered ? 1 : 0
            border.color: root.withOpacity(root.foreground, 0.35)
          }

          Rectangle {
            visible: !barCell.emptyDay
            width: Math.min(root.effectiveBarWidth, parent.width - 1)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            height: root.barHeightFor(modelData, barCell.plotH)
            radius: Style.cornerRadius
            transformOrigin: Item.Bottom
            scale: barCell.cellHovered ? 1.06 : 1
            opacity: barCell.cellHovered ? 1 : 0.82
            border.width: barCell.cellHovered ? 2 : 0
            border.color: root.barColor(barCell.modelData)

            Behavior on scale {
              NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
              }
            }

            gradient: Gradient {
              orientation: Gradient.Vertical
              GradientStop {
                position: 0
                color: root.barColorAlpha(
                  modelData,
                  barCell.cellHovered ? 1 : 0.9)
              }
              GradientStop {
                position: 1
                color: root.barColorAlpha(
                  modelData,
                  barCell.cellHovered ? 0.72 : 0.4)
              }
            }
          }

          MouseArea {
            id: hitArea
            anchors.fill: parent
            z: 1
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
              if (containsMouse)
                root.tooltipIndex = index
              else if (root.tooltipIndex === index)
                root.tooltipIndex = -1
            }
            onClicked: root.tooltipIndex = index
          }
        }
      }
    }
  }
}
