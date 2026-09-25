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
