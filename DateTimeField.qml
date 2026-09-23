import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "DateTimeModel.js" as DT

// Text field + calendar/time popup. Keyboard entry stays primary;
// the picker writes YYYY-MM-DD or YYYY-MM-DDTHH:mm into the field.
Item {
  id: root

  property alias text: field.text
  property string placeholderText: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool includeTime: true
  property int weekStart: Qt.locale().firstDayOfWeek
  // Panel host for key-catcher blocking while the popup is open
  property var host: null

  property string trToday: "Today"
  property string trClear: "Clear"
  property string trApply: "Apply"
  property string trTime: "Time"

  readonly property bool popupOpen: popup.visible
  readonly property bool fieldFocused: field.activeFocus

  signal accepted()
  signal editingFinished()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property int pickHour: 9
  property int pickMinute: 0
  property string selectedKey: ""
  property bool _countedOpen: false

  readonly property string todayKey: DT.formatDate(new Date())
  readonly property var cells: DT.monthGrid(viewYear, viewMonth, weekStart, selectedKey, todayKey)
  readonly property var weekdayLabels: DT.weekdayLabels(weekStart, Qt.locale())
  readonly property string monthTitle: Qt.locale().standaloneMonthName(viewMonth) + " " + viewYear

  function setHostPickerOpen(on) {
    if (!host || !("datePickerCount" in host)) return
    if (on && !_countedOpen) {
      host.datePickerCount = host.datePickerCount + 1
      _countedOpen = true
    } else if (!on && _countedOpen) {
      host.datePickerCount = Math.max(0, host.datePickerCount - 1)
      _countedOpen = false
    }
  }

  function openPicker() {
    var parsed = DT.parseFlexible(field.text)
    var base = parsed || new Date()
    viewYear = base.getFullYear()
    viewMonth = base.getMonth()
    selectedKey = DT.formatDate(base)
    pickHour = parsed ? base.getHours() : 9
    pickMinute = parsed ? base.getMinutes() : 0
    hourField.value = pickHour
    minuteField.value = pickMinute
    popup.open()
  }

  // Close without writing the field — only Apply commits.
  function discardPicker() {
    popup.close()
  }

  function togglePicker() {
    if (popup.visible) {
      discardPicker()
      return
    }
    // Pressing the icon while open closes via CloseOnPressOutside first;
    // ignore the immediate reopen from the same click.
    if (Date.now() - root._closedAt < 250) return
    openPicker()
  }

  function applySelection() {
    if (!selectedKey) return
    var parts = selectedKey.split("-")
    if (parts.length !== 3) return
    var d = new Date(+parts[0], +parts[1] - 1, +parts[2], pickHour, pickMinute, 0)
    field.text = includeTime ? DT.formatDateTime(d) : DT.formatDate(d)
    popup.close()
    root.editingFinished()
  }

  function clearSelection() {
    field.text = ""
    selectedKey = ""
    popup.close()
    root.editingFinished()
  }

  function pickToday() {
    var n = new Date()
    selectedKey = DT.formatDate(n)
    viewYear = n.getFullYear()
    viewMonth = n.getMonth()
    if (includeTime) {
      pickHour = n.getHours()
      pickMinute = n.getMinutes()
      hourField.value = pickHour
      minuteField.value = pickMinute
    }
  }

  property real _closedAt: 0

  Component.onDestruction: setHostPickerOpen(false)

  Row {
    id: row
    width: root.width > 0 ? root.width : implicitWidth
    spacing: Style.space(4)

    TextField {
      id: field
      width: Math.max(Style.space(80), parent.width - calBtn.width - parent.spacing)
      foreground: root.foreground
      accent: root.accent
      placeholderText: root.placeholderText
      verticalPadding: Style.space(2)
      font.family: root.fontFamily
      onAccepted: root.accepted()
      onEditingFinished: root.editingFinished()
      onActiveFocusChanged: {
        if (host) host.formFocused = activeFocus || root.popupOpen
      }
    }

    Button {
      id: calBtn
      text: "󰃭"
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      verticalPadding: Style.space(2)
      horizontalPadding: Style.space(8)
      onClicked: root.togglePicker()
    }
  }

  Popup {
    id: popup
    x: 0
    y: root.height + Style.space(4)
    width: Style.space(280)
    padding: Style.space(10)
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    onVisibleChanged: {
      root.setHostPickerOpen(visible)
      if (host) host.formFocused = visible || field.activeFocus
      if (!visible) root._closedAt = Date.now()
    }

    background: BorderSurface {
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius
    }

    contentItem: Column {
      width: popup.availableWidth
      spacing: Style.space(8)

      Row {
        width: parent.width
        spacing: Style.space(4)

        Button {
          text: "‹"
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.title
          verticalPadding: Style.space(1)
          horizontalPadding: Style.space(8)
          onClicked: {
            var n = DT.stepMonth(root.viewYear, root.viewMonth, -1)
            root.viewYear = n.year
            root.viewMonth = n.month
          }
        }

        Text {
          width: parent.width - Style.space(80)
          text: root.monthTitle
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
        }

        Button {
          text: "›"
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.title
          verticalPadding: Style.space(1)
          horizontalPadding: Style.space(8)
          onClicked: {
            var n = DT.stepMonth(root.viewYear, root.viewMonth, 1)
            root.viewYear = n.year
            root.viewMonth = n.month
          }
        }
      }

      Row {
        width: parent.width
        spacing: 0
        Repeater {
          model: root.weekdayLabels
          Text {
            required property string modelData
            width: parent.width / 7
            text: modelData
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      Grid {
        id: dayGrid
        width: parent.width
        columns: 7
        rowSpacing: Style.space(2)
        columnSpacing: 0

        Repeater {
          model: root.cells
          Item {
            required property var modelData
            width: dayGrid.width / 7
            height: Style.space(28)

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: Style.cornerRadius
              visible: modelData.inMonth
              color: modelData.selected
                ? Style.hoverFillFor(root.foreground, root.accent)
                : (dayMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
              border.width: modelData.today && !modelData.selected ? 1 : 0
              border.color: root.accent

              Text {
                anchors.centerIn: parent
                text: modelData.inMonth ? String(modelData.day) : ""
                color: modelData.selected ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: modelData.today || modelData.selected
              }

              MouseArea {
                id: dayMouse
                anchors.fill: parent
                enabled: modelData.inMonth
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedKey = modelData.key
              }
            }
          }
        }
      }

      Row {
        visible: root.includeTime
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: root.trTime
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        NumberField {
          id: hourField
          label: ""
          width: Style.space(64)
          fieldWidth: Style.space(56)
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          value: root.pickHour
          from: 0
          to: 23
          onModified: function(v) { root.pickHour = v }
        }

        Text {
          text: ":"
          color: root.foreground
          font.family: root.fontFamily
          anchors.verticalCenter: parent.verticalCenter
        }

        NumberField {
          id: minuteField
          label: ""
          width: Style.space(64)
          fieldWidth: Style.space(56)
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          value: root.pickMinute
          from: 0
          to: 59
          onModified: function(v) { root.pickMinute = v }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Button {
          text: root.trToday
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: root.pickToday()
        }
        Button {
          text: root.trClear
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: root.clearSelection()
        }
        Item {
          width: Math.max(0, parent.width - Style.space(200))
          height: 1
        }
        Button {
          text: root.trApply
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          selected: true
          onClicked: root.applySelection()
        }
      }
    }
  }
}
