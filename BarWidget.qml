import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "urielcuriel.ratbag"

  property bool connected: false
  property bool loading: false
  property bool applying: false
  property string deviceId: ""
  property string deviceName: "Mouse"
  property int activeProfile: -1
  property int profileCount: 0
  property int dpi: 0
  property var dpiOptions: []
  property int reportRate: 0
  property var reportRateOptions: []
  property int battery: -1
  property string batteryStatus: "Unknown"
  property bool batteryOnline: false
  property bool piperAvailable: false
  property string error: ""
  property string statusError: ""
  property string applyError: ""

  readonly property int maxInputLineLength: 8192
  readonly property int maxErrorLength: 2048

  readonly property bool charging: batteryStatus.toLowerCase() === "charging"
  readonly property bool charged: batteryStatus.toLowerCase() === "full"
  readonly property string statusLabel: !connected ? "Disconnected"
    : charging ? "Charging"
    : charged ? "Fully charged"
    : "In use"
  readonly property string mouseIcon: "\uefba"
  readonly property string statusIcon: !connected ? mouseIcon
    : charging ? "󰂄"
    : charged ? "󰁹"
    : mouseIcon

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function parseList(value, limit) {
    if (!value) return []
    return String(value).split(",").filter(function(entry) {
      return /^\d+$/.test(entry)
    }).slice(0, limit)
  }

  function boundedNumber(value, minimum, maximum, fallback) {
    var parsed = Number(value)
    if (!isFinite(parsed)) return fallback
    return Math.max(minimum, Math.min(maximum, parsed))
  }

  function appendError(current, line) {
    var chunk = String(line || "").substring(0, 512)
    if (chunk === "") return current
    return (current + (current === "" ? "" : "\n") + chunk).substring(0, maxErrorLength)
  }

  function escapeMarkup(value) {
    return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  function parseStatusLine(line) {
    var boundedLine = String(line || "").substring(0, maxInputLineLength)
    var separator = boundedLine.indexOf("\t")
    if (separator < 0) return
    var key = boundedLine.substring(0, Math.min(separator, 64))
    var value = boundedLine.substring(separator + 1).trim()

    if (key === "connected") connected = value === "1"
    else if (key === "device_id") deviceId = value.substring(0, 128)
    else if (key === "device_name") deviceName = value.substring(0, 256)
    else if (key === "profile") activeProfile = boundedNumber(value, -1, 15, -1)
    else if (key === "profile_count") profileCount = boundedNumber(value, 0, 16, 0)
    else if (key === "dpi") dpi = boundedNumber(value, 0, 100000, 0)
    else if (key === "dpis") dpiOptions = parseList(value, 256)
    else if (key === "rate") reportRate = boundedNumber(value, 0, 100000, 0)
    else if (key === "rates") reportRateOptions = parseList(value, 32)
    else if (key === "battery") battery = boundedNumber(value, -1, 100, -1)
    else if (key === "battery_status") batteryStatus = value.substring(0, 32)
    else if (key === "battery_online") batteryOnline = value === "1"
    else if (key === "piper_available") piperAvailable = value === "1"
  }

  function refresh(quiet) {
    if (statusProcess.running) return
    error = ""
    statusError = ""
    if (!quiet) loading = true
    statusProcess.running = true
  }

  function applySetting(kind, value) {
    if (!connected || applyProcess.running) return
    error = ""
    applyError = ""
    applying = true
    applyProcess.command = [Qt.resolvedUrl("ratbag-status").toString().replace("file://", ""), kind, String(value)]
    applyProcess.running = true
  }

  function launchPiper() {
    if (!piperAvailable) {
      error = "Piper is required for advanced button and macro configuration"
      return
    }

    Quickshell.execDetached([
      Qt.resolvedUrl("ratbag-status").toString().replace("file://", ""),
      "piper"
    ])
  }

  function open() {
    refresh(true)
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Process {
    id: statusProcess
    command: [Qt.resolvedUrl("ratbag-status").toString().replace("file://", ""), "status"]
    stdout: SplitParser { onRead: function(line) { root.parseStatusLine(line) } }
    stderr: SplitParser { onRead: function(line) { root.statusError = root.appendError(root.statusError, line) } }
    onExited: function(exitCode) {
      root.loading = false
      if (root.statusError !== "") root.error = root.statusError
      if (exitCode !== 0 && root.connected) root.error = root.error || "Unable to read mouse settings"
    }
  }

  Process {
    id: applyProcess
    stderr: SplitParser { onRead: function(line) { root.applyError = root.appendError(root.applyError, line) } }
    onExited: function(exitCode) {
      root.applying = false
      if (root.applyError !== "") root.error = root.applyError
      if (exitCode !== 0) root.error = root.error || "Unable to apply setting"
      refreshTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: 350
    repeat: false
    onTriggered: root.refresh(true)
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh(true)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName
    function inspect(): string {
      return JSON.stringify({
        connected: root.connected,
        device: root.deviceName,
        profile: root.activeProfile,
        dpi: root.dpi,
        pollingRate: root.reportRate,
        battery: root.battery,
        batteryStatus: root.batteryStatus,
        piperAvailable: root.piperAvailable,
        error: root.error
      })
    }
    function refresh(): void { root.refresh(false) }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.statusIcon
    dimmed: !root.connected
    tooltipText: root.connected
      ? root.escapeMarkup(root.deviceName) + " | " + root.statusLabel + (root.battery >= 0 ? " | " + root.battery + "%" : "")
      : "No supported mouse detected"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.refresh(false)
    }
  }
}
