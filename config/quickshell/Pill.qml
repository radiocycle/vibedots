import Quickshell
import "."
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: pill
    property string icon:      ""
    property string svg:       ""
    property string label:     ""
    property color  iconColor: Config.cOnSurface
    property bool   hoverable: true

    height: 28; implicitWidth: pr.implicitWidth + 16
    radius: height / 2
    color: Qt.rgba(Config.cSurfaceCont.r, Config.cSurfaceCont.g, Config.cSurfaceCont.b, 0.90)
    border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, hoverable && pma.containsMouse ? 0.50 : 0.22)
    border.width: 1
    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: pill.hoverable }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, pma.containsMouse && pill.hoverable ? 0.06 : 0) }
    RowLayout {
        id: pr; anchors.centerIn: parent; spacing: 5
        Item {
            width: 16; height: 16; visible: pill.svg !== ""
            Image { id: svgImg; anchors.fill: parent; source: pill.svg; smooth: true; mipmap: true }
            MultiEffect { source: svgImg; anchors.fill: svgImg; colorization: 1.0; colorizationColor: pill.iconColor }
        }
        Text { text: pill.icon; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 16; color: pill.iconColor; visible: pill.icon !== "" && pill.svg === "" }
        Text { text: pill.label; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 16; color: Config.cOnSurface; visible: pill.label !== "" }
    }
}
