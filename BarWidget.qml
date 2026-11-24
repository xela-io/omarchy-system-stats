import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "StatsModel.js" as Model

Panel {
  id: root
  moduleName: "xela.system-stats"
  ipcTarget: "xela.system-stats"

  // Only hardware sensors and system details need the shell probe.
  // FileView's onLoaded is the sampling boundary: reload() is asynchronous.
  // Static hardware facts are probed once; while the popup is closed each tick
  // only asks for GPU load (and nothing at all when GPU is hidden from the bar).
  property var staticInfo: ({})
  property var stats: ({})
  property string probeMode: "bar"
  readonly property string probeScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/xela.system-stats/stats.sh"
  property var cpuSnapshot: null
  property var memorySnapshot: ({ percent: 0, used: "–", total: "–", available: "–", swapUsed: "–", swapTotal: "–" })
  readonly property int cpuUsage: cpuSnapshot ? cpuSnapshot.usage : 0
  readonly property int gpuUsage: Number(stats.gpu_usage || 0)
  readonly property bool showCpu: setting("showCpu", true) !== false
  readonly property bool showGpu: setting("showGpu", true) !== false
  readonly property bool showRam: setting("showRam", false) === true
  readonly property bool showHotspot: setting("showHotspot", false) === true
  // Hotspot, VRAM temp and SoC voltage come from an optional hwlog CSV.
  readonly property bool hasHwlog: stats.gpu_hotspot !== undefined && stats.gpu_hotspot !== ""
  readonly property int refreshInterval: [1000, 2000, 3000, 4000, 5000].indexOf(Number(setting("refreshInterval", 2000))) >= 0
    ? Number(setting("refreshInterval", 2000)) : 2000
  readonly property int cpuLevel: Model.loadLevel(cpuUsage)
  readonly property int gpuLevel: stats.gpu_usage === undefined || stats.gpu_usage === "" ? 0 : Model.loadLevel(gpuUsage)
  readonly property int ramLevel: Model.loadLevel(memorySnapshot.percent)
  readonly property int diskLevel: Model.loadLevel(stats.disk_percent)
  // Only metrics shown in the bar may raise the bar's indicator.
  readonly property int barLevel: Math.max(showCpu ? cpuLevel : 0, showGpu ? gpuLevel : 0, showRam ? ramLevel : 0)
  readonly property string barText: {
    var parts = []
    if (showCpu) parts.push("CPU " + cpuUsage + "%")
    if (showGpu) parts.push("GPU " + value("gpu_usage", "%"))
    if (showRam) parts.push("RAM " + memorySnapshot.percent + "%")
    if (showHotspot && hasHwlog) parts.push("Hotspot " + value("gpu_hotspot", "°"))
    return parts.length ? parts.join("  ") : "Systemmonitor"
  }

  // Theme tokens, taken from the bar like the built-in panels do.
  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property string family: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.4)
  function tone(level) { return Model.levelColor(level, root.fg, Commons.Color.accent, Commons.Color.urgent) }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function updateSetting(key, value) {
    var entry = { id: moduleName }
    for (var k in settings) if (k !== "id") entry[k] = settings[k]
    entry[key] = value
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }
  function refresh() {
    cpuFile.reload()
    memoryFile.reload()
    if (probe.running) return
    if (!opened && !showGpu && !showHotspot) return
    probeMode = opened ? "details" : "bar"
    probe.running = true
  }
  function parseOutput(raw) {
    var next = {}
    var lines = String(raw || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].indexOf("=")
      if (p > 0) next[lines[i].slice(0, p)] = lines[i].slice(p + 1)
    }
    return next
  }
  function raw(key) {
    var v = stats[key]
    if (v === undefined || v === "") v = staticInfo[key]
    return v === undefined || v === "" ? undefined : v
  }
  function has(key) { return raw(key) !== undefined }
  function value(key, suffix) {
    var v = raw(key)
    return v === undefined ? "–" : String(v) + (suffix || "")
  }
  // Number in the shell's language (13,1 in German), with a unit.
  function num(key, decimals, unit) {
    var v = Number(raw(key))
    if (raw(key) === undefined || !isFinite(v)) return "–"
    return Commons.I18n.formatNumber(v, decimals) + (unit ? " " + unit : "")
  }
  function gib(v) {
    var n = Number(v)
    return isFinite(n) ? Commons.I18n.formatNumber(n, 1) : "–"
  }
  onOpenedChanged: if (opened) refresh()
  Component.onCompleted: staticProbe.running = true

  FileView {
    id: cpuFile
    path: "/proc/stat"
    onLoaded: root.cpuSnapshot = Model.parseCpu(text(), root.cpuSnapshot)
  }
  FileView {
    id: memoryFile
    path: "/proc/meminfo"
    onLoaded: root.memorySnapshot = Model.parseMemory(text())
  }
  Process {
    id: staticProbe
    command: ["sh", root.probeScript, "static"]
    stdout: StdioCollector { id: staticOutput; waitForEnd: true }
    onExited: root.staticInfo = root.parseOutput(staticOutput.text)
  }
  Process {
    id: probe
    command: ["sh", root.probeScript, root.probeMode, root.showHotspot ? "hwlog" : ""]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: {
      root.stats = root.parseOutput(output.text)
      // The popup opened while a bar-only probe was running: fetch details now.
      if (root.opened && root.probeMode !== "details") Qt.callLater(root.refresh)
    }
  }
  Timer { interval: root.refreshInterval; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    horizontalMargin: 8
    tooltipText: "Systemdetails öffnen · Rechtsklick: aktualisieren"
    onPressed: function(b) { if (b === Qt.RightButton) root.refresh(); else root.toggle() }
  }
  Rectangle {
    anchors.left: button.left; anchors.right: button.right; anchors.bottom: button.bottom
    anchors.leftMargin: 8; anchors.rightMargin: 8
    height: 2; radius: 1
    visible: root.barLevel > 0
    color: root.tone(root.barLevel)
  }

  KeyboardPanel {
    id: details
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: details.fittedContentWidth(Style.space(400))
    contentHeight: details.fittedContentHeight(content.implicitHeight, Style.space(900))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Column {
          id: content
          width: scroller.width
          spacing: Style.space(14)
          bottomPadding: Style.space(4)

          // ---------- Hero: chip icon · title/uptime ----------
          PanelHero {
            title: "System"
            meta: root.has("uptime_s") ? "Läuft seit " + Model.formatUptime(root.raw("uptime_s")) : ""
            foreground: root.fg
            fontFamily: root.family
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰍛"
                color: root.fg
                font.family: root.family
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator { foreground: root.fg }

          // ---------- Processor ----------
          Metric {
            title: "CPU"
            subtitle: Model.shortName(root.raw("cpu_name"))
            percent: root.cpuUsage
            level: root.cpuLevel
            valueColor: Model.levelColor(root.cpuLevel, root.fg, Commons.Color.accent, Commons.Color.urgent)
          }
          PairGrid {
            InfoPair { label: "Temperatur"; value: root.num("cpu_temp", 0, "°C") }
            InfoPair { label: "Takt"; value: root.num("cpu_mhz", 0, "MHz") }
            InfoPair { label: "Kerne / Threads"; value: root.value("cpu_cores") + " / " + root.value("cpu_threads") }
            InfoPair { visible: root.has("soc_voltage"); label: "SoC-Spannung"; value: root.num("soc_voltage", 3, "V") }
          }

          PanelSeparator { foreground: root.fg }

          // ---------- Graphics ----------
          Metric {
            title: "GPU"
            subtitle: Model.shortName(root.raw("gpu_name"))
            percent: root.gpuUsage
            known: root.has("gpu_usage")
            level: root.gpuLevel
            valueColor: Model.levelColor(root.gpuLevel, root.fg, Commons.Color.accent, Commons.Color.urgent)
          }
          PairGrid {
            InfoPair { label: "Temperatur"; value: root.num("gpu_temp", 0, "°C") }
            InfoPair { label: "Takt"; value: root.num("gpu_mhz", 0, "MHz") }
            InfoPair { visible: root.hasHwlog; label: "Hotspot"; value: root.num("gpu_hotspot", 0, "°C") }
            InfoPair { label: "Leistung"; value: root.num("gpu_power", 0, "W") }
            InfoPair { visible: root.hasHwlog; label: "VRAM-Temp."; value: root.num("vram_temp", 0, "°C") }
            InfoPair { label: "VRAM"; value: root.num("vram_used", 1, "") + " / " + root.num("vram_total", 1, "GiB") }
            InfoPair { visible: root.hasHwlog; label: "Bis Drosselung"; value: root.num("gpu_tlimit", 0, "°C") }
          }

          PanelSeparator { foreground: root.fg }

          // ---------- Memory & disk ----------
          Metric {
            title: "Arbeitsspeicher"
            subtitle: root.gib(root.memorySnapshot.used) + " / " + root.gib(root.memorySnapshot.total) + " GiB"
            percent: root.memorySnapshot.percent
            level: root.ramLevel
            valueColor: Model.levelColor(root.ramLevel, root.fg, Commons.Color.accent, Commons.Color.urgent)
          }
          PairGrid {
            InfoPair { label: "Verfügbar"; value: root.gib(root.memorySnapshot.available) + " GiB" }
            InfoPair { label: "Swap"; value: root.gib(root.memorySnapshot.swapUsed) + " / " + root.gib(root.memorySnapshot.swapTotal) + " GiB" }
            InfoPair { label: "Prozesse"; value: root.value("processes") }
          }
          Metric {
            title: "Systemlaufwerk"
            subtitle: root.value("disk_used") + " / " + root.value("disk_total") + " GB"
            percent: Number(root.raw("disk_percent") || 0)
            known: root.has("disk_percent")
            level: root.diskLevel
            valueColor: Model.levelColor(root.diskLevel, root.fg, Commons.Color.accent, Commons.Color.urgent)
          }

          PanelSeparator { foreground: root.fg }

          // ---------- Bar preferences ----------
          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "IN DER LEISTE"; foreground: root.fg; fontFamily: root.family }
            Row {
              id: metricRow
              width: parent.width
              spacing: Style.space(6)
              readonly property real cellWidth: (width - spacing * 3) / 4
              Chip { width: metricRow.cellWidth; text: "CPU"; active: root.showCpu; onClicked: root.updateSetting("showCpu", !root.showCpu) }
              Chip { width: metricRow.cellWidth; text: "GPU"; active: root.showGpu; onClicked: root.updateSetting("showGpu", !root.showGpu) }
              Chip { width: metricRow.cellWidth; text: "RAM"; active: root.showRam; onClicked: root.updateSetting("showRam", !root.showRam) }
              Chip {
                width: metricRow.cellWidth; text: "Hotspot"; active: root.showHotspot
                tooltipText: "GPU-Hotspot aus dem hwlog-Protokoll"
                onClicked: root.updateSetting("showHotspot", !root.showHotspot)
              }
            }

            PanelSectionHeader { text: "AKTUALISIERUNG"; foreground: root.fg; fontFamily: root.family }
            Row {
              id: intervalRow
              width: parent.width
              spacing: Style.space(6)
              readonly property real cellWidth: (width - spacing * 4) / 5
              Chip { width: intervalRow.cellWidth; text: "1 s"; active: root.refreshInterval === 1000; onClicked: root.updateSetting("refreshInterval", 1000) }
              Chip { width: intervalRow.cellWidth; text: "2 s"; active: root.refreshInterval === 2000; onClicked: root.updateSetting("refreshInterval", 2000) }
              Chip { width: intervalRow.cellWidth; text: "3 s"; active: root.refreshInterval === 3000; onClicked: root.updateSetting("refreshInterval", 3000) }
              Chip { width: intervalRow.cellWidth; text: "4 s"; active: root.refreshInterval === 4000; onClicked: root.updateSetting("refreshInterval", 4000) }
              Chip { width: intervalRow.cellWidth; text: "5 s"; active: root.refreshInterval === 5000; onClicked: root.updateSetting("refreshInterval", 5000) }
            }
          }
        }
      }
    }
  }

  // Title + dim subtitle on the left, large percentage on the right,
  // then a thin bar like the battery panel's.
  component Metric: Column {
    id: metric
    property string title: ""
    property string subtitle: ""
    property real percent: 0
    property bool known: true
    property int level: 0
    property color valueColor: root.fg

    width: parent ? parent.width : 0
    spacing: Style.space(8)

    Item {
      width: parent.width
      implicitHeight: Math.max(labels.implicitHeight, bigValue.implicitHeight)

      Column {
        id: labels
        anchors.left: parent.left
        anchors.right: bigValue.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: metric.title
          color: root.fg
          font.family: root.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          visible: text !== ""
          textFormat: Text.PlainText
          text: metric.subtitle
          color: root.dim
          font.family: root.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }
      Text {
        id: bigValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: metric.known ? Commons.I18n.formatNumber(Math.round(metric.percent)) + "%" : "–"
        color: metric.valueColor
        font.family: root.family
        font.pixelSize: Style.font.display
        font.bold: true
        Behavior on color { ColorAnimation { duration: Style.duration(200) } }
      }
    }

    Item {
      width: parent.width
      implicitHeight: Style.space(6)
      Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
      }
      Rectangle {
        anchors.left: track.left
        anchors.verticalCenter: track.verticalCenter
        height: track.height
        radius: track.radius
        visible: metric.known && metric.percent > 0
        width: Math.max(track.height, track.width * Math.min(100, metric.percent) / 100)
        color: metric.valueColor
        Behavior on width { NumberAnimation { duration: Style.duration(320); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Style.duration(200) } }
      }
    }
  }

  component PairGrid: Grid {
    width: parent ? parent.width : 0
    columns: 2
    columnSpacing: Style.space(20)
    rowSpacing: Style.spacing.labelGap
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent ? (parent.width - Style.space(20)) / 2 : 0
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: parent.label
      color: root.fg
      opacity: 0.6
      font.family: root.family
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    Text {
      textFormat: Text.PlainText
      text: parent.value
      color: root.fg
      font.family: root.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  component Chip: Button {
    bordered: true
    foreground: root.fg
    fontFamily: root.family
    fontSize: Style.font.bodySmall
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
  }
}
