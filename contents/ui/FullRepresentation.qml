import QtQuick
import QtQuick.Layouts

import "components" as Comp

// Minimal transparent card: ring + VRAM + TEMP/POWER — like the reference.
// Fully transparent (no backdrop): plasmoid background is disabled in main.qml.
Item {
    id: full
    property real gpuUsage: 0
    property string vramUsedText: "—"
    property string vramTotalText: "—"
    property real vramPct: 0
    property var gpuTemp: null
    property var gpuPower: null
    property bool online: false
    property string errorText: ""

    function fmtTemp(v) {
        if (v === null || v === undefined) return "—";
        return Math.round(v) + "°";
    }
    function fmtPower(v) {
        if (v === null || v === undefined) return "—";
        return v + " W";
    }

    Layout.minimumWidth: 340
    Layout.minimumHeight: 160
    Layout.preferredWidth: 360
    Layout.preferredHeight: 170

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 18

        Comp.RingGauge {
            value: full.gpuUsage
            size: 140
            stroke: 13
            trackColor: "#363d4d"
            arcA: "#00eec6"
            arcB: "#00d5ff"
            glow: true
            centerTop: full.online ? Math.round(full.gpuUsage) + "%" : "—"
            centerBottom: "GPU LOAD"
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.preferredWidth: 168
            Layout.maximumWidth: 168
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: "VRAM"
                color: "#9aa3b5"
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                text: full.vramUsedText + " / " + full.vramTotalText
                color: "white"
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // thin bar with glowing tip dot, like the reference
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 9
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#2c3342"
                }
                Rectangle {
                    id: vramFill
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(10, parent.width * Math.max(0, Math.min(1, full.vramPct / 100)))
                    height: 6
                    radius: 3
                    visible: full.online
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#3aa8ff" }
                        GradientStop { position: 1.0; color: "#00e5cc" }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - 9, vramFill.width - 5))
                    width: 9
                    height: 9
                    radius: 4.5
                    color: "#5ab8ff"
                    border.color: "#cfeaff"
                    border.width: 1
                    visible: full.online
                }
            }

            Text {
                text: full.online ? full.vramPct.toFixed(1) + "% used" : ""
                color: "#8b93a5"
                font.pixelSize: 11
            }

            Item { Layout.preferredHeight: 3 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                ColumnLayout {
                    spacing: 0
                    Text { text: "TEMP"; color: "#9aa3b5"; font.pixelSize: 12; font.bold: true }
                    Text { text: full.fmtTemp(full.gpuTemp); color: "white"; font.pixelSize: 21; font.bold: true }
                }
                ColumnLayout {
                    spacing: 0
                    Text { text: "POWER"; color: "#9aa3b5"; font.pixelSize: 12; font.bold: true }
                    Text { text: full.fmtPower(full.gpuPower); color: "white"; font.pixelSize: 21; font.bold: true }
                }
            }

            Text {
                visible: full.errorText !== ""
                text: full.errorText
                color: "#ff8296"
                font.pixelSize: 10
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
