# Omarchy System Stats

A compact, expandable system-monitor widget for the Omarchy bar.

The bar shows CPU and NVIDIA GPU usage by default. The popup groups CPU/GPU
sensors, RAM and swap, disk and process details, and per-interface network
speeds. Its switches optionally add RAM, download, and upload to the bar;
CPU/GPU can also be hidden. If all metrics are hidden, a "Systemmonitor"
button remains so settings are still reachable. Refresh intervals: 1–5
seconds (2 seconds by default); settings are saved in Omarchy's `shell.json`.

CPU, RAM and network counters are read asynchronously from `/proc` via
Quickshell `FileView` and parsed only after loading finishes. The shell probe
still runs for the NVIDIA GPU, CPU sensors, disk and process details.

## Requirements

- Omarchy with the Quickshell-based bar
- An NVIDIA GPU with `nvidia-smi`
- Standard Linux utilities: `awk`, `lscpu`, `df`, `ps` and `uptime`

## Installation

```bash
git clone https://github.com/xela-io/omarchy-system-stats.git \
  ~/.config/omarchy/plugins/xela.system-stats
omarchy bar move xela.system-stats --section right
omarchy restart shell
```

If the widget is not already present in the bar layout, add this entry to the
desired section in `~/.config/omarchy/shell.json`:

```json
{ "id": "xela.system-stats" }
```

Left-click opens the detail panel. Right-click refreshes the values immediately.
