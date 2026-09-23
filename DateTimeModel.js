// Compact month-grid helpers for DateTimeField.

function pad2(n) {
  n = Number(n) || 0
  return (n < 10 ? "0" : "") + n
}

function formatDate(d) {
  if (!d || isNaN(d.getTime())) return ""
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function formatDateTime(d) {
  if (!d || isNaN(d.getTime())) return ""
  return formatDate(d) + "T" + pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}

function parseFlexible(text) {
  var s = String(text || "").trim()
  if (!s) return null
  // YYYY-MM-DD or YYYY-MM-DDTHH:mm[:ss]
  var m = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?$/)
  if (m) {
    return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0))
  }
  // YYYYMMDDTHHMMSSZ (taskwarrior export)
  m = s.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/)
  if (m) {
    return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]))
  }
  var d = new Date(s)
  return isNaN(d.getTime()) ? null : d
}

function daysInMonth(year, month) {
  return new Date(year, month + 1, 0).getDate()
}

// Build a 6x7 grid of day cells. weekStart: 0=Sun … 6=Sat (JS getDay).
function monthGrid(year, month, weekStart, selectedKey, todayKey) {
  weekStart = weekStart === undefined || weekStart === null ? 1 : weekStart
  var first = new Date(year, month, 1)
  var startPad = (first.getDay() - weekStart + 7) % 7
  var total = daysInMonth(year, month)
  var cells = []
  var i
  for (i = 0; i < startPad; i++) {
    cells.push({ day: 0, inMonth: false, key: "", selected: false, today: false })
  }
  for (i = 1; i <= total; i++) {
    var key = year + "-" + pad2(month + 1) + "-" + pad2(i)
    cells.push({
      day: i,
      inMonth: true,
      key: key,
      selected: key === selectedKey,
      today: key === todayKey
    })
  }
  while (cells.length % 7 !== 0) {
    cells.push({ day: 0, inMonth: false, key: "", selected: false, today: false })
  }
  while (cells.length < 42) {
    cells.push({ day: 0, inMonth: false, key: "", selected: false, today: false })
  }
  return cells
}

function stepMonth(year, month, delta) {
  var d = new Date(year, month + delta, 1)
  return { year: d.getFullYear(), month: d.getMonth() }
}

function weekdayLabels(weekStart, locale) {
  weekStart = weekStart === undefined || weekStart === null ? 1 : weekStart
  var labels = []
  var loc = locale || Qt.locale()
  for (var i = 0; i < 7; i++) {
    var day = (weekStart + i) % 7
    labels.push(loc.dayName(day, Locale.NarrowFormat))
  }
  return labels
}
