# GPU Monitor — beautiful KDE Plasma 6 widget

![GPU Monitor](screenshot.png)

Monitors GPU usage on KDE Plasma 6. Auto-detects **AMD** (via sysfs, no extra
tools), **NVIDIA** (via `nvidia-smi`) and **Intel**.

Tested on: CachyOS, Plasma 6.7, AMD Radeon RX 9070 XT (Navi 48, discrete) +
Radeon 610M (integrated).

## Features

- Big gradient ring gauge for GPU load
- Live history graph (last 60 samples)
- VRAM used/total + bar
- Temperatures: edge / junction (hotspot) / VRAM mem
- Power draw, fan RPM, GFX + memory clocks, memory-controller load
- Compact panel view: mini-ring + % + temp
- Configurable: which card (`auto`/`card0`/`card1`), refresh 1–10 s

## Install

```bash
cd ~/Desktop/GPUwidget
bash install.sh
```

Then: right-click desktop/panel → **Add or Manage Widgets…** → search
**GPU Monitor** → Add.

Tip: add it twice — one set to `card1` (RX 9070) and one to `card0` (610M).

## How it works

`contents/code/gpu_stats.py` reads:

- AMD: `/sys/class/drm/card*/device/gpu_busy_percent`,
  `mem_info_vram_*`, `hwmon/{temp,power,fan,freq}_*`
- NVIDIA: `nvidia-smi --query-gpu=...`
- Intel: `gpu_busy_percent` + GTT

and prints one JSON line. `contents/ui/main.qml` polls it every N seconds
through the `executable` data engine (`Plasma5Support.DataSource`) and feeds
the QML gauges.

Check detection manually:

```bash
python3 ~/.local/share/plasma/plasmoids/com.murali.gpumonitor/contents/code/gpu_stats.py --card auto | python3 -m json.tool
python3 ~/.local/share/plasma/plasmoids/com.murali.gpumonitor/contents/code/gpu_stats.py --card card1 | python3 -m json.tool
```

## Files

```
metadata.json
contents/
  code/gpu_stats.py
  ui/main.qml
  ui/CompactRepresentation.qml
  ui/FullRepresentation.qml
  ui/components/RingGauge.qml
  ui/components/HistoryGraph.qml
  ui/components/StatTile.qml
  config/main.xml
  config/config.qml
```

## Uninstall

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.murali.gpumonitor
```
