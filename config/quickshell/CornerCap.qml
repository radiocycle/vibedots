import Quickshell
import "."
import Quickshell.Wayland
import QtQuick

// capNum: 1 = start corner, 2 = end corner
PanelWindow {
    property int capNum: 1
    visible: Config.outerCorners
    anchors.top:    capNum === 1 ? Config.barPosition !== "bottom" : Config.barPosition === "top"
    anchors.bottom: capNum === 1 ? Config.barPosition === "bottom" : Config.barPosition !== "top"
    anchors.left:   capNum === 1 ? Config.barPosition !== "right"  : Config.barPosition === "left"
    anchors.right:  capNum === 1 ? Config.barPosition === "right"  : Config.barPosition !== "left"
    margins {
        top:    Config.barPosition === "top"    ? Config.barThickness : 0
        bottom: Config.barPosition === "bottom" ? Config.barThickness : 0
        left:   Config.barPosition === "left"   ? Config.barThickness : 0
        right:  Config.barPosition === "right"  ? Config.barThickness : 0
    }
    WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore; color: "transparent"
    implicitWidth: Config.windowRounding; implicitHeight: Config.windowRounding
    BarCorner {
        anchors.fill: parent; size: Config.windowRounding
        fillColor: Qt.rgba(Config.cSurface.r, Config.cSurface.g, Config.cSurface.b, Config.barOpacity)
        corner: {
            if (capNum === 1) return Config.barPosition === "top" ? "tl" : Config.barPosition === "bottom" ? "bl" : Config.barPosition === "left" ? "tl" : "tr"
            return Config.barPosition === "top" ? "tr" : Config.barPosition === "bottom" ? "br" : Config.barPosition === "left" ? "bl" : "br"
        }
    }
}
