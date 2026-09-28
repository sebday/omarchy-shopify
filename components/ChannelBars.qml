import QtQuick
import qs.Commons

Column {
  id: root

  property var rows: []
  property color accent: "#89dceb"
  property color bright: "#c0caf5"
  property color mutedColor: "#565f89"
  property color textColor: "#a9b1d6"
  property string fontFamily: "monospace"

  spacing: Style.space(6)

  Repeater {
    model: root.rows

    Item {
      required property var modelData
      required property int index

      width: root.width
      height: Style.font.bodySmall + Style.space(4)

      Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(72)
        textFormat: Text.PlainText
        text: modelData.label
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(96)
        textFormat: Text.PlainText
        text: modelData.text
        horizontalAlignment: Text.AlignRight
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideLeft
      }

      Canvas {
        id: share
        anchors.left: labelText.right
        anchors.right: valueText.left
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
        readonly property real shareValue: {
          var n = Number(modelData.share)
          return isFinite(n) && n > 0 ? Math.min(1, n) : 0
        }
        property color accentColor: root.accent
        property color brightColor: root.bright

        canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
        antialiasing: true

        onShareValueChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAccentColorChanged: requestPaint()
        onBrightColorChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          if (ctx.reset) ctx.reset()
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
          ctx.clearRect(0, 0, width, height)
          if (width < 2 || shareValue <= 0) return
          var dot = 2.2
          var gap = 2
          var stride = dot + gap
          var count = Math.max(1, Math.floor((width + gap) / stride))
          var filled = Math.round(shareValue * count)
          if (filled < 1) filled = 1
          if (filled > count) filled = count
          var y = height / 2
          for (var i = 0; i < filled; i++) {
            var t = filled <= 1 ? 0 : i / (filled - 1)
            ctx.fillStyle = t < 0.35 ? root.bright : root.accent
            ctx.globalAlpha = t < 0.7 ? 1 : 0.75
            ctx.beginPath()
            ctx.arc(i * stride + dot / 2, y, dot / 2, 0, Math.PI * 2)
            ctx.fill()
          }
          ctx.globalAlpha = 1
        }
      }
    }
  }
}
