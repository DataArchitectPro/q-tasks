// Filtering, grouping, and date helpers for q.tasks.

function parseTwDate(s) {
  if (!s) return null
  var str = String(s)
  // 20260922T190000Z
  var m = str.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/)
  if (m) {
    return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]))
  }
  var d = new Date(str)
  return isNaN(d.getTime()) ? null : d
}

function formatShortDate(s, localeName) {
  var d = parseTwDate(s)
  if (!d) return ""
  try {
    return Qt.formatDate(d, "yyyy-MM-dd")
  } catch (e) {
    var y = d.getFullYear()
    var mo = ("0" + (d.getMonth() + 1)).slice(-2)
    var da = ("0" + d.getDate()).slice(-2)
    return y + "-" + mo + "-" + da
  }
}

function dateRangeLabel(task) {
  var a = formatShortDate(task.scheduled)
  var b = formatShortDate(task.due)
  if (a && b) return a + " → " + b
  if (b) return "→ " + b
  if (a) return a + " →"
  return ""
}

function startOfLocalDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

function dueBucket(task) {
  if (!task.due) return "none"
  var due = parseTwDate(task.due)
  if (!due) return "none"
  var now = new Date()
  var today = startOfLocalDay(now)
  var dueDay = startOfLocalDay(due)
  if (dueDay < today && task.status === "pending") return "overdue"
  if (dueDay.getTime() === today.getTime()) return "today"
  var weekEnd = new Date(today)
  weekEnd.setDate(weekEnd.getDate() + (7 - weekEnd.getDay()) % 7)
  // end of week Sunday-ish; simpler: +7 days
  var inWeek = new Date(today)
  inWeek.setDate(inWeek.getDate() + 7)
  if (dueDay < inWeek) return "week"
  return "later"
}

function matchesFilter(task, filter) {
  if (!task) return false
  if (filter === "all") return task.status === "pending" || task.status === "waiting"
  if (filter === "active") return task.status === "pending" && !!task.timerActive
  if (filter === "today") {
    if (task.status !== "pending") return false
    var b = dueBucket(task)
    return b === "today" || b === "overdue"
  }
  if (filter === "done") return task.status === "completed"
  return task.status === "pending"
}

function sortTasks(tasks) {
  return tasks.slice().sort(function (a, b) {
    var ua = Number(a.urgency) || 0
    var ub = Number(b.urgency) || 0
    if (ub !== ua) return ub - ua
    return String(a.description).localeCompare(String(b.description))
  })
}

function groupKey(task, groupBy) {
  if (groupBy === "project") return task.project || ""
  if (groupBy === "priority") return task.priority || ""
  if (groupBy === "status") return task.status || ""
  if (groupBy === "due") return dueBucket(task)
  return ""
}

function groupLabel(key, groupBy, tFn) {
  if (groupBy === "project") return key || tFn("sectionNone")
  if (groupBy === "priority") {
    if (key === "H") return tFn("priH")
    if (key === "M") return tFn("priM")
    if (key === "L") return tFn("priL")
    return tFn("priNone")
  }
  if (groupBy === "status") {
    if (key === "pending") return tFn("statusPending")
    if (key === "completed") return tFn("statusCompleted")
    if (key === "waiting") return tFn("statusWaiting")
    return key || tFn("sectionNone")
  }
  if (groupBy === "due") {
    if (key === "overdue") return tFn("dueOverdue")
    if (key === "today") return tFn("dueToday")
    if (key === "week") return tFn("dueWeek")
    if (key === "later") return tFn("dueLater")
    return tFn("dueNone")
  }
  return tFn("sectionNone")
}

function dueGroupOrder(key) {
  var order = { overdue: 0, today: 1, week: 2, later: 3, none: 4 }
  return order[key] !== undefined ? order[key] : 9
}

function priorityOrder(key) {
  var order = { H: 0, M: 1, L: 2, "": 3 }
  return order[key] !== undefined ? order[key] : 9
}

function buildGroups(tasks, filter, groupBy, tFn) {
  var filtered = sortTasks(tasks.filter(function (task) { return matchesFilter(task, filter) }))
  if (groupBy === "none" || !groupBy) {
    return [{ key: "", label: "", tasks: filtered }]
  }
  var map = {}
  var keys = []
  for (var i = 0; i < filtered.length; i++) {
    var task = filtered[i]
    var key = groupKey(task, groupBy)
    if (!map[key]) {
      map[key] = []
      keys.push(key)
    }
    map[key].push(task)
  }
  keys.sort(function (a, b) {
    if (groupBy === "due") return dueGroupOrder(a) - dueGroupOrder(b)
    if (groupBy === "priority") return priorityOrder(a) - priorityOrder(b)
    return String(a).localeCompare(String(b))
  })
  var groups = []
  for (var j = 0; j < keys.length; j++) {
    groups.push({
      key: keys[j],
      label: groupLabel(keys[j], groupBy, tFn),
      tasks: map[keys[j]]
    })
  }
  return groups
}

function datesValid(scheduled, due) {
  // Soft check for ISO-like dates only; TW natural language passes through.
  var re = /^\d{4}-\d{2}-\d{2}$/
  if (scheduled && due && re.test(scheduled) && re.test(due)) {
    return scheduled <= due
  }
  return true
}

function flattenRows(groups) {
  // Flat list for ListView: { type: "header"|"task", ... }
  var rows = []
  for (var i = 0; i < groups.length; i++) {
    var g = groups[i]
    if (g.label) rows.push({ type: "header", label: g.label, key: g.key })
    for (var j = 0; j < g.tasks.length; j++) {
      rows.push({ type: "task", task: g.tasks[j] })
    }
  }
  return rows
}

function findTask(tasks, uuid) {
  for (var i = 0; i < tasks.length; i++) {
    if (tasks[i].uuid === uuid) return tasks[i]
  }
  return null
}

function pendingForDeps(tasks, excludeUuid) {
  return tasks.filter(function (t) {
    return t.status === "pending" && t.uuid && t.uuid !== excludeUuid
  })
}
