import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "i18n.js" as I18n

BarWidget {
  id: root
  moduleName: "taskwarrior-time"

  readonly property bool showWhenEmpty: setting("showWhenEmpty", true) === true
  readonly property int refreshIntervalSec: Math.max(5, Number(setting("refreshIntervalSec", 30)) || 30)

  property int pending: 0
  property int waiting: 0
  property int actionable: 0
  property bool hasActiveTimer: false
  property bool taskAvailable: true
  property string activeDescription: ""
  property string pillLabel: "\uf0ae"
  property string pillTooltip: ""
  property var lastSnapshot: ({})

  readonly property bool debugLogging: panelLoader.item ? panelLoader.item.debugLogging === true : false
  readonly property string debugLogPath: panelLoader.item ? String(panelLoader.item.debugLogPath || "") : ""
  readonly property string uiLanguage: panelLoader.item ? String(panelLoader.item.uiLanguage || "system") : "system"
  readonly property string localeName: {
    if (panelLoader.item && panelLoader.item.localeName)
      return String(panelLoader.item.localeName)
    var loc = Qt.locale()
    if (loc && loc.uiLanguages && loc.uiLanguages.length > 0)
      return String(loc.uiLanguages[0])
    return loc ? String(loc.name || "") : ""
  }

  function tr(key) {
    return I18n.t(key, root.localeName, root.uiLanguage)
  }

  function trCount(key, n) {
    return String(root.tr(key) || "").replace("%1", String(n))
  }

  // Bar tooltip: concise status only (Microsoft tray / infotip guidance —
  // useful summary, no redundant product name, short fragments).
  function composeTooltip(data) {
    data = data || {}
    if (data.available === false)
      return root.tr("missingTaskwarrior")

    var lines = []
    var active = String((data.active && data.active.description) || "").trim()
    if (active)
      lines.push(root.tr("tooltipTimer") + ": " + active)

    var overdue = Math.max(0, Number(data.actionable) || 0)
    var pendingCount = Math.max(0, Number(data.pending) || 0)
    var waitingCount = Math.max(0, Number(data.waiting) || 0)

    if (overdue > 0)
      lines.push(root.trCount("tooltipOverdue", overdue))

    var counts = []
    if (pendingCount > 0)
      counts.push(root.trCount("tooltipPending", pendingCount))
    if (waitingCount > 0)
      counts.push(root.trCount("tooltipWaiting", waitingCount))
    if (counts.length)
      lines.push(counts.join(" · "))

    if (!lines.length)
      lines.push(root.tr("tooltipIdle"))

    if (root.debugLogging)
      lines.push(root.tr("tooltipDebugOn") + " → " + (root.debugLogPath || "~/.local/share/taskwarrior-time/debug.log"))

    return lines.join("\n")
  }

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
    root.lastSnapshot = data || {}
    root.taskAvailable = data && data.available !== false
    root.pending = Math.max(0, Number(data && data.pending) || 0)
    root.waiting = Math.max(0, Number(data && data.waiting) || 0)
    root.actionable = Math.max(0, Number(data && data.actionable) || 0)
    root.hasActiveTimer = !!(data && data.active)
    root.activeDescription = String((data && data.active && data.active.description) || "")
    var count = root.pending
    root.pillLabel = count > 0 ? ("\uf0ae  " + String(count)) : "\uf0ae"
    if (data && data.label && !count)
      root.pillLabel = String(data.label)
    root.pillTooltip = root.composeTooltip(data)
  }

  function syncTooltip() {
    if (panelLoader.item && panelLoader.item.snapshot)
      root.applySnapshot(panelLoader.item.snapshot)
    else
      root.pillTooltip = root.composeTooltip(root.lastSnapshot)
  }

  visible: !taskAvailable || pending > 0 || waiting > 0 || hasActiveTimer || showWhenEmpty
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onDebugLoggingChanged: syncTooltip()
  onUiLanguageChanged: syncTooltip()
  onLocaleNameChanged: syncTooltip()

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
    function onUiLanguageChanged() { root.syncTooltip() }
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
    dimmed: root.taskAvailable && root.pending === 0 && root.waiting === 0 && !root.hasActiveTimer && !root.debugLogging
    tooltipText: root.pillTooltip

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.LeftButton)
        root.togglePanel()
    }
  }
}
