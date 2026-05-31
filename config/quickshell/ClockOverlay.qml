import Quickshell
import "."
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth: clockPill.implicitWidth

    Rectangle {
        id: clockPill
        anchors.verticalCenter: parent.verticalCenter
        height: 28; implicitWidth: clockRow.implicitWidth + 16; radius: height / 2
        color: Qt.rgba(Config.cSurfaceCont.r, Config.cSurfaceCont.g, Config.cSurfaceCont.b, 0.90)
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, clkMa.containsMouse ? 0.30 : 0.14); border.width: 1
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, clkMa.containsMouse ? 0.06 : 0) }
        MouseArea { id: clkMa; anchors.fill: parent; hoverEnabled: true }
        RowLayout {
            id: clockRow; anchors.centerIn: parent; spacing: 8
            Text {
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 16; font.weight: Font.Medium; color: Config.cOnSurface
                Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm") }
                Component.onCompleted: text = Qt.formatDateTime(new Date(), "HH:mm")
            }
            Text { text: "·"; font.pixelSize: 14; color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.30) }
            Text {
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.60)
                Timer { interval: 60000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd d MMM") }
                Component.onCompleted: text = Qt.formatDateTime(new Date(), "ddd d MMM")
            }
        }
    }
}
