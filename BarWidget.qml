import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "q.tasks"

  readonly property bool showWhenEmpty: setting("showWhenEmpty", true) === true
  readonly property int refreshIntervalSec: Math.max(5, Number(setting("refreshIntervalSec", 30)) || 30)

  property int pending: 0
  property bool hasActiveTimer: false
  property bool taskAvailable: true
  property string pillLabel: "\uf0ae"
  property string pillTooltip: ""

  readonly property bool debugLogging: panelLoader.item ? panelLoader.item.debugLogging === true : false
  readonly property string debugLogPath: panelLoader.item ? String(panelLoader.item.debugLogPath || "") : ""

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function applySnapshot(data) {
    root.taskAvailable = data && data.available !== false
    root.pending = Math.max(0, Number(data && data.pending) || 0)
    root.hasActiveTimer = !!(data && data.active)
    var count = root.pending
    root.pillLabel = count > 0 ? ("\uf0ae  " + String(count)) : "\uf0ae"
    if (data && data.label && !count)
      root.pillLabel = String(data.label)
    var tip = String((data && data.tooltip) || "")
    if (root.debugLogging)
      tip = (tip ? (tip + "\n") : "") + "Debug log ON → " + (root.debugLogPath || "~/.local/share/q.tasks/debug.log")
    root.pillTooltip = tip
  }

  function syncTooltip() {
    if (panelLoader.item && panelLoader.item.snapshot)
      root.applySnapshot(panelLoader.item.snapshot)
  }

  visible: !taskAvailable || pending > 0 || hasActiveTimer || showWhenEmpty
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onDebugLoggingChanged: syncTooltip()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
      if (panelLoader.item && panelLoader.item.snapshot)
        root.applySnapshot(panelLoader.item.snapshot)
    }
  }

  Connections {
    target: panelLoader.item
    function onSnapshotChanged() {
      if (panelLoader.item) root.applySnapshot(panelLoader.item.snapshot)
    }
    function onDebugLoggingChanged() { root.syncTooltip() }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var panel = panelLoader.item
      if (panel && (panel.formFocused || panel.datePickerCount > 0 || panel.expandedUuid))
        return
      root.refresh()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pillLabel
    fontSize: Style.font.caption
    active: root.hasActiveTimer || !root.taskAvailable || root.debugLogging
    activeColor: Color.accent
    useActiveColor: true
    dimmed: root.taskAvailable && root.pending === 0 && !root.hasActiveTimer && !root.debugLogging
    tooltipText: root.pillTooltip

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.LeftButton)
        root.togglePanel()
    }
  }
}
