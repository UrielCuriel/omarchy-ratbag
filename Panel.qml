import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "urielcuriel.ratbag"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool busy: hostWidget ? hostWidget.loading || hostWidget.applying : false

  function open() {
    if (hostWidget) hostWidget.refresh(true)
    root.controller.show()
  }

  function close() {
    root.controller.hide()
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

  function profileOptions() {
    var options = []
    var count = hostWidget ? hostWidget.profileCount : 0
    for (var i = 0; i < count; i++) options.push({ value: String(i), label: String(i + 1) })
    return options
  }

  function pollingIndex() {
    if (!hostWidget) return 0
    var current = String(hostWidget.reportRate)
    for (var i = 0; i < hostWidget.reportRateOptions.length; i++) {
      if (String(hostWidget.reportRateOptions[i]) === current) return i
    }
    return 0
  }

  function pollingRateAt(index) {
    if (!hostWidget || hostWidget.reportRateOptions.length === 0) return 0
    var clamped = Math.max(0, Math.min(hostWidget.reportRateOptions.length - 1, Math.round(index)))
    return Number(hostWidget.reportRateOptions[clamped])
  }

  function dpiMinimum() {
    if (!hostWidget || hostWidget.dpiOptions.length === 0) return 100
    return Number(hostWidget.dpiOptions[0])
  }

  function dpiMaximum() {
    if (!hostWidget || hostWidget.dpiOptions.length === 0) return 25500
    return Number(hostWidget.dpiOptions[hostWidget.dpiOptions.length - 1])
  }

  function nearestDpi(value) {
    if (!hostWidget || hostWidget.dpiOptions.length === 0) return Math.round(value)
    var nearest = Number(hostWidget.dpiOptions[0])
    var distance = Math.abs(nearest - value)
    for (var i = 1; i < hostWidget.dpiOptions.length; i++) {
      var candidate = Number(hostWidget.dpiOptions[i])
      var candidateDistance = Math.abs(candidate - value)
      if (candidateDistance < distance) {
        nearest = candidate
        distance = candidateDistance
      }
    }
    return nearest
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(16)

        Row {
          width: parent.width
          spacing: Style.space(14)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: hostWidget ? hostWidget.statusIcon : "\uefba"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.displayLarge
          }

          Column {
            width: parent.width - Style.space(116)
            spacing: Style.space(3)

            Text {
              width: parent.width
              text: hostWidget ? hostWidget.deviceName : "Mouse"
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: hostWidget ? hostWidget.statusLabel : "Disconnected"
              textFormat: Text.PlainText
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: hostWidget && hostWidget.piperAvailable ? "Open Piper" : "Piper is required"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (hostWidget) hostWidget.launchPiper()
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.busy ? "…" : "󰑐"
            tooltipText: "Refresh"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            enabled: !root.busy
            onClicked: if (hostWidget) hostWidget.refresh(false)
          }
        }

        Column {
          visible: hostWidget && hostWidget.battery >= 0
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "BATTERY"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }
            Item { width: parent.width - batteryLabel.width - Style.space(70); height: 1 }
            Text {
              id: batteryLabel
              text: hostWidget ? hostWidget.battery + "%" : ""
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(7)
            radius: height / 2
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)

            Rectangle {
              width: parent.width * Math.max(0, Math.min(100, hostWidget ? hostWidget.battery : 0)) / 100
              height: parent.height
              radius: parent.radius
              color: hostWidget && hostWidget.battery <= 15
                ? Color.urgent
                : Style.selectedStateColor(root.contentForeground, Color.accent)
              Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
          }
        }

        Column {
          visible: hostWidget && hostWidget.connected
          width: parent.width
          spacing: Style.space(14)
          enabled: !root.busy
          opacity: enabled ? 1 : 0.55

          Column {
            width: parent.width
            spacing: Style.space(7)

            Text {
              text: "PROFILE"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }

            Row {
              width: parent.width
              spacing: Style.spacing.md

              Repeater {
                model: root.profileOptions()

                Button {
                  required property var modelData
                  width: (parent.width - parent.spacing * Math.max(0, root.profileOptions().length - 1))
                    / Math.max(1, root.profileOptions().length)
                  text: modelData.label
                  selected: hostWidget && String(hostWidget.activeProfile) === String(modelData.value)
                  bordered: true
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: if (hostWidget) hostWidget.applySetting("profile", modelData.value)
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.contentForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(dpiHeader.implicitHeight, dpiValue.implicitHeight)

              PanelSectionHeader {
                id: dpiHeader
                text: "DPI"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: dpiValue
                text: (dpiSlider.dragging
                  ? root.nearestDpi(dpiSlider.liveValue)
                  : (hostWidget ? hostWidget.dpi : 0)) + " DPI"
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              width: parent.width
              height: dpiSlider.implicitHeight + Style.spacing.controlGap
              foreground: root.contentForeground
              outline: true

              PanelSlider {
                id: dpiSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: root.dpiMinimum()
                maximum: root.dpiMaximum()
                step: 50
                integer: true
                value: hostWidget ? hostWidget.dpi : root.dpiMinimum()
                onReleased: function(value) {
                  if (hostWidget) hostWidget.applySetting("dpi", root.nearestDpi(value))
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.contentForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(pollingHeader.implicitHeight, pollingValue.implicitHeight)

              PanelSectionHeader {
                id: pollingHeader
                text: "POLLING RATE"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: pollingValue
                text: (pollingSlider.dragging
                  ? root.pollingRateAt(pollingSlider.liveValue)
                  : (hostWidget ? hostWidget.reportRate : 0)) + " Hz"
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              width: parent.width
              height: pollingSlider.implicitHeight + Style.spacing.controlGap
              foreground: root.contentForeground
              outline: true

              PanelSlider {
                id: pollingSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 0
                maximum: hostWidget ? Math.max(0, hostWidget.reportRateOptions.length - 1) : 0
                step: 1
                integer: true
                tickCount: hostWidget ? hostWidget.reportRateOptions.length : 0
                value: root.pollingIndex()
                onReleased: function(value) {
                  if (hostWidget) hostWidget.applySetting("rate", root.pollingRateAt(value))
                }
              }
            }
          }
        }

        Text {
          visible: hostWidget && !hostWidget.connected && !hostWidget.loading
          width: parent.width
          text: "Connect a libratbag-compatible mouse to manage its onboard profiles."
          textFormat: Text.PlainText
          color: Qt.darker(root.contentForeground, 1.35)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Text {
          visible: hostWidget && hostWidget.error !== ""
          width: parent.width
          text: hostWidget ? hostWidget.error : ""
          textFormat: Text.PlainText
          color: Color.urgent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
