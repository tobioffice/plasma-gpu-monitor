import QtQuick

// Donut ring gauge with gradient stroke. value: 0-100
Item {
    id: root
    property real value: 0
    property real size: 150
    property real stroke: 14
    property string centerTop: ""
    property string centerBottom: ""
    property color trackColor: Qt.rgba(1, 1, 1, 0.10)
    property bool glow: true
    // fixed arc colors: when set (non-empty), ignore usage-based gradient
    property string arcA: ""
    property string arcB: ""

    width: size
    height: size

    function usageColor(v) {
        if (v < 50) return "#00e5a0";
        if (v < 75) return "#ffc542";
        if (v < 90) return "#ff9f43";
        return "#ff5470";
    }
    function usageColor2(v) {
        if (v < 50) return "#00b3ff";
        if (v < 75) return "#ffdd57";
        if (v < 90) return "#ff6b6b";
        return "#c44dff";
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2, cy = height / 2;
            var r = Math.min(width, height) / 2 - root.stroke / 2 - 2;
            var start = -Math.PI / 2;
            var end = start + Math.PI * 2;

            // track
            ctx.beginPath();
            ctx.arc(cx, cy, r, start, end, false);
            ctx.lineWidth = root.stroke;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.trackColor;
            ctx.stroke();

            // value arc
            var frac = Math.max(0, Math.min(1, root.value / 100));
            if (frac > 0.001) {
                var c1 = root.arcA !== "" ? root.arcA : root.usageColor(root.value);
                var c2 = root.arcB !== "" ? root.arcB : root.usageColor2(root.value);
                var aEnd = start + Math.PI * 2 * frac;
                var grad = ctx.createLinearGradient(0, 0, width, height);
                grad.addColorStop(0, c1);
                grad.addColorStop(1, c2);
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, aEnd, false);
                ctx.lineWidth = root.stroke;
                ctx.lineCap = "round";
                ctx.strokeStyle = grad;
                if (root.glow) {
                    ctx.save();
                    ctx.shadowColor = c1;
                    ctx.shadowBlur = 14;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, aEnd, false);
                    ctx.lineWidth = root.stroke * 0.55;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = grad;
                    ctx.stroke();
                    ctx.restore();
                }
                // tip dot
                var tx = cx + r * Math.cos(aEnd);
                var ty = cy + r * Math.sin(aEnd);
                ctx.beginPath();
                ctx.arc(tx, ty, root.stroke * 0.22, 0, Math.PI * 2);
                ctx.fillStyle = "#ffffff";
                ctx.fill();
            }
        }
    }

    onValueChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    onArcAChanged: canvas.requestPaint()
    onArcBChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.centerTop
            color: "white"
            font.pixelSize: Math.max(18, root.size * 0.22)
            font.bold: true
            font.family: "Inter, Noto Sans, sans-serif"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.centerBottom
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: Math.max(10, root.size * 0.085)
            font.family: "Inter, Noto Sans, sans-serif"
        }
    }
}
