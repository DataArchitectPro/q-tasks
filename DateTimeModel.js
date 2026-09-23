// Compact month-grid helpers for DateTimeField.
// UI display is DD.MM.YYYY [HH:MM:SS]; calendar keys stay YYYY-MM-DD internally.
// Wire format for Taskwarrior remains YYYY-MM-DD[THH:mm:ss].

function pad2(n) {
  n = Number(n) || 0
  return (n < 10 ? "0" : "") + n
}

// Internal calendar key — not shown in the text field.
function dateKey(d) {
  if (!d || isNaN(d.getTime())) return ""
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

// UI date: DD.MM.YYYY
function formatDate(d) {
  if (!d || isNaN(d.getTime())) return ""
  return pad2(d.getDate()) + "." + pad2(d.getMonth() + 1) + "." + d.getFullYear()
}

// UI datetime: DD.MM.YYYY HH:MM:SS (24h)
function formatDateTime(d) {
  if (!d || isNaN(d.getTime())) return ""
  return formatDate(d) + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes()) + ":" + pad2(d.getSeconds())
}

function parseFlexible(text) {
  var s = String(text || "").trim()
  if (!s) return null

  // DD.MM.YYYY[ HH:MM[:SS]] or DD.MM.YYYY[THH:MM[:SS]]
  var m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2}))?)?$/)
  if (m) {
    return new Date(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0))
  }

  // Legacy UI / wire: YYYY-MM-DD or YYYY-MM-DDTHH:mm[:ss]
  m = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?$/)
  if (m) {
    return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0))
  }

  // Taskwarrior export: YYYYMMDDTHHMMSSZ
  m = s.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/)
  if (m) {
    return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]))
  }

  return null
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
