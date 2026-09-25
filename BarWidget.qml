import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "StatsModel.js" as Model

Panel {
  id: root
  moduleName: "xela.system-stats"
  ipcTarget: "xela.system-stats"

  // Only hardware sensors and system details need the shell probe.
  // FileView's onLoaded is the sampling boundary: reload() is asynchronous.
  property var stats: ({})
  property var cpuSnapshot: null
  property var memorySnapshot: ({ percent: 0, used: "–", total: "–", available: "–", swapUsed: "–", swapTotal: "–" })
  readonly property int cpuUsage: cpuSnapshot ? cpuSnapshot.usage : 0
  readonly property int gpuUsage: Number(stats.gpu_usage || 0)
  readonly property bool showCpu: setting("showCpu", true) !== false
  readonly property bool showGpu: setting("showGpu", true) !== false
  readonly property bool showRam: setting("showRam", false) === true
  readonly property int refreshInterval: [1000, 2000, 3000, 4000, 5000].indexOf(Number(setting("refreshInterval", 2000))) >= 0
    ? Number(setting("refreshInterval", 2000)) : 2000
  readonly property string barText: {
    var parts = []
    if (showCpu) parts.push("CPU " + cpuUsage + "%")
    if (showGpu) parts.push("GPU " + value("gpu_usage", "%"))
    if (showRam) parts.push("RAM " + memorySnapshot.percent + "%")
    return parts.length ? parts.join("  ") : "Systemmonitor"
  }
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
    if (!probe.running) probe.running = true
  }
  function parseOutput(raw) {
    var next = {}
    var lines = String(raw || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].indexOf("=")
      if (p > 0) next[lines[i].slice(0, p)] = lines[i].slice(p + 1)
    }
    stats = next
  }
  function value(key, suffix) {
    var v = stats[key]
    return v === undefined || v === "" ? "–" : String(v) + (suffix || "")
  }
  onOpenedChanged: if (opened) refresh()

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
    id: probe
    command: ["sh", Quickshell.env("HOME") + "/.config/omarchy/plugins/xela.system-stats/stats.sh"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: root.parseOutput(output.text)
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

  KeyboardPanel {
    id: details
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: details.fittedContentWidth(Style.space(440))
    contentHeight: details.fittedContentHeight(content.implicitHeight, Style.space(650))

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
          bottomPadding: Style.space(8)
          Text { text: "Systemmonitor"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
          Text {
            width: parent.width; textFormat: Text.PlainText; wrapMode: Text.WordWrap
            text: root.value("cpu_name") + " · Laufzeit " + root.value("uptime")
            color: Qt.darker(Color.popups.text, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption
          }
          PanelSeparator {}
          PanelSectionHeader { text: "PROZESSOR & GRAFIK" }
          Rectangle {
            width: parent.width; implicitHeight: cpuCard.implicitHeight + Style.space(20)
            radius: Style.cornerRadius; color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.05)
            Column {
              id: cpuCard
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: Style.space(10); spacing: Style.space(6)
              Text { text: "CPU  " + root.cpuUsage + "%"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
              Rectangle {
                width: parent.width; height: Style.space(6); radius: height / 2
                color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.15)
                Rectangle { width: parent.width * root.cpuUsage / 100; height: parent.height; radius: parent.radius; color: Color.accent }
              }
              Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "Temperatur " + root.value("cpu_temp", " °C") + "  ·  Takt " + root.value("cpu_mhz", " MHz") + "  ·  " + root.value("cpu_cores", " Kerne / ") + root.value("cpu_threads", " Threads")
                color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
              }
            }
          }
          Rectangle {
            width: parent.width; implicitHeight: gpuCard.implicitHeight + Style.space(20)
            radius: Style.cornerRadius; color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.05)
            Column {
              id: gpuCard
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: Style.space(10); spacing: Style.space(6)
              Text { text: "GPU  " + root.value("gpu_usage", "%"); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
              Rectangle {
                width: parent.width; height: Style.space(6); radius: height / 2
                color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.15)
                Rectangle { width: parent.width * root.gpuUsage / 100; height: parent.height; radius: parent.radius; color: Color.accent }
              }
              Text { width: parent.width; textFormat: Text.PlainText; elide: Text.ElideRight; text: root.value("gpu_name"); color: Qt.darker(Color.popups.text, 1.25); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "Temperatur " + root.value("gpu_temp", " °C") + "  ·  Takt " + root.value("gpu_mhz", " MHz") + "  ·  Leistung " + root.value("gpu_power", " W") + "  ·  VRAM " + root.value("vram_used", " / ") + root.value("vram_total", " GiB")
                color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
              }
            }
          }
          PanelSectionHeader { text: "SPEICHER & LAUFWERK" }
          Column {
            width: parent.width; spacing: Style.space(6)
            Text { text: "RAM  " + root.memorySnapshot.percent + "%  ·  " + root.memorySnapshot.used + " / " + root.memorySnapshot.total + " GiB"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Verfügbar " + root.memorySnapshot.available + " GiB  ·  Swap " + root.memorySnapshot.swapUsed + " / " + root.memorySnapshot.swapTotal + " GiB"; color: Qt.darker(Color.popups.text, 1.3); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { text: "Systemlaufwerk  " + root.value("disk_used", " / ") + root.value("disk_total") + " (" + root.value("disk_percent", ")"); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { text: "Prozesse  " + root.value("processes"); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
          PanelSeparator {}
          PanelSectionHeader { text: "LEISTE EINSTELLEN" }
          Column {
            width: parent.width; spacing: Style.space(5)
            Toggle { width: parent.width; label: "CPU"; checked: root.showCpu; onClicked: root.updateSetting("showCpu", !root.showCpu) }
            Toggle { width: parent.width; label: "NVIDIA-GPU"; checked: root.showGpu; onClicked: root.updateSetting("showGpu", !root.showGpu) }
            Toggle { width: parent.width; label: "RAM"; checked: root.showRam; onClicked: root.updateSetting("showRam", !root.showRam) }
          }
          Text { text: "Aktualisierung"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
          Row {
            spacing: Style.space(8)
            Button { text: "1 s"; bordered: true; selected: root.refreshInterval === 1000; onClicked: root.updateSetting("refreshInterval", 1000) }
            Button { text: "2 s"; bordered: true; selected: root.refreshInterval === 2000; onClicked: root.updateSetting("refreshInterval", 2000) }
            Button { text: "3 s"; bordered: true; selected: root.refreshInterval === 3000; onClicked: root.updateSetting("refreshInterval", 3000) }
            Button { text: "4 s"; bordered: true; selected: root.refreshInterval === 4000; onClicked: root.updateSetting("refreshInterval", 4000) }
            Button { text: "5 s"; bordered: true; selected: root.refreshInterval === 5000; onClicked: root.updateSetting("refreshInterval", 5000) }
          }
        }
      }
    }
  }
}
