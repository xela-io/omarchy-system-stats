import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "xela.system-stats"
  ipcTarget: "xela.system-stats"
  property var stats: ({})
  property double previousIdle: 0
  property double previousTotal: 0
  readonly property int cpuUsage: Number(stats.cpu_usage || 0)
  readonly property int gpuUsage: Number(stats.gpu_usage || 0)
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { if (!probe.running) probe.running = true }
  function parseOutput(raw) {
    var next = Object.assign({}, stats)
    var lines = String(raw || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].indexOf("=")
      if (p < 1) continue
      var key = lines[i].slice(0, p), value = lines[i].slice(p + 1)
      if (key === "cpu_ticks") {
        var f = value.trim().split(/\s+/).map(Number), idle = f[3] + (f[4] || 0), total = 0
        for (var j = 0; j < f.length; j++) total += f[j] || 0
        if (previousTotal > 0 && total > previousTotal)
          next.cpu_usage = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - previousIdle) / (total - previousTotal)))))
        previousIdle = idle; previousTotal = total
      } else next[key] = value
    }
    stats = next
  }
  function value(key, suffix) {
    var v = stats[key]
    return v === undefined || v === "" ? "–" : String(v) + (suffix || "")
  }
  onOpenedChanged: if (opened) refresh()

  Process {
    id: probe
    command: ["sh", Quickshell.env("HOME") + "/.config/omarchy/plugins/xela.system-stats/stats.sh"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: root.parseOutput(output.text)
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "CPU " + root.cpuUsage + "%  GPU " + root.gpuUsage + "%"
    horizontalMargin: 8
    tooltipText: "Systemdetails öffnen"
    onPressed: function(b) { if (b === Qt.RightButton) root.refresh(); else root.toggle() }
  }

  KeyboardPanel {
    id: details
    anchorItem: button; owner: root; bar: root.bar; open: root.opened; focusTarget: keyCatcher
    contentWidth: details.fittedContentWidth(Style.space(430))
    contentHeight: details.fittedContentHeight(content.implicitHeight)
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      Column {
        id: content
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        spacing: Style.space(14)
        Text { text: "Systemmonitor"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }

        Column {
          width: parent.width; spacing: Style.space(6)
          Text { text: "CPU  " + root.cpuUsage + "%"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
          Rectangle {
            width: parent.width; height: Style.space(7); radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16)
            Rectangle { width: parent.width * root.cpuUsage / 100; height: parent.height; radius: height / 2; color: root.bar.foreground }
          }
          Text { width: parent.width; wrapMode: Text.Wrap; text: root.value("cpu_name"); color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "Temperatur  " + root.value("cpu_temp", "°C") + "     Takt  " + root.value("cpu_mhz", " MHz") + "     " + root.value("cpu_cores", " Kerne / ") + root.value("cpu_threads", " Threads"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
        }

        Column {
          width: parent.width; spacing: Style.space(6)
          Text { text: "GPU  " + root.gpuUsage + "%"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
          Rectangle {
            width: parent.width; height: Style.space(7); radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16)
            Rectangle { width: parent.width * root.gpuUsage / 100; height: parent.height; radius: height / 2; color: root.bar.foreground }
          }
          Text { width: parent.width; elide: Text.ElideRight; text: root.value("gpu_name"); color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "Temperatur  " + root.value("gpu_temp", "°C") + "     Takt  " + root.value("gpu_mhz", " MHz") + "     Leistung  " + root.value("gpu_power", " W"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "VRAM  " + root.value("vram_used", " / ") + root.value("vram_total", " GiB"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15) }
        Grid {
          width: parent.width; columns: 2; columnSpacing: Style.space(28); rowSpacing: Style.space(8)
          Text { text: "Arbeitsspeicher"; color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: root.value("ram_used", " / ") + root.value("ram_total", " GiB") + "  (" + root.value("ram_percent", "%)"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "Systemlaufwerk"; color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: root.value("disk_used", " / ") + root.value("disk_total") + "  (" + root.value("disk_percent", ")"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "Prozesse"; color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: root.value("processes"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: "Laufzeit"; color: Qt.darker(root.bar.foreground, 1.25); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Text { text: root.value("uptime"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
        }
        Text { text: "Aktualisierung alle 2 Sekunden · Rechtsklick aktualisiert sofort"; color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
      }
    }
  }
}
