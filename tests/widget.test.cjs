const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const qml = fs.readFileSync(path.join(root, 'BarWidget.qml'), 'utf8');
const script = fs.readFileSync(path.join(root, 'stats.sh'), 'utf8');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));

test('CPU und RAM werden nur nach abgeschlossenem FileView-Laden geparst', () => {
  for (const marker of ['Model.parseCpu(text()', 'Model.parseMemory(text()'])
    assert.ok(qml.includes(marker), marker);
  assert.match(qml, /FileView\s*\{[^}]*onLoaded:/s);
  assert.doesNotMatch(qml, /\.reload\(\)[\s\S]{0,100}\.text\(\)/);
});

test('CPU/GPU/RAM lassen sich unabhängig im Popup umschalten, auch wenn alle aus sind', () => {
  for (const key of ['showCpu', 'showGpu', 'showRam']) {
    assert.ok(qml.includes(`setting("${key}"`), key);
    assert.ok(qml.includes(`updateSetting("${key}"`), key);
  }
  assert.doesNotMatch(qml, /visible:\s*(?:root\.)?hasAnyMetricVisible/);
  assert.ok(qml.includes('updateEntryInline'));
});

test('Popup passt mit Scrollbereich auf kurze Bildschirme und Werte sind gruppiert', () => {
  assert.ok(qml.includes('Flickable {'));
  for (const section of ['PROZESSOR & GRAFIK', 'SPEICHER & LAUFWERK', 'LEISTE EINSTELLEN'])
    assert.ok(qml.includes(section), section);
  assert.ok(qml.includes('fittedContentHeight'));
});

test('Netzwerk wird dem nativen Omarchy-Menü überlassen', () => {
  assert.doesNotMatch(qml, /showDown|showUp|networkFile|networkSnapshot|\/proc\/net\/dev|NETZWERK|Download|Upload/);
  assert.doesNotMatch(JSON.stringify(manifest.barWidget), /showDown|showUp|network|download|upload/i);
});

test('Shell-Probe liest CPU/RAM nicht redundant per awk', () => {
  assert.doesNotMatch(script, /cpu_ticks=|ram_percent=/);
});

test('Manifest dokumentiert die konfigurierbaren Metriken und die bisherige Standardleiste', () => {
  const defaults = manifest.barWidget.defaults;
  assert.deepEqual(defaults, { showCpu: true, showGpu: true, showRam: false, refreshInterval: 2000 });
  assert.equal(manifest.barWidget.schema.length, 4);
});

test('Jedes im Manifest erlaubte Aktualisierungsintervall ist auch im Popup auswählbar', () => {
  for (const ms of [1000, 2000, 3000, 4000, 5000]) {
    assert.ok(qml.includes(`updateSetting("refreshInterval", ${ms})`), `${ms} ms`);
    assert.ok(qml.includes(`root.refreshInterval === ${ms}`), `${ms} ms selection`);
  }
});

test('Statische Hardwaredaten werden einmal, Sensoren pro Takt nur bei Bedarf gelesen', () => {
  const section = (mode) => script.match(new RegExp(`^${mode}\\)\\n([\\s\\S]*?)^  ;;`, 'm'))[1];
  const staticPart = section('static');
  const barPart = section('bar');
  const detailsPart = section('details');
  for (const key of ['cpu_name', 'cpu_cores', 'cpu_threads', 'gpu_name', 'vram_total'])
    assert.ok(staticPart.includes(key), `${key} in static`);
  assert.doesNotMatch(barPart + detailsPart, /lscpu|getconf|gpu_name|vram_total/);
  assert.doesNotMatch(barPart, /df |ps -e|uptime|hwmon|cpuinfo/);
  assert.ok(qml.includes('command: ["sh", root.probeScript, "static"]'));
  assert.ok(qml.includes('Component.onCompleted: staticProbe.running = true'));
  assert.ok(qml.includes('probeMode = opened ? "details" : "bar"'));
  assert.ok(qml.includes('if (!opened && !showGpu) return'));
});

test('Hohe Last färbt Popup-Werte und markiert die Leiste nur für sichtbare Metriken', () => {
  for (const level of ['cpuLevel', 'gpuLevel', 'ramLevel'])
    assert.ok(qml.includes(`Model.levelColor(root.${level}`), level);
  assert.match(qml, /barLevel:\s*Math\.max\(showCpu \? cpuLevel : 0, showGpu \? gpuLevel : 0, showRam \? ramLevel : 0\)/);
  assert.match(qml, /visible:\s*root\.barLevel > 0/);
});
