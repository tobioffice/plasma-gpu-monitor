#!/usr/bin/env python3
"""GPU stats helper for KDE Plasma GPU Monitor widget.
Reads AMD sysfs, NVIDIA nvidia-smi, Intel sysfs. Outputs one JSON line.
Usage: gpu_stats.py [--card auto|card0|card1|...]
No third-party dependencies.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys


def read_file(path, default=None):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        return default


def read_int(path, default=None):
    v = read_file(path)
    if v is None:
        return default
    try:
        # some sysfs files contain "123 ..." - take first int
        return int(v.split()[0])
    except Exception:
        return default


def list_drm_cards():
    cards = []
    for dev_path in sorted(glob.glob("/sys/class/drm/card*/device")):
        parts = dev_path.split("/")
        try:
            idx = parts.index("drm")
            card_name = parts[idx + 1]
        except Exception:
            continue
        # Only real cards: cardN (digits), not cardN-DP-x connectors
        if not card_name.startswith("card"):
            continue
        suffix = card_name[4:]
        if not suffix.isdigit():
            continue
        cards.append((card_name, dev_path))
    return cards


def vendor_of(dev_path):
    v = read_file(os.path.join(dev_path, "vendor"))
    if v:
        return v.lower()
    return ""


def pci_id(dev_path):
    vendor = read_file(os.path.join(dev_path, "vendor"), "")
    device = read_file(os.path.join(dev_path, "device"), "")
    return vendor, device


# Known AMD names for common PCI device ids (partial, fallback to generic)
AMD_NAMES = {
    "0x7550": "Radeon RX 9070 / 9070 XT",
    "0x7551": "Radeon RX 9070 GRE",
    "0x164e": "Radeon 610M (Integrated)",
    "0x15bf": "Radeon 780M / 760M (Integrated)",
    "0x15bd": "Radeon 680M (Integrated)",
    "0x743f": "Radeon RX 6400 / 6500 XT",
    "0x744c": "Radeon RX 7700 XT / 7800 XT",
    "0x74a0": "Radeon RX 7900 XTX",
    "0x74a1": "Radeon RX 7900 XT",
    "0x73ff": "Radeon RX 6600 / 6650 XT",
    "0x73df": "Radeon RX 6700 XT",
    "0x67df": "Radeon RX 480 / 580",
}


def clean_gpu_name(raw):
    """'Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070...] [1002:7550] (rev c0)'
    -> 'Navi 48 [Radeon RX 9070...]'"""
    import re
    name = raw
    name = name.replace("Advanced Micro Devices, Inc. [AMD/ATI] ", "")
    name = name.replace("Advanced Micro Devices, Inc. ", "")
    name = name.replace("NVIDIA Corporation ", "")
    name = name.replace("Intel Corporation ", "")
    # drop trailing [xxxx:xxxx] pci id tag
    name = re.sub(r"\s*\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]", "", name)
    # drop trailing (rev ..) 
    name = re.sub(r"\s*\(rev [^)]*\)\s*$", "", name)
    return name.strip()[:80]


def lspci_name(slot=None):
    # Try lspci for a friendly name
    try:
        out = subprocess.run(
            ["lspci", "-nn"],
            capture_output=True, text=True, timeout=3,
        ).stdout
        # normalize slot: "0000:03:00.0" -> "03:00.0" to match lspci output
        short_slot = None
        if slot:
            s = slot.strip()
            if s.startswith("0000:"):
                short_slot = s[5:]
            else:
                short_slot = s
        for line in out.splitlines():
            if "VGA" in line or "3D" in line or "Display" in line:
                if short_slot and short_slot not in line:
                    continue
                # strip prefix up to ": "
                if ": " in line:
                    name = line.split(": ", 1)[1]
                    # remove [0300] style tag at start
                    # name like "Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070...]"
                    return name.strip()
        return None
    except Exception:
        return None


def slot_of(dev_path):
    ue = read_file(os.path.join(dev_path, "uevent"), "")
    slot = None
    if ue:
        for line in ue.splitlines():
            if line.startswith("PCI_SLOT_NAME="):
                slot = line.split("=", 1)[1].strip()
                break
    return slot


def read_amd(dev_path, card_name):
    data = {}
    data["vendor"] = "amd"
    data["card"] = card_name

    vendor_id, device_id = pci_id(dev_path)
    data["pci_id"] = f"{vendor_id}:{device_id}"

    slot = slot_of(dev_path)
    friendly = lspci_name(slot) if slot else None
    if not friendly:
        friendly = lspci_name(None)
    if friendly and ("AMD" in friendly or "ATI" in friendly or "Radeon" in friendly):
        # shorten a bit
        data["name"] = clean_gpu_name(friendly)
    else:
        key = device_id.lower() if device_id else ""
        data["name"] = "AMD " + AMD_NAMES.get(key, "Radeon Graphics")

    data["usage"] = read_int(os.path.join(dev_path, "gpu_busy_percent"), 0) or 0
    mem_busy = read_int(os.path.join(dev_path, "mem_busy_percent"), None)
    data["mem_busy"] = mem_busy

    vram_used = read_int(os.path.join(dev_path, "mem_info_vram_used"), 0) or 0
    vram_total = read_int(os.path.join(dev_path, "mem_info_vram_total"), 0) or 0
    vis_used = read_int(os.path.join(dev_path, "mem_info_vis_vram_used"), None)
    gtt_used = read_int(os.path.join(dev_path, "mem_info_gtt_used"), None)
    data["vram_used"] = vram_used
    data["vram_total"] = vram_total
    data["vram_vis_used"] = vis_used
    data["gtt_used"] = gtt_used
    if vram_total and vram_total > 0:
        data["vram_pct"] = round(vram_used / vram_total * 100.0, 1)
    else:
        data["vram_pct"] = 0.0

    # hwmon (first hwmon dir)
    hwmon_dirs = sorted(glob.glob(os.path.join(dev_path, "hwmon", "hwmon*")))
    temp = temp_j = temp_m = None
    power = None
    fan = None
    sclk = None
    mclk = None
    if hwmon_dirs:
        hw = hwmon_dirs[0]
        # temps: find by label
        for tfile in glob.glob(os.path.join(hw, "temp*_input")):
            base = tfile.replace("_input", "")
            label = read_file(base + "_label", "")
            try:
                val = read_int(tfile, None)
                c = round(val / 1000.0, 1) if val is not None else None
            except Exception:
                c = None
            if c is None:
                continue
            if label == "edge":
                temp = c
            elif label == "junction":
                temp_j = c
            elif label == "mem":
                temp_m = c
            elif temp is None:
                temp = c  # first temp as fallback
        # generic fallbacks if labels missing
        if temp is None:
            v = read_int(os.path.join(hw, "temp1_input"), None)
            temp = round(v / 1000.0, 1) if v is not None else None
        power_raw = read_int(os.path.join(hw, "power1_average"), None)
        if power_raw is None:
            power_raw = read_int(os.path.join(hw, "power1_input"), None)
        if power_raw is not None:
            power = round(power_raw / 1000000.0, 1)
        fan = read_int(os.path.join(hw, "fan1_input"), None)
        f1 = read_int(os.path.join(hw, "freq1_input"), None)
        f2 = read_int(os.path.join(hw, "freq2_input"), None)
        l1 = read_file(os.path.join(hw, "freq1_label"), "")
        l2 = read_file(os.path.join(hw, "freq2_label"), "")
        # map sclk/mclk by label
        for val, lab in ((f1, l1), (f2, l2)):
            if val is None:
                continue
            mhz = round(val / 1000000.0)
            if lab == "sclk":
                sclk = mhz
            elif lab == "mclk":
                mclk = mhz
        if sclk is None and f1 is not None:
            sclk = round(f1 / 1000000.0)
        if mclk is None and f2 is not None:
            mclk = round(f2 / 1000000.0)

    data["temp"] = temp
    data["temp_junction"] = temp_j
    data["temp_mem"] = temp_m
    data["power"] = power
    data["fan"] = fan
    data["sclk"] = sclk
    data["mclk"] = mclk
    return data


def read_nvidia_smi():
    if not shutil.which("nvidia-smi"):
        return None
    try:
        q = "utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,fan.speed,clocks.gr,clocks.mem,name"
        out = subprocess.run(
            ["nvidia-smi", f"--query-gpu={q}", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip().splitlines()
        if not out or not out[0].strip():
            return None
        # pick first GPU (discrete); widget monitors GPU 0
        parts = [p.strip() for p in out[0].split(",")]
        if len(parts) < 9:
            return None
        ugpu, mem_used, mem_total, temp, power, fan, gr, memc, name = parts[:9]

        def num(x, cast=float, default=None):
            try:
                if x in ("[N/A]", "N/A", ""):
                    return default
                return cast(x)
            except Exception:
                return default

        vram_used = num(mem_used, float, 0.0) * 1024 * 1024
        vram_total = num(mem_total, float, 1.0) * 1024 * 1024
        return {
            "vendor": "nvidia",
            "card": "nvidia0",
            "name": name,
            "usage": int(num(ugpu, float, 0.0) or 0.0),
            "mem_busy": None,
            "vram_used": int(vram_used),
            "vram_total": int(vram_total),
            "vram_vis_used": None,
            "gtt_used": None,
            "vram_pct": round(num(mem_used, float, 0.0) / max(num(mem_total, float, 1.0), 1.0) * 100.0, 1),
            "temp": num(temp, float, None),
            "temp_junction": None,
            "temp_mem": None,
            "power": num(power, float, None),
            "fan": num(fan, float, None),
            "sclk": num(gr, float, None),
            "mclk": num(memc, float, None),
        }
    except Exception:
        return None


def read_intel(dev_path, card_name):
    data = {
        "vendor": "intel",
        "card": card_name,
        "name": "Intel Graphics",
    }
    friendly = lspci_name(slot_of(dev_path))
    if friendly:
        data["name"] = clean_gpu_name(friendly)
    data["usage"] = read_int(os.path.join(dev_path, "gpu_busy_percent"), 0) or 0
    # Intel integrated shares system memory; report GTT as vram-ish
    gtt_used = read_int(os.path.join(dev_path, "mem_info_gtt_used"), 0) or 0
    data["vram_used"] = gtt_used
    data["vram_total"] = 0
    data["vram_vis_used"] = None
    data["gtt_used"] = gtt_used
    data["vram_pct"] = 0.0
    data["mem_busy"] = None
    data["temp"] = None
    data["temp_junction"] = None
    data["temp_mem"] = None
    data["power"] = None
    data["fan"] = None
    data["sclk"] = None
    data["mclk"] = None
    # try hwmon temp if present
    for hw in sorted(glob.glob(os.path.join(dev_path, "hwmon", "hwmon*"))):
        v = read_int(os.path.join(hw, "temp1_input"), None)
        if v is not None:
            data["temp"] = round(v / 1000.0, 1)
            break
    return data


def pick_card(requested):
    cards = list_drm_cards()
    if requested and requested != "auto":
        for name, dev in cards:
            if name == requested:
                return name, dev
        # fall through to auto if requested not found
    # auto: prefer discrete AMD/NVIDIA with biggest VRAM, else first card
    best = None
    best_score = -1
    for name, dev in cards:
        v = vendor_of(dev).lower()
        vram = read_int(os.path.join(dev, "mem_info_vram_total"), 0) or 0
        score = vram
        # prefer discrete (large vram) over integrated
        if best is None or score > best_score:
            best = (name, dev)
            best_score = score
    if best:
        return best
    return (None, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--card", default="auto")
    args = ap.parse_args()

    # NVIDIA first if requested card is nvidia or auto and nvidia-smi exists
    # and no AMD discrete? Prefer AMD discrete sysfs when present since
    # nvidia-smi may not exist on AMD-only systems (like this one).
    # Strategy: if auto, check DRM cards; if an AMD card with >2GB exists,
    # use it. Otherwise try nvidia-smi.
    card_name, dev_path = pick_card(args.card if args.card != "auto" else "auto")

    data = None
    if dev_path:
        v = vendor_of(dev_path)
        if "0x10de" in v:
            data = read_nvidia_smi()
            if data is None:
                # fallback: generic
                data = {
                    "vendor": "nvidia", "card": card_name,
                    "name": "NVIDIA GPU",
                    "usage": 0, "mem_busy": None,
                    "vram_used": 0, "vram_total": 0, "vram_vis_used": None,
                    "gtt_used": None, "vram_pct": 0.0,
                    "temp": None, "temp_junction": None, "temp_mem": None,
                    "power": None, "fan": None, "sclk": None, "mclk": None,
                }
        elif "0x1002" in v:
            data = read_amd(dev_path, card_name)
        elif "0x8086" in v:
            data = read_intel(dev_path, card_name)
        else:
            # unknown vendor: try generic busy percent
            raw = lspci_name(slot_of(dev_path))
            data = {
                "vendor": "unknown", "card": card_name,
                "name": clean_gpu_name(raw) if raw else "GPU",
                "usage": read_int(os.path.join(dev_path, "gpu_busy_percent"), 0) or 0,
                "mem_busy": None,
                "vram_used": read_int(os.path.join(dev_path, "mem_info_vram_used"), 0) or 0,
                "vram_total": read_int(os.path.join(dev_path, "mem_info_vram_total"), 0) or 0,
                "vram_vis_used": None, "gtt_used": None, "vram_pct": 0.0,
                "temp": None, "temp_junction": None, "temp_mem": None,
                "power": None, "fan": None, "sclk": None, "mclk": None,
            }
            if data["vram_total"]:
                data["vram_pct"] = round(data["vram_used"] / data["vram_total"] * 100.0, 1)
    else:
        # no DRM cards? try nvidia-smi anyway
        data = read_nvidia_smi()
        if data is None:
            data = {
                "vendor": "unknown", "card": "none",
                "name": "No GPU found",
                "usage": 0, "mem_busy": None,
                "vram_used": 0, "vram_total": 0, "vram_vis_used": None,
                "gtt_used": None, "vram_pct": 0.0,
                "temp": None, "temp_junction": None, "temp_mem": None,
                "power": None, "fan": None, "sclk": None, "mclk": None,
            }

    # list available cards for config UI debugging
    data["cards"] = [n for n, _ in list_drm_cards()]
    sys.stdout.write(json.dumps(data))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
