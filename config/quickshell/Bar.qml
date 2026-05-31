import Quickshell
import "."
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar
    anchors.top:    Config.barPosition === "top"    || Config.isVertical
    anchors.bottom: Config.barPosition === "bottom" || Config.isVertical
    anchors.left:   Config.barPosition === "top" || Config.barPosition === "bottom" || Config.barPosition === "left"
    anchors.right:  Config.barPosition === "top" || Config.barPosition === "bottom" || Config.barPosition === "right"
    implicitHeight: Config.isVertical ? 0 : Config.barThickness
    implicitWidth:  Config.isVertical ? Config.barThickness : 0
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.exclusiveZone: Config.barThickness
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.cSurface.r, Config.cSurface.g, Config.cSurface.b, Config.barOpacity)
        radius: Config.barRounding

        HorizontalContent {
            visible: !Config.isVertical
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        }
        VerticalContent {
            visible: Config.isVertical
            anchors.fill: parent
        }
        ClockOverlay {
            visible: !Config.isVertical
            anchors.centerIn: parent
            implicitHeight: Config.barThickness
        }
    }
}
