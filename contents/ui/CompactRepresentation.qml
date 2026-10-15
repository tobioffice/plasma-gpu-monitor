import QtQuick
import QtQuick.Layouts

import "components" as Comp

// Small panel representation: mini ring + % and temp
Item {
    id: compact
    property real gpuUsage: 0
    property var gpuTemp: null
    property bool online: false
    property bool showTemp: true

    Layout.minimumWidth: row.implicitWidth + 8
    Layout.minimumHeight: 32
    Layout.preferredWidth: row.implicitWidth + 8
    Layout.preferredHeight: 36

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Comp.RingGauge {
            id: miniRing
            value: compact.gpuUsage
            size: 30
            stroke: 5
            centerTop: ""
            centerBottom: ""
            glow: false
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter
            Text {
                text: compact.online ? Math.round(compact.gpuUsage) + "%" : "—"
                color: "white"
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                visible: compact.showTemp
                text: {
                    if (!compact.online || compact.gpuTemp === null || compact.gpuTemp === undefined) return "GPU";
                    return Math.round(compact.gpuTemp) + "°C";
                }
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 10
            }
        }
    }
}
