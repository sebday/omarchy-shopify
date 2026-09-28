import QtQuick
import qs.Commons

Item {
  id: root

  property string legend: ""
  property int number: 0
  property color borderColor: "#89dceb"
  property color legendColor: borderColor
  property color backgroundColor: "#1a1b26"
  property color mutedColor: "#565f89"
  property string fontFamily: "monospace"
  property string bottomLeft: ""

  default property alias contentData: body.data

  function sup(n) {
    var marks = ["", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
    return n >= 1 && n < marks.length ? marks[n] : ""
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    radius: Style.space(8)
    border.width: 1
    border.color: root.borderColor
    antialiasing: true
  }

  Item {
    id: legendChip
    x: Style.space(14)
    y: -height / 2
    width: legendRow.width + Style.space(8)
    height: Math.max(legendText.implicitHeight, numText.implicitHeight)
    visible: root.legend !== ""

    Rectangle {
      anchors.fill: parent
      color: root.backgroundColor
    }

    Row {
      id: legendRow
      x: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        id: numText
        textFormat: Text.PlainText
        text: root.sup(root.number)
        color: root.legendColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        id: legendText
        textFormat: Text.PlainText
        text: root.legend
        color: root.legendColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }
  }

  Item {
    id: leftChip
    anchors.left: parent.left
    anchors.leftMargin: Style.space(14)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -height / 2
    width: leftText.width + Style.space(8)
    height: leftText.implicitHeight
    visible: root.bottomLeft !== ""

    Rectangle {
      anchors.fill: parent
      color: root.backgroundColor
    }

    Text {
      id: leftText
      x: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.bottomLeft
      color: root.borderColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Item {
    id: body
    anchors.fill: parent
    anchors.leftMargin: Style.space(14)
    anchors.rightMargin: Style.space(14)
    anchors.topMargin: Style.space(16)
    anchors.bottomMargin: Style.space(14)
  }
}
