import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

Item {
  id: root

  property string title: ""
  property string adminSlug: ""
  property string iconPath: ""
  property var externalPayload: null

  property color foreground: Color.foreground
  property color urgent: Color.urgent
  property color accent: Color.accent
  property color dim: Qt.darker(foreground, 1.4)
  property color surface: Color.popups.background
  property string fontFamily: Style.font.family
  property var palette: []

  readonly property var storeData: externalPayload || ({})
  readonly property bool loading: !externalPayload
  readonly property string adminUrl: adminSlug !== ""
    ? "https://admin.shopify.com/store/" + adminSlug + "/analytics/live"
    : ""
  readonly property bool hasLiveAnalyticsLink: adminUrl !== ""
  readonly property bool hasStoreData: !!(storeData && storeData.ok)
  readonly property var todayDetail: hasStoreData ? (storeData.todayDetail || {}) : {}
  readonly property var period: hasStoreData ? (storeData.period || {}) : {}
  readonly property string currency: hasStoreData ? String(storeData.symbol || "£") : "£"
  readonly property var revenueBars: hasStoreData
    ? Model.themeBarArray(storeData.bars, palette)
    : []
  readonly property string errorText: storeData && storeData.error ? String(storeData.error) : ""

  implicitHeight: body.implicitHeight
  implicitWidth: parent ? parent.width : 0

  function openAdmin() {
    if (!adminUrl) return
    Quickshell.execDetached(["xdg-open", adminUrl])
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(12)

    MouseArea {
      width: parent.width
      implicitHeight: hero.implicitHeight
      enabled: root.hasLiveAnalyticsLink
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.openAdmin()

      PanelHero {
        id: hero
        width: parent.width
        title: root.title
        meta: root.hasStoreData
          ? Model.kpiHeroMeta(root.todayDetail, root.hasLiveAnalyticsLink)
          : (root.errorText || "Shopify")
        foreground: root.foreground
        fontFamily: root.fontFamily

        iconComponent: Component {
          StoreIcon {
            iconPath: root.iconPath
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            size: Style.font.display
          }
        }
      }
    }

    Text {
      width: parent.width
      visible: !root.hasStoreData && !root.loading && root.errorText !== ""
      text: root.errorText
      color: root.urgent
      wrapMode: Text.WordWrap
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    GridLayout {
      width: parent.width
      visible: root.hasStoreData
      columns: 4
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(8)

      StatTile {
        Layout.fillWidth: true
        label: "Revenue"
        value: Model.statTodayRevenue(root.storeData, root.todayDetail, root.currency)
      }

      StatTile {
        Layout.fillWidth: true
        label: "Orders"
        value: Model.statOrders(root.todayDetail, root.storeData)
      }

      StatTile {
        Layout.fillWidth: true
        label: "CoS"
        value: String(root.todayDetail.cos || root.storeData.cos || "—")
      }

      StatTile {
        Layout.fillWidth: true
        label: (root.period.days || 30) + "d revenue"
        value: root.period.revenue !== undefined
          ? Model.formatRevenue(root.period.revenue, root.currency)
          : "—"
        valueColor: root.foreground
      }
    }

    BorderSurface {
      width: parent.width
      visible: root.revenueBars.length > 0
      implicitHeight: chartColumn.implicitHeight + Style.spacing.lg + Style.spacing.xs
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
      radius: Style.cornerRadius
      clip: true

      Column {
        id: chartColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.spacing.lg
        anchors.rightMargin: Style.spacing.lg
        anchors.topMargin: Style.spacing.lg
        anchors.bottomMargin: Style.spacing.xs
        spacing: 0

        Text {
          width: parent.width
          visible: chart.hasTooltip
          text: chart.tooltipLabel
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        Item {
          width: parent.width
          height: Style.font.caption
        }

        RevenueBarChart {
          id: chart
          width: parent.width
          height: implicitHeight
          bars: root.revenueBars
          currency: root.currency
          foreground: root.foreground
          accent: root.accent
          background: root.surface
          fontFamily: root.fontFamily
        }
      }
    }
  }

  component StatTile: BorderSurface {
    property string label: ""
    property string value: ""
    property color valueColor: root.accent

    implicitHeight: tileColumn.implicitHeight + Style.spacing.lg * 2
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
    radius: Style.cornerRadius

    Column {
      id: tileColumn
      anchors.centerIn: parent
      width: parent.width - Style.spacing.lg * 2
      spacing: Style.spacing.labelGap

      Text {
        width: parent.width
        text: value
        color: valueColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }
}
