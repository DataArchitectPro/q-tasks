import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "i18n.js" as I18n

Panel {
  id: root
  moduleName: "q.tasks"
  ipcTarget: "q.tasks"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var snapshot: ({
    ok: true,
    available: true,
    tasks: [],
    projects: [],
    pending: 0,
    actionable: 0,
    active: null,
    label: "\uf0ae",
    tooltip: ""
  })

  property string viewMode: "tasks" // tasks | projects
  property string filter: setting("defaultFilter", "all")
  property string groupBy: setting("defaultGroupBy", "project")
  property string expandedUuid: ""
  property string pendingDeleteUuid: ""
  property string pendingClearProject: ""
  property string projectFilter: ""
  property int cursorIndex: -1
  property bool cursorActive: false
  property string busyUuid: ""
  property string lastError: ""

  property bool formFocused: false

  // Add form
  property string addDescription: ""
  property string addPriority: ""
  property string addProject: ""
  property string addScheduled: ""
  property string addDue: ""
  property bool showAddExtras: false

  // Project form
  property string newProjectName: ""
  property string renameFrom: ""
  property string renameTo: ""

  readonly property string localeName: Qt.locale().name
  function tr(key) { return I18n.t(key, root.localeName) }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string helperPath: {
    var value = String(Qt.resolvedUrl("bin/q-tasks"))
    if (value.indexOf("file://") === 0) return decodeURIComponent(value.substring(7))
    return value
  }

  readonly property var filteredTasks: {
    var tasks = (snapshot && snapshot.tasks) ? snapshot.tasks : []
    if (projectFilter) {
      tasks = tasks.filter(function (t) { return t.project === projectFilter })
    }
    return tasks
  }

  readonly property var groups: Model.buildGroups(filteredTasks, filter, groupBy, tr)
  readonly property var rows: Model.flattenRows(groups)
  readonly property var projectList: (snapshot && snapshot.projects) ? snapshot.projects : []

  readonly property string label: snapshot && snapshot.label ? snapshot.label : "\uf0ae"

  function open() {
    root.controller.show()
    refresh()
  }

  function openFromHotkey() {
    root.controller.show()
    refresh()
  }

  function close() {
    confirmDelete.opened = false
    confirmClear.opened = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function applyData(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      root.snapshot = data
      root.lastError = data.error ? String(data.error) : ""
    } catch (e) {
      root.lastError = String(e)
      console.warn("q.tasks: bad JSON", e)
    }
  }

  function refresh() {
    if (!exportProc.running) {
      exportProc.command = [root.helperPath, "export"]
      exportProc.running = true
    }
  }

  function runCmd(args) {
    if (cmdProc.running) return
    cmdProc.command = [root.helperPath].concat(args)
    cmdProc.running = true
  }

  function addTask() {
    var desc = addField.text.trim()
    if (!desc) return
    if (!Model.datesValid(addScheduledField.text.trim(), addDueField.text.trim())) {
      root.lastError = "scheduled > due"
      return
    }
    var args = ["add", "--description", desc]
    if (priorityCombo.value) args.push("--priority", priorityCombo.value)
    if (projectCombo.value) args.push("--project", projectCombo.value)
    var sched = addScheduledField.text.trim()
    var due = addDueField.text.trim()
    if (sched) args.push("--scheduled", sched)
    if (due) args.push("--due", due)
    addField.text = ""
    addScheduledField.text = ""
    addDueField.text = ""
    runCmd(args)
  }

  function toggleDone(task) {
    if (!task || !task.uuid) return
    root.busyUuid = task.uuid
    if (task.status === "completed")
      runCmd(["status", "--uuid", task.uuid, "--status", "pending"])
    else
      runCmd(["done", "--uuid", task.uuid])
  }

  function toggleTimer(task) {
    if (!task || !task.uuid) return
    root.busyUuid = task.uuid
    if (task.timerActive) runCmd(["stop", "--uuid", task.uuid])
    else runCmd(["start", "--uuid", task.uuid])
  }

  function requestDelete(task) {
    if (!task || !task.uuid) return
    pendingDeleteUuid = task.uuid
    confirmDelete.opened = true
  }

  function confirmDeleteTask() {
    confirmDelete.opened = false
    if (!pendingDeleteUuid) return
    root.busyUuid = pendingDeleteUuid
    runCmd(["delete", "--uuid", pendingDeleteUuid])
    pendingDeleteUuid = ""
    expandedUuid = ""
  }

  function saveTask(task, desc, project, priority, scheduled, due) {
    if (!task || !task.uuid) return
    if (!desc || !String(desc).trim()) return
    if (!Model.datesValid(scheduled, due)) {
      root.lastError = "scheduled > due"
      return
    }
    root.busyUuid = task.uuid
    var args = ["modify", "--uuid", task.uuid, "--description", String(desc).trim()]
    args.push("--project", project === undefined || project === null ? "" : String(project))
    args.push("--priority", priority === undefined || priority === null ? "" : String(priority))
    args.push("--scheduled", scheduled === undefined || scheduled === null ? "" : String(scheduled).trim())
    args.push("--due", due === undefined || due === null ? "" : String(due).trim())
    runCmd(args)
  }

  function setStatus(task, status) {
    if (!task || !task.uuid) return
    root.busyUuid = task.uuid
    runCmd(["status", "--uuid", task.uuid, "--status", status])
  }

  function addDependency(task, depId) {
    if (!task || !task.uuid || !depId) return
    root.busyUuid = task.uuid
    runCmd(["deps", "--uuid", task.uuid, "--add", String(depId)])
  }

  function removeDependency(task, depId) {
    if (!task || !task.uuid || !depId) return
    root.busyUuid = task.uuid
    runCmd(["deps", "--uuid", task.uuid, "--remove", String(depId)])
  }

  function renameProject() {
    var from = renameFrom
    var to = renameTo.trim()
    if (!from || !to || to.indexOf(":") >= 0) return
    runCmd(["projects", "rename", "--old", from, "--new", to])
    renameFrom = ""
    renameTo = ""
  }

  function requestClearProject(name) {
    pendingClearProject = name
    confirmClear.opened = true
  }

  function confirmClearProjectAction() {
    confirmClear.opened = false
    if (!pendingClearProject) return
    runCmd(["projects", "clear", "--old", pendingClearProject])
    if (projectFilter === pendingClearProject) projectFilter = ""
    pendingClearProject = ""
  }

  function createProjectName() {
    var name = newProjectField.text.trim()
    if (!name || name.indexOf(":") >= 0) return
    // Projects materialize when assigned; stash as selected add-project.
    projectCombo.value = name
    newProjectField.text = ""
    viewMode = "tasks"
    showAddExtras = true
  }

  function moveCursor(dy) {
    cursorActive = true
    if (rows.length === 0) {
      cursorIndex = -1
      return
    }
    var next = cursorIndex
    if (next < 0) next = dy > 0 ? 0 : rows.length - 1
    else next = Math.max(0, Math.min(rows.length - 1, next + dy))
    // Skip headers when moving
    var guard = 0
    while (guard < rows.length && rows[next] && rows[next].type === "header") {
      next = Math.max(0, Math.min(rows.length - 1, next + (dy >= 0 ? 1 : -1)))
      guard++
    }
    cursorIndex = next
    listView.positionViewAtIndex(cursorIndex, ListView.Contain)
  }

  function activateCursor() {
    var t = selectedTask()
    if (t) toggleDone(t)
  }

  function expandCursor() {
    if (cursorIndex < 0 || cursorIndex >= rows.length) return
    var row = rows[cursorIndex]
    if (row.type !== "task") return
    expandedUuid = expandedUuid === row.task.uuid ? "" : row.task.uuid
  }

  property bool enterExpand: false

  function selectedTask() {
    if (cursorIndex < 0 || cursorIndex >= rows.length) return null
    var row = rows[cursorIndex]
    return row && row.type === "task" ? row.task : null
  }

  Process {
    id: exportProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyData(text)
    }
  }

  Process {
    id: cmdProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.busyUuid = ""
        root.applyData(text)
      }
    }
    onExited: function(code) {
      root.busyUuid = ""
      if (code !== 0) root.refresh()
    }
  }

  // Bar button is on BarWidget; this panel is loaded hidden.
  Item {
    width: 0
    height: 0
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: confirmDelete.opened || confirmClear.opened || root.formFocused
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: {
        if (root.enterExpand) {
          root.enterExpand = false
          root.expandCursor()
          return
        }
        root.activateCursor()
      }
      onReturnRequested: { root.enterExpand = true }
      onDeleteRequested: {
        var t = root.selectedTask()
        if (t) root.requestDelete(t)
      }
      onTextKey: function(ch) {
        var t = root.selectedTask()
        if (!t) return
        if (ch === "t" || ch === "T") root.toggleTimer(t)
        if (ch === "e" || ch === "E") root.expandCursor()
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(10)

        // Header
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: root.tr("title")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: String(root.snapshot.pending || 0)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Item { width: Style.space(8); height: 1 }

          Button {
            text: root.tr("viewTasks")
            selected: root.viewMode === "tasks"
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            verticalPadding: Style.space(2)
            horizontalPadding: Style.space(8)
            onClicked: root.viewMode = "tasks"
          }
          Button {
            text: root.tr("viewProjects")
            selected: root.viewMode === "projects"
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            verticalPadding: Style.space(2)
            horizontalPadding: Style.space(8)
            onClicked: root.viewMode = "projects"
          }
        }

        Text {
          visible: root.lastError !== ""
          width: parent.width
          text: root.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // Tasks view controls
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.viewMode === "tasks"

          // Filters
          Row {
            spacing: Style.space(4)
            Repeater {
              model: [
                { v: "all", k: "filterAll" },
                { v: "active", k: "filterActive" },
                { v: "today", k: "filterToday" },
                { v: "done", k: "filterDone" }
              ]
              Button {
                required property var modelData
                text: root.tr(modelData.k)
                selected: root.filter === modelData.v
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(8)
                onClicked: root.filter = modelData.v
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: root.tr("groupBy")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            Dropdown {
              id: groupDropdown
              width: Style.space(140)
              foreground: root.foreground
              fontFamily: root.fontFamily
              value: root.groupBy
              options: [
                { value: "none", label: root.tr("groupNone") },
                { value: "project", label: root.tr("groupProject") },
                { value: "priority", label: root.tr("groupPriority") },
                { value: "due", label: root.tr("groupDue") },
                { value: "status", label: root.tr("groupStatus") }
              ]
              onChanged: function(v) { root.groupBy = v }
            }

            Item { Layout.fillWidth: true; width: parent.width - Style.space(280); height: 1 }
          }

          // Quick add
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: addField
                width: parent.width - addBtn.width - Style.space(6)
                foreground: root.foreground
                placeholderText: root.tr("addPlaceholder")
                verticalPadding: Style.space(4)
                onActiveFocusChanged: root.formFocused = activeFocus || addScheduledField.activeFocus || addDueField.activeFocus
                onAccepted: root.addTask()
              }

              Button {
                id: addBtn
                text: "+"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.title
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(10)
                onClicked: root.addTask()
              }
            }

            Button {
              text: root.showAddExtras ? "▾" : "▸"
              foreground: root.dim
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.space(1)
              horizontalPadding: Style.space(6)
              onClicked: root.showAddExtras = !root.showAddExtras
            }

            GridLayout {
              visible: root.showAddExtras
              width: parent.width
              columns: 2
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)

              Text {
                text: root.tr("priority")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Dropdown {
                id: priorityCombo
                Layout.fillWidth: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                value: ""
                options: [
                  { value: "", label: root.tr("priorityNone") },
                  { value: "H", label: "H" },
                  { value: "M", label: "M" },
                  { value: "L", label: "L" }
                ]
              }

              Text {
                text: root.tr("project")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Dropdown {
                id: projectCombo
                Layout.fillWidth: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                value: ""
                options: {
                  var opts = [{ value: "", label: root.tr("projectNone") }]
                  for (var i = 0; i < root.projectList.length; i++)
                    opts.push({ value: root.projectList[i], label: root.projectList[i] })
                  return opts
                }
              }

              Text {
                text: root.tr("startDate")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              TextField {
                id: addScheduledField
                Layout.fillWidth: true
                foreground: root.foreground
                placeholderText: root.tr("datesHint")
                verticalPadding: Style.space(2)
                onActiveFocusChanged: root.formFocused = activeFocus || addField.activeFocus || addDueField.activeFocus
              }

              Text {
                text: root.tr("endDate")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              TextField {
                id: addDueField
                Layout.fillWidth: true
                foreground: root.foreground
                placeholderText: root.tr("datesHint")
                verticalPadding: Style.space(2)
                onActiveFocusChanged: root.formFocused = activeFocus || addField.activeFocus || addScheduledField.activeFocus
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // Task list
          ListView {
            id: listView
            width: parent.width
            height: Math.min(Style.space(320), Math.max(Style.space(120), contentHeight))
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            spacing: Style.space(2)
            model: root.rows

            ScrollBar.vertical: ScrollBar {
              policy: listView.contentHeight > listView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Item {
              id: rowRoot
              required property var modelData
              required property int index
              width: listView.width
              height: rowCol.implicitHeight

              readonly property bool isHeader: modelData.type === "header"
              readonly property var task: modelData.task
              readonly property bool expanded: !isHeader && task && root.expandedUuid === task.uuid
              readonly property bool hasCursor: root.cursorActive && root.cursorIndex === index

              Column {
                id: rowCol
                width: parent.width
                spacing: Style.space(4)

                // Section header
                PanelSectionHeader {
                  visible: rowRoot.isHeader
                  width: parent.width
                  text: rowRoot.isHeader ? String(modelData.label || "").toUpperCase() : ""
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                // Task row
                Rectangle {
                  visible: !rowRoot.isHeader
                  width: parent.width
                  height: taskMain.implicitHeight + Style.space(6)
                  radius: Style.cornerRadius
                  color: rowRoot.hasCursor || taskMouse.containsMouse
                    ? Style.hoverFillFor(root.foreground, Color.accent)
                    : "transparent"

                  MouseArea {
                    id: taskMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: { root.cursorActive = true; root.cursorIndex = rowRoot.index }
                    onClicked: function(mouse) {
                      root.cursorIndex = rowRoot.index
                      if (mouse.button === Qt.RightButton) root.requestDelete(rowRoot.task)
                      else root.expandedUuid = root.expandedUuid === rowRoot.task.uuid ? "" : rowRoot.task.uuid
                    }
                  }

                  Column {
                    id: taskMain
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(4)
                    spacing: Style.space(4)

                    Row {
                      width: parent.width
                      spacing: Style.space(6)

                      Button {
                        text: rowRoot.task && rowRoot.task.status === "completed" ? "☑" : "☐"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.body
                        verticalPadding: Style.space(1)
                        horizontalPadding: Style.space(4)
                        onClicked: root.toggleDone(rowRoot.task)
                      }

                      Column {
                        width: parent.width - Style.space(90)
                        spacing: 1

                        Text {
                          width: parent.width
                          text: rowRoot.task ? rowRoot.task.description : ""
                          color: rowRoot.task && rowRoot.task.overdue ? root.urgent : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.strikeout: !!(rowRoot.task && rowRoot.task.status === "completed")
                          elide: Text.ElideRight
                        }

                        Row {
                          spacing: Style.space(6)
                          Text {
                            visible: !!(rowRoot.task && rowRoot.task.project)
                            text: rowRoot.task ? rowRoot.task.project : ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                          Text {
                            visible: !!(rowRoot.task && rowRoot.task.priority)
                            text: rowRoot.task ? rowRoot.task.priority : ""
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                          Text {
                            visible: !!(rowRoot.task && (rowRoot.task.scheduled || rowRoot.task.due))
                            text: rowRoot.task ? Model.dateRangeLabel(rowRoot.task) : ""
                            color: rowRoot.task && rowRoot.task.overdue ? root.urgent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                          Text {
                            visible: !!(rowRoot.task && rowRoot.task.blocked)
                            text: root.tr("blocked")
                            color: root.urgent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                          Text {
                            visible: !!(rowRoot.task && rowRoot.task.todayLabel)
                            text: root.tr("todayTime") + " " + (rowRoot.task ? rowRoot.task.todayLabel : "")
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                        }
                      }

                      Button {
                        text: rowRoot.task && rowRoot.task.timerActive ? "■" : "▶"
                        foreground: rowRoot.task && rowRoot.task.timerActive ? Color.accent : root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.caption
                        verticalPadding: Style.space(2)
                        horizontalPadding: Style.space(6)
                        tooltipText: rowRoot.task && rowRoot.task.timerActive ? root.tr("stop") : root.tr("play")
                        onClicked: root.toggleTimer(rowRoot.task)
                      }
                    }

                    // Expanded editor
                    Column {
                      visible: rowRoot.expanded
                      width: parent.width
                      spacing: Style.space(6)

                      TextField {
                        id: editDescField
                        width: parent.width
                        foreground: root.foreground
                        text: rowRoot.task ? rowRoot.task.description : ""
                        verticalPadding: Style.space(3)
                        onActiveFocusChanged: root.formFocused = activeFocus
                      }

                      GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: Style.space(6)
                        rowSpacing: Style.space(4)

                        Text {
                          text: root.tr("project")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        Dropdown {
                          id: editProject
                          Layout.fillWidth: true
                          foreground: root.foreground
                          fontFamily: root.fontFamily
                          value: rowRoot.task ? (rowRoot.task.project || "") : ""
                          options: {
                            var opts = [{ value: "", label: root.tr("projectNone") }]
                            for (var i = 0; i < root.projectList.length; i++)
                              opts.push({ value: root.projectList[i], label: root.projectList[i] })
                            if (rowRoot.task && rowRoot.task.project) {
                              var found = false
                              for (var j = 0; j < opts.length; j++) if (opts[j].value === rowRoot.task.project) found = true
                              if (!found) opts.push({ value: rowRoot.task.project, label: rowRoot.task.project })
                            }
                            return opts
                          }
                        }

                        Text {
                          text: root.tr("priority")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        Dropdown {
                          id: editPriority
                          Layout.fillWidth: true
                          foreground: root.foreground
                          fontFamily: root.fontFamily
                          value: rowRoot.task ? (rowRoot.task.priority || "") : ""
                          options: [
                            { value: "", label: root.tr("priorityNone") },
                            { value: "H", label: "H" },
                            { value: "M", label: "M" },
                            { value: "L", label: "L" }
                          ]
                        }

                        Text {
                          text: root.tr("startDate")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        TextField {
                          id: editScheduled
                          Layout.fillWidth: true
                          foreground: root.foreground
                          text: rowRoot.task ? Model.formatShortDate(rowRoot.task.scheduled) : ""
                          placeholderText: root.tr("datesHint")
                          verticalPadding: Style.space(2)
                          onActiveFocusChanged: root.formFocused = activeFocus
                        }

                        Text {
                          text: root.tr("endDate")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        TextField {
                          id: editDue
                          Layout.fillWidth: true
                          foreground: root.foreground
                          text: rowRoot.task ? Model.formatShortDate(rowRoot.task.due) : ""
                          placeholderText: root.tr("datesHint")
                          verticalPadding: Style.space(2)
                          onActiveFocusChanged: root.formFocused = activeFocus
                        }

                        Text {
                          text: root.tr("status")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        Row {
                          spacing: Style.space(4)
                          Button {
                            text: root.tr("pending")
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(1)
                            horizontalPadding: Style.space(6)
                            onClicked: root.setStatus(rowRoot.task, "pending")
                          }
                          Button {
                            text: root.tr("done")
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(1)
                            horizontalPadding: Style.space(6)
                            onClicked: root.setStatus(rowRoot.task, "completed")
                          }
                          Button {
                            text: root.tr("waiting")
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(1)
                            horizontalPadding: Style.space(6)
                            onClicked: root.setStatus(rowRoot.task, "waiting")
                          }
                        }
                      }

                      // Dependencies
                      Text {
                        text: root.tr("depends")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Column {
                        width: parent.width
                        spacing: Style.space(2)
                        Repeater {
                          model: rowRoot.task ? (rowRoot.task.depends || []) : []
                          Row {
                            required property var modelData
                            spacing: Style.space(6)
                            width: parent.width
                            Text {
                              text: {
                                var dep = Model.findTask(root.snapshot.tasks || [], modelData)
                                return dep ? ("#" + dep.id + " " + dep.description) : String(modelData)
                              }
                              color: root.foreground
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.caption
                              width: parent.width - Style.space(60)
                              elide: Text.ElideRight
                            }
                            Button {
                              text: root.tr("removeDep")
                              foreground: root.urgent
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              verticalPadding: Style.space(1)
                              horizontalPadding: Style.space(4)
                              onClicked: root.removeDependency(rowRoot.task, modelData)
                            }
                          }
                        }
                      }

                      Dropdown {
                        id: depCombo
                        width: parent.width
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        value: ""
                        options: {
                          var opts = [{ value: "", label: root.tr("addDep") }]
                          var cands = Model.pendingForDeps(root.snapshot.tasks || [], rowRoot.task ? rowRoot.task.uuid : "")
                          for (var i = 0; i < cands.length; i++) {
                            var c = cands[i]
                            var already = rowRoot.task && rowRoot.task.depends && rowRoot.task.depends.indexOf(c.uuid) >= 0
                            if (already) continue
                            opts.push({ value: c.uuid, label: "#" + c.id + " " + c.description })
                          }
                          return opts
                        }
                        onChanged: function(v) {
                          if (v) {
                            root.addDependency(rowRoot.task, v)
                            depCombo.value = ""
                          }
                        }
                      }

                      Row {
                        spacing: Style.space(6)
                        Button {
                          text: root.tr("save")
                          foreground: root.foreground
                          fontFamily: root.fontFamily
                          fontSize: Style.font.caption
                          onClicked: root.saveTask(
                            rowRoot.task,
                            editDescField.text,
                            editProject.value,
                            editPriority.value,
                            editScheduled.text,
                            editDue.text
                          )
                        }
                        Button {
                          text: root.tr("deleteTask")
                          foreground: root.urgent
                          fontFamily: root.fontFamily
                          fontSize: Style.font.caption
                          onClicked: root.requestDelete(rowRoot.task)
                        }
                      }
                    }
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.rows.length === 0
              text: root.snapshot.available === false ? root.tr("missingTaskwarrior") : root.tr("noTasks")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        // Projects view
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.viewMode === "projects"

          Row {
            width: parent.width
            spacing: Style.space(6)
            TextField {
              id: newProjectField
              width: parent.width - createProjBtn.width - Style.space(6)
              foreground: root.foreground
              placeholderText: root.tr("newProject")
              verticalPadding: Style.space(4)
              onAccepted: root.createProjectName()
            }
            Button {
              id: createProjBtn
              text: root.tr("add")
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: root.createProjectName()
            }
          }

          ListView {
            width: parent.width
            height: Style.space(280)
            clip: true
            model: root.projectList
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
              policy: parent.contentHeight > parent.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
              required property string modelData
              required property int index
              width: ListView.view.width
              height: projRow.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: root.projectFilter === modelData
                ? Style.hoverFillFor(root.foreground, Color.accent)
                : "transparent"

              Row {
                id: projRow
                anchors.fill: parent
                anchors.margins: Style.space(4)
                spacing: Style.space(6)

                Button {
                  text: modelData
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.body
                  leftAlign: true
                  onClicked: {
                    root.projectFilter = root.projectFilter === modelData ? "" : modelData
                    root.viewMode = "tasks"
                    root.groupBy = "project"
                  }
                }

                Item { width: Style.space(8); height: 1 }

                Button {
                  text: root.tr("rename")
                  foreground: root.dim
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  onClicked: {
                    root.renameFrom = modelData
                    root.renameTo = modelData
                    renameField.text = modelData
                    renameField.forceActiveFocus()
                  }
                }
                Button {
                  text: root.tr("clearProject")
                  foreground: root.urgent
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  onClicked: root.requestClearProject(modelData)
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.projectList.length === 0
              text: root.tr("noProjects")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          Row {
            visible: root.renameFrom !== ""
            width: parent.width
            spacing: Style.space(6)
            TextField {
              id: renameField
              width: parent.width - renameBtn.width - Style.space(6)
              foreground: root.foreground
              verticalPadding: Style.space(3)
              onTextChanged: root.renameTo = text
              onAccepted: root.renameProject()
            }
            Button {
              id: renameBtn
              text: root.tr("rename")
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: root.renameProject()
            }
          }
        }
      }

      ConfirmDialog {
        id: confirmDelete
        anchors.fill: parent
        message: root.tr("confirmDelete")
        cancelText: root.tr("cancel")
        confirmText: root.tr("confirm")
        foreground: root.foreground
        background: Color.popups.background
        fontFamily: root.fontFamily
        onCanceled: { opened = false; root.pendingDeleteUuid = "" }
        onConfirmed: root.confirmDeleteTask()
      }

      ConfirmDialog {
        id: confirmClear
        anchors.fill: parent
        message: root.tr("confirmClearProject")
        cancelText: root.tr("cancel")
        confirmText: root.tr("confirm")
        foreground: root.foreground
        background: Color.popups.background
        fontFamily: root.fontFamily
        onCanceled: { opened = false; root.pendingClearProject = "" }
        onConfirmed: root.confirmClearProjectAction()
      }
    }
  }

  IpcHandler {
    target: "q.tasks"
    function refresh(): void { root.refresh() }
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Component.onCompleted: refresh()
}
