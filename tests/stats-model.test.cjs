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

test('Netzwerk wählt aktive Schnittstelle nach aktuellem Durchsatz statt Lebenszeit-Traffic', () => {
  const mk = (a, b, c, d) => `Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\n    lo: 900000 0 0 0 0 0 0 0 900000 0 0 0 0 0 0 0\n enp1s0: ${a} 0 0 0 0 0 0 0 ${b} 0 0 0 0 0 0 0\n wlp2s0: ${c} 0 0 0 0 0 0 0 ${d} 0 0 0 0 0 0 0\n`;
  const first = model.parseNetwork(mk(1000000, 200000, 100, 20), null, 2);
  assert.equal(first.rx, 0);
  const next = model.parseNetwork(mk(1000005, 200003, 2148, 1044), first, 2);
  assert.equal(next.iface, 'wlp2s0');
  assert.equal(next.rx, 1024);
  assert.equal(next.tx, 512);
  assert.equal(next.download, '1.0 KiB/s');
});

test('Zähler-Reset und Schnittstellenwechsel erzeugen keine negativen oder falschen Spitzen', () => {
  const mk = n => `Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\n enp1s0: ${n} 0 0 0 0 0 0 0 ${n} 0 0 0 0 0 0 0\n`;
  const first = model.parseNetwork(mk(3000), null, 2);
  const reset = model.parseNetwork(mk(50), first, 2);
  assert.equal(reset.rx, 0);
  assert.equal(reset.tx, 0);
  assert.equal(model.parseNetwork(mk(55), reset, 0).rx, 0);
});
