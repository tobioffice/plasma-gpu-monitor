import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: configPage

    property alias cfg_gpuCard: gpuCardField.text
    property alias cfg_updateInterval: intervalSpin.value
    property alias cfg_showCompactTemp: showTempCheck.checked

    TextField {
        id: gpuCardField
        Kirigami.FormData.label: "GPU card:"
        placeholderText: "auto (recommended), card0, card1…"
    }

    SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: "Update every:"
        from: 1
        to: 10
        stepSize: 1
        textFromValue: function(v) { return v + " s"; }
        valueFromText: function(t) { return parseInt(t); }
    }

    CheckBox {
        id: showTempCheck
        Kirigami.FormData.label: "Panel:"
        text: "Show temperature next to usage"
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        opacity: 0.7
        font.pointSize: 9
        text: "AMD: reads /sys/class/drm directly (no extra tools). NVIDIA: needs nvidia-smi. Tip: add the widget twice — once set to card1 (discrete) and once to card0 (integrated)."
    }
}
