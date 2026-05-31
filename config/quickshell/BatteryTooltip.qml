import Quickshell
import "."
import Quickshell.Wayland
import QtQuick

PanelWindow {
    property string tipText: Config.batCharging ? (Config.batPercent >= 100 ? "Fully charged" : "Charging · " + Config.batPercent + "%") : Config.batPercent + "% remaining"
    visible: Config.batHovered && tipText !== ""
    anchors.top:    Config.barPosition !== "bottom"
    anchors.bottom: Config.barPosition === "bottom"
    anchors.left:   Config.barPosition === "left"
    anchors.right:  Config.barPosition !== "left"
    margins {
        top:    Config.barPosition === "top"    ? Config.barThickness + 4 : (Config.isVertical ? 96 : 0)
        bottom: Config.barPosition === "bottom" ? Config.barThickness + 4 : (Config.isVertical ? 96 : 0)
        left:   Config.barPosition === "left"   ? Config.barThickness + 8 : 0
        right:  Config.barPosition !== "left"   ? (Config.isVertical ? Config.barThickness + 8 : 140) : 0
    }
    WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore; color: "transparent"
    implicitWidth: batTipLabel.implicitWidth + 20; implicitHeight: batTipLabel.implicitHeight + 12
    Rectangle {
        anchors.fill: parent; radius: 8; color: Config.cSurface
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22); border.width: 1
        Text { id: batTipLabel; anchors.centerIn: parent; text: parent.parent.tipText; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; color: Config.cOnSurface }
    }
}
