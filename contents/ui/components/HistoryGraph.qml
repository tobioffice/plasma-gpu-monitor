import QtQuick

// Filled history line chart. values: array of 0-100 numbers
Item {
    id: root
    property var values: []
    property color lineColor: "#00e5ff"
    property color fillColorTop: Qt.rgba(0, 229, 255, 0.35)
    property color fillColorBottom: Qt.rgba(0.486, 0.302, 1.0, 0.02)
    property real maxValue: 100

    implicitHeight: 84

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height;
            var pad = 6;

            // grid lines
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07);
            ctx.lineWidth = 1;
            for (var g = 1; g <= 3; g++) {
                var gy = pad + (h - pad * 2) * g / 4;
                ctx.beginPath();
                ctx.moveTo(pad, gy);
                ctx.lineTo(w - pad, gy);
                ctx.stroke();
            }

            var vals = root.values;
            if (!vals || vals.length < 2) {
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.35);
                ctx.font = "11px sans-serif";
                ctx.textAlign = "center";
                ctx.fillText("collecting data…", w / 2, h / 2);
                return;
            }
            var n = vals.length;
            function px(i) { return pad + (w - pad * 2) * i / (n - 1); }
            function py(v) {
                var c = Math.max(0, Math.min(root.maxValue, v)) / root.maxValue;
                return h - pad - (h - pad * 2) * c;
            }

            // fill
            var grad = ctx.createLinearGradient(0, 0, 0, h);
            grad.addColorStop(0, root.fillColorTop);
            grad.addColorStop(1, root.fillColorBottom);
            ctx.beginPath();
            ctx.moveTo(px(0), py(vals[0]));
            for (var i = 1; i < n; i++) ctx.lineTo(px(i), py(vals[i]));
            ctx.lineTo(px(n - 1), h - pad);
            ctx.lineTo(px(0), h - pad);
            ctx.closePath();
            ctx.fillStyle = grad;
            ctx.fill();

            // line
            var lgrad = ctx.createLinearGradient(0, 0, w, 0);
            lgrad.addColorStop(0, "#00e5a0");
            lgrad.addColorStop(0.55, root.lineColor);
            lgrad.addColorStop(1, "#7c4dff");
            ctx.beginPath();
            ctx.moveTo(px(0), py(vals[0]));
            for (var j = 1; j < n; j++) ctx.lineTo(px(j), py(vals[j]));
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = lgrad;
            ctx.stroke();

            // last point
            var lx = px(n - 1), ly = py(vals[n - 1]);
            ctx.beginPath();
            ctx.arc(lx - 1, ly, 3.5, 0, Math.PI * 2);
            ctx.fillStyle = "#ffffff";
            ctx.fill();
            ctx.beginPath();
            ctx.arc(lx - 1, ly, 6, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(0, 229, 255, 0.25);
            ctx.fill();
        }
    }

    onValuesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
