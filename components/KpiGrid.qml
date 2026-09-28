import QtQuick
import qs.Commons

Item {
  id: root

  property var cells: []
  property color accent: "#89dceb"
  property color backgroundColor: "#1a1b26"
  property color mutedColor: "#565f89"
  property color textColor: "#a9b1d6"
  property string fontFamily: "monospace"

  signal chosen(string id)

  Grid {
    id: grid
    anchors.fill: parent
    columns: 5
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(10)

    Repeater {
      model: root.cells

      Item {
        required property var modelData
        required property int index

        width: Math.max(1, Math.floor((grid.width - grid.columnSpacing * 4) / 5))
        height: cellCol.implicitHeight

        Column {
          id: cellCol
          width: parent.width
          spacing: Style.space(2)

          Rectangle {
            width: parent.width
            height: labelText.implicitHeight + Style.space(2)
            color: modelData.selected ? root.accent : "transparent"

            Text {
              id: labelText
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: modelData.label
              color: modelData.selected ? root.backgroundColor : root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: modelData.value
            horizontalAlignment: Text.AlignRight
            rightPadding: Style.space(4)
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: modelData.clickable === true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.chosen(modelData.id)
        }
      }
    }
  }
}
