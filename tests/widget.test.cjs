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
