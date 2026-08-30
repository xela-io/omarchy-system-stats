# Omarchy System Stats

A compact, expandable system-monitor widget for the Omarchy bar.

The bar shows CPU and NVIDIA GPU utilization. Clicking the widget opens a
detailed panel with CPU temperature and clock speed, NVIDIA GPU temperature,
clock speed, power draw and VRAM usage, as well as memory, disk, process and
uptime information.

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
