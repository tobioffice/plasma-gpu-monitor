#!/bin/bash
# Install / update the GPU Monitor plasmoid for KDE Plasma 6
set -e
cd "$(dirname "$0")"

ID="com.murali.gpumonitor"
SRC="$PWD"
DEST="$HOME/.local/share/plasma/plasmoids/$ID"

echo "→ Installing $ID"
mkdir -p "$DEST"
cp -r metadata.json contents "$DEST"/

echo "→ Validating QML (if qmllint available)…"
if [ -x /usr/lib/qt6/bin/qmllint ]; then
  /usr/lib/qt6/bin/qmllint "$SRC/contents/ui/main.qml" && echo "  main.qml OK" || echo "  qmllint warnings above (non-fatal)"
fi

echo "→ Testing helper…"
python3 "$SRC/contents/code/gpu_stats.py" --card auto | head -c 400
echo ""

if command -v kpackagetool6 >/dev/null 2>&1; then
  echo "→ (kpackagetool6 present — files copied directly, no packaging needed)"
fi

echo ""
echo "Done. Now:"
echo "  1. Right-click desktop or panel → Add or Manage Widgets…"
echo "  2. Search 'GPU Monitor' → Add"
echo "  3. For panel: right-click widget → Configure to pick card0/card1"
echo ""
echo "To uninstall: rm -rf \"$DEST\""
