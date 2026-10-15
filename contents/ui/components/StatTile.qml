import QtQuick
import QtQuick.Layouts

// Small stat tile with optional progress bar
Rectangle {
    id: root
    property string title: ""
    property string value: ""
    property string sub: ""
    property real percent: -1  // 0-100, -1 hides bar
    property color accent: "#00e5ff"

    radius: 12
    color: Qt.rgba(1, 1, 1, 0.055)
    border.color: Qt.rgba(1, 1, 1, 0.09)
    border.width: 1

    implicitHeight: 68

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
            text: root.title
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 10
            font.bold: true
            font.capitalization: Font.AllUppercase
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Text {
            text: root.value
            color: "white"
            font.pixelSize: 17
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.percent >= 0 || root.sub !== ""
            Rectangle {
                visible: root.percent >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.alignment: Qt.AlignVCenter
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.percent / 100))
                    height: parent.height
                    radius: 2
                    color: root.accent
                }
            }
            Text {
                visible: root.sub !== ""
                text: root.sub
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
