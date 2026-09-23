// Filtering, grouping, and date helpers for Taskwarrior Time (taskwarrior-time).

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

function pad2(n) {
  n = Number(n) || 0
  return (n < 10 ? "0" : "") + n
}

function formatEditableDateTime(s) {
  var d = parseTwDate(s)
  if (!d) return ""
  var ymd = formatShortDate(s)
  var h = d.getHours()
  var m = d.getMinutes()
  if (h === 0 && m === 0) return ymd
  return ymd + "T" + pad2(h) + ":" + pad2(m)
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
  // Legacy simple filters kept for compatibility
  if (!task) return false
  if (!filter || filter === "pass") return true
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

function matchesAdvanced(task, spec) {
  if (!task || !spec) return false

  var status = String(spec.status || "open")
  if (status === "open") {
    if (task.status !== "pending" && task.status !== "waiting") return false
  } else if (status === "pending") {
    if (task.status !== "pending") return false
  } else if (status === "waiting") {
    if (task.status !== "waiting") return false
  } else if (status === "completed") {
    if (task.status !== "completed") return false
  } else if (status === "active") {
    if (!(task.status === "pending" && task.timerActive)) return false
  }
  // status === "all" → any status (except deleted, already stripped)

  var project = String(spec.project || "")
  if (project === "__none__") {
    if (task.project) return false
  } else if (project !== "" && project !== "__all__") {
    if (task.project !== project) return false
  }

  var priority = String(spec.priority || "")
  if (priority === "__none__") {
    if (task.priority) return false
  } else if (priority !== "") {
    if (task.priority !== priority) return false
  }

  var due = String(spec.due || "")
  if (due !== "") {
    var bucket = dueBucket(task)
    if (due === "overdue" || due === "today" || due === "week" || due === "later" || due === "none") {
      if (bucket !== due) return false
    } else if (due === "soon") {
      if (bucket !== "overdue" && bucket !== "today" && bucket !== "week") return false
    }
  }

  var search = String(spec.search || "").trim().toLowerCase()
  if (search) {
    var hay = (String(task.description || "") + " " + String(task.details || "") + " " + String(task.project || "")).toLowerCase()
    if (hay.indexOf(search) < 0) return false
  }

  var blocked = String(spec.blocked || "")
  if (blocked === "blocked") {
    if (!task.blocked) return false
  } else if (blocked === "blocking") {
    if (!task.blocking) return false
  } else if (blocked === "clear") {
    if (task.blocked || task.blocking) return false
  }

  var timer = String(spec.timer || "")
  if (timer === "running") {
    if (!task.timerActive) return false
  } else if (timer === "idle") {
    if (task.timerActive) return false
  }

  return true
}

function countActiveFilters(spec) {
  if (!spec) return 0
  var n = 0
  if (spec.status && spec.status !== "open") n++
  if (spec.project) n++
  if (spec.priority) n++
  if (spec.due) n++
  if (spec.search && String(spec.search).trim()) n++
  if (spec.blocked) n++
  if (spec.timer) n++
  return n
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

// Waiting → in progress → done (matches the editor chip order).
function statusGroupOrder(key) {
  var order = { waiting: 0, pending: 1, completed: 2 }
  return order[key] !== undefined ? order[key] : 9
}

function buildGroups(tasks, filter, groupBy, tFn) {
  // When filter is "pass", tasks are already filtered by the caller.
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
    if (groupBy === "status") return statusGroupOrder(a) - statusGroupOrder(b)
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
  function datePrefix(s) {
    var m = String(s || "").trim().match(/^(\d{4}-\d{2}-\d{2})/)
    return m ? m[1] : ""
  }
  var a = datePrefix(scheduled)
  var b = datePrefix(due)
  if (a && b) return a <= b
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

function rowsStructureKey(rows) {
  if (!rows || !rows.length) return ""
  var parts = []
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (!r) {
      parts.push("?")
      continue
    }
    if (r.type === "header")
      parts.push("h:" + String(r.key || r.label || ""))
    else
      parts.push("t:" + String((r.task && r.task.uuid) || ""))
  }
  return parts.join("|")
}

// Explicit keys — Object.keys() is empty on QVariantMap-wrapped tasks from QML.
var TASK_FIELDS = [
  "id", "uuid", "description", "status", "project", "priority",
  "scheduled", "due", "wait", "waitingFor", "outcome", "details", "start", "end",
  "depends", "blocks", "urgency", "tags", "timerActive", "todaySeconds",
  "todayLabel", "overdue", "blocked", "blocking"
]

function toJsArray(v) {
  if (!v) return []
  if (Array.isArray(v)) return v.slice()
  // QVariantList / array-like from QML — no .indexOf, but has .length
  var out = []
  var len = Number(v.length) || 0
  for (var i = 0; i < len; i++) out.push(v[i])
  return out
}

function listContains(list, value) {
  var arr = toJsArray(list)
  var want = String(value)
  for (var i = 0; i < arr.length; i++) {
    if (String(arr[i]) === want) return true
  }
  return false
}

function copyTaskFields(dst, src) {
  if (!dst || !src) return
  for (var i = 0; i < TASK_FIELDS.length; i++) {
    var k = TASK_FIELDS[i]
    var v = src[k]
    if (k === "depends" || k === "blocks" || k === "tags")
      dst[k] = toJsArray(v)
    else if (v !== undefined)
      dst[k] = v
  }
}

// Fresh object so QML bindings re-evaluate when dataRev changes.
function taskSnapshot(t, rev) {
  if (!t) return null
  var out = {}
  copyTaskFields(out, t)
  out._rev = rev
  return out
}

function patchRowsInPlace(prev, next) {
  if (!prev || !next || prev.length !== next.length) return false
  if (rowsStructureKey(prev) !== rowsStructureKey(next)) return false
  for (var i = 0; i < next.length; i++) {
    if (next[i].type === "task" && prev[i].task && next[i].task)
      copyTaskFields(prev[i].task, next[i].task)
    else if (next[i].type === "header") {
      prev[i].label = next[i].label
      prev[i].key = next[i].key
    }
  }
  return true
}

function findTask(tasks, uuid) {
  for (var i = 0; i < tasks.length; i++) {
    if (tasks[i].uuid === uuid) return tasks[i]
  }
  return null
}

function pendingForDeps(tasks, excludeUuid) {
  // Offer anything open (pending/waiting) plus completed — useful when
  // almost all work is already done and you still want an explicit link.
  var open = []
  var done = []
  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i]
    if (!t || !t.uuid || t.uuid === excludeUuid) continue
    if (t.status === "pending" || t.status === "waiting") open.push(t)
    else if (t.status === "completed") done.push(t)
  }
  open.sort(function (a, b) { return (a.id || 0) - (b.id || 0) })
  done.sort(function (a, b) { return (b.id || 0) - (a.id || 0) })
  return open.concat(done)
}
