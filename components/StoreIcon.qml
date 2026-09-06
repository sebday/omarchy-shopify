import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property string iconPath: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real size: Style.font.display

  readonly property string imageSource: Model.iconFileUrl(iconPath)
  readonly property bool hasImage: imageSource !== ""

  implicitWidth: size
  implicitHeight: size

  Text {
    textFormat: Text.PlainText
    anchors.centerIn: parent
    visible: !root.hasImage || iconImage.status === Image.Error
    text: "󰒚"
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: root.size
    opacity: 0.92
  }

  Image {
    id: iconImage
    anchors.fill: parent
    visible: root.hasImage && status !== Image.Error
    source: root.imageSource
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(Math.round(root.size * 2), Math.round(root.size * 2))
  }
}
