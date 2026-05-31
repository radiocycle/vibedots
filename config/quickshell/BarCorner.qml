import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string corner:    "bl"   // bl | br | tl | tr
    property color  fillColor: "#000000"
    property int    size:      12

    implicitWidth:  size
    implicitHeight: size

    readonly property bool isLeft:   corner === "tl" || corner === "bl"
    readonly property bool isTop:    corner === "tl" || corner === "tr"

    Shape {
        anchors.fill: parent
        layer.enabled: true; layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: shapePath
            strokeWidth: 0
            fillColor: root.fillColor
            startX: root.isLeft ? 0 : root.size
            startY: root.isTop  ? 0 : root.size

            PathAngleArc {
                moveToStart: false
                centerX: root.size - shapePath.startX
                centerY: root.size - shapePath.startY
                radiusX: root.size
                radiusY: root.size
                startAngle: root.corner === "tl" ? 180 : root.corner === "tr" ? -90 : root.corner === "bl" ? 90 : 0
                sweepAngle: 90
            }
            PathLine { x: shapePath.startX; y: shapePath.startY }
        }
    }
}
