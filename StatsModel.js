.pragma library

function parseCpu(raw, previous) {
  var match = String(raw || "").match(/^cpu\s+([\d\s]+)/m)
  if (!match) return previous || { usage: 0, idle: 0, total: 0 }
  var ticks = match[1].trim().split(/\s+/).map(Number)
  if (ticks.length < 4) return previous || { usage: 0, idle: 0, total: 0 }
  // guest/guest_nice are already part of user/nice, so do not count twice.
  var total = 0
  for (var i = 0; i < Math.min(ticks.length, 8); i++) total += ticks[i]
  var idle = ticks[3] + (ticks[4] || 0)
  var usage = previous ? previous.usage : 0
  if (previous && total > previous.total) {
    usage = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - previous.idle) / (total - previous.total)))))
  }
  return { usage: usage, idle: idle, total: total }
}

function parseMemory(raw) {
  var fields = {}
  String(raw || "").split("\n").forEach(function(line) {
    var m = line.match(/^([A-Za-z]+):\s+(\d+)/)
    if (m) fields[m[1]] = Number(m[2])
  })
  var total = fields.MemTotal || 0
  var available = fields.MemAvailable === undefined ? (fields.MemFree || 0) : fields.MemAvailable
  var used = Math.max(0, total - available)
  var swapTotal = fields.SwapTotal || 0
  var swapUsed = Math.max(0, swapTotal - (fields.SwapFree || 0))
  return {
    percent: total ? Math.round(used * 100 / total) : 0,
    used: (used / 1048576).toFixed(1),
    total: (total / 1048576).toFixed(1),
    available: (available / 1048576).toFixed(1),
    swapPercent: swapTotal ? Math.round(swapUsed * 100 / swapTotal) : 0,
    swapUsed: (swapUsed / 1048576).toFixed(1),
    swapTotal: (swapTotal / 1048576).toFixed(1)
  }
}

var WARN_PERCENT = 80
var CRITICAL_PERCENT = 95

// 0 = normal, 1 = warning, 2 = critical
function loadLevel(percent) {
  var p = Number(percent)
  if (!isFinite(p)) return 0
  if (p >= CRITICAL_PERCENT) return 2
  if (p >= WARN_PERCENT) return 1
  return 0
}

// warning/critical default to fixed colours; the widget passes theme colours.
function levelColor(level, normal, warning, critical) {
  if (level >= 2) return critical || "#e01b24"
  if (level === 1) return warning || "#e5a50a"
  return normal
}

// Seconds since boot -> "13 Std. 33 Min." / "2 T. 4 Std." / "5 Min."
function formatUptime(seconds) {
  var s = Number(seconds)
  if (!isFinite(s) || s < 0) return ""
  var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
  if (d > 0) return d + " T. " + h + " Std."
  if (h > 0) return h + " Std. " + m + " Min."
  return m + " Min."
}

// "AMD Ryzen 9 9950X3D 16-Core Processor" -> "Ryzen 9 9950X3D",
// "NVIDIA GeForce RTX 4090" -> "GeForce RTX 4090"
function shortName(name) {
  return String(name || "")
    .replace(/^(AMD|Intel\(R\)|NVIDIA)\s+/i, "")
    .replace(/\s+\d+-Core Processor$/i, "")
    .replace(/\(R\)|\(TM\)/g, "")
    .replace(/\s+CPU\s+@.*$/i, "")
    .trim()
}
