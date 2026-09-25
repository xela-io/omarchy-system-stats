const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'StatsModel.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const model = vm.createContext({});
vm.runInContext(source, model);

test('CPU-Last wird aus zwei frischen Tick-Samples berechnet', () => {
  const first = model.parseCpu('cpu 10 0 10 80 0 0 0 0\n', null);
  assert.equal(first.usage, 0);
  const second = model.parseCpu('cpu 20 0 20 160 0 0 0 0\n', first);
  assert.equal(second.usage, 20);
});

test('RAM-Nutzung berücksichtigt verfügbaren Cache und Swap', () => {
  const data = model.parseMemory('MemTotal: 8192000 kB\nMemFree: 1000000 kB\nMemAvailable: 4096000 kB\nSwapTotal: 2048000 kB\nSwapFree: 1024000 kB\n');
  assert.equal(data.percent, 50);
  assert.equal(data.used, '3.9');
  assert.equal(data.total, '7.8');
  assert.equal(data.swapPercent, 50);
});

test('Netzwerk-Parsen und Geschwindigkeitsformatierung gehören nicht zum Plugin', () => {
  assert.equal(typeof model.parseNetwork, 'undefined');
  assert.equal(typeof model.formatSpeed, 'undefined');
});
