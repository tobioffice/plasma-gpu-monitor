import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // ---- state ----
    property string gpuName: "Detecting GPU…"
    property string cardId: ""
    property string vendorLabel: "AMD"
    property real gpuUsage: 0
    property double vramUsed: 0
    property double vramTotal: 0
    property real vramPct: 0
    property var gpuTemp: null
    property var tempJunction: null
    property var tempMem: null
    property var gpuPower: null
    property var gpuFan: null
    property var sclk: null
    property var mclk: null
    property var memBusy: null
    property var usageHistory: []
    property bool online: false
    property string lastUpdate: ""
    property string errorText: ""

    property string gpuCard: Plasmoid.configuration.gpuCard || "auto"
    property int pollSecs: Plasmoid.configuration.updateInterval || 2
    property int pollMs: Math.max(1, pollSecs) * 1000
    property int historyMax: 60

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: gpuName
    toolTipSubText: online ? (Math.round(gpuUsage) + "%  •  " + vramUsedText + " / " + vramTotalText + (gpuTemp !== null ? "  •  " + Math.round(gpuTemp) + "°C" : "")) : "waiting for data…"

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    // ---- helpers ----
    function fmtGB(bytes) {
        if (!bytes || bytes <= 0) return "—";
        return (bytes / 1073741824).toFixed(1) + " GB";
    }
    property string vramUsedText: fmtGB(vramUsed)
    property string vramTotalText: fmtGB(vramTotal)

    function vendorPretty(v) {
        if (v === "amd") return "AMD";
        if (v === "nvidia") return "NVIDIA";
        if (v === "intel") return "Intel";
        return v ? v.toUpperCase() : "";
    }

    property string scriptPath: {
        try {
            var u = Qt.resolvedUrl("../code/gpu_stats.py").toString();
            if (u.indexOf("file://") === 0) return u.substring(7);
            return u;
        } catch (e) {
            return "";
        }
    }
    property string command: "python3 " + scriptPath + " --card " + gpuCard

    // ---- data source ----
    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []
        interval: root.pollMs
        onNewData: function(sourceName, data) {
            var out = data["stdout"];
            if (!out) {
                root.errorText = "No data from helper (is python3 installed?)";
                root.online = false;
                return;
            }
            try {
                var j = JSON.parse(out);
                root.gpuName = j.name || "GPU";
                root.cardId = j.card || "";
                root.vendorLabel = root.vendorPretty(j.vendor);
                root.gpuUsage = Number(j.usage || 0);
                root.vramUsed = Number(j.vram_used || 0);
                root.vramTotal = Number(j.vram_total || 0);
                root.vramPct = Number(j.vram_pct || 0);
                root.gpuTemp = (j.temp === null || j.temp === undefined) ? null : Number(j.temp);
                root.tempJunction = (j.temp_junction === null || j.temp_junction === undefined) ? null : Number(j.temp_junction);
                root.tempMem = (j.temp_mem === null || j.temp_mem === undefined) ? null : Number(j.temp_mem);
                root.gpuPower = (j.power === null || j.power === undefined) ? null : Number(j.power);
                root.gpuFan = (j.fan === null || j.fan === undefined) ? null : Number(j.fan);
                root.sclk = (j.sclk === null || j.sclk === undefined) ? null : Number(j.sclk);
                root.mclk = (j.mclk === null || j.mclk === undefined) ? null : Number(j.mclk);
                root.memBusy = (j.mem_busy === null || j.mem_busy === undefined) ? null : Number(j.mem_busy);
                root.online = true;
                root.errorText = "";
                var d = new Date();
                var hh = ("0" + d.getHours()).slice(-2);
                var mm = ("0" + d.getMinutes()).slice(-2);
                var ss = ("0" + d.getSeconds()).slice(-2);
                root.lastUpdate = hh + ":" + mm + ":" + ss;

                var h = root.usageHistory.slice();
                h.push(root.gpuUsage);
                while (h.length > root.historyMax) h.shift();
                root.usageHistory = h;
            } catch (e) {
                root.errorText = "Parse error: " + e;
                root.online = false;
            }
        }
        onSourceConnected: function(source) {}
    }

    function reconnect() {
        if (!scriptPath) {
            errorText = "Helper script not found";
            return;
        }
        // disconnect all, connect current command
        var existing = execSource.connectedSources.slice();
        for (var i = 0; i < existing.length; i++) {
            execSource.disconnectSource(existing[i]);
        }
        execSource.connectSource(root.command);
    }

    Component.onCompleted: reconnect()
    onCommandChanged: reconnect()
    onPollMsChanged: {
        execSource.interval = root.pollMs;
        reconnect();
    }

    // ---- representations ----
    compactRepresentation: CompactRepresentation {
        gpuUsage: root.gpuUsage
        gpuTemp: root.gpuTemp
        online: root.online
        showTemp: Plasmoid.configuration.showCompactTemp
    }

    fullRepresentation: FullRepresentation {
        gpuUsage: root.gpuUsage
        vramUsedText: root.vramUsedText
        vramTotalText: root.vramTotalText
        vramPct: root.vramPct
        gpuTemp: root.gpuTemp
        gpuPower: root.gpuPower
        online: root.online
        errorText: root.errorText
    }
}
