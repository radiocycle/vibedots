import Quickshell
import "."
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    visible: Config.currentPlayer !== null && Config.playerPopupShow
    anchors.top:    Config.barPosition !== "bottom"
    anchors.bottom: Config.barPosition === "bottom"
    anchors.left:   Config.barPosition !== "right"
    anchors.right:  Config.barPosition === "right"
    margins {
        top:    Config.barPosition === "top"    ? Config.barThickness + 4 : 8
        bottom: Config.barPosition === "bottom" ? Config.barThickness + 4 : 0
        left:   Config.barPosition !== "right"  ? (Config.barPosition === "left" ? Config.barThickness + 8 : 8) : 0
        right:  Config.barPosition === "right"  ? Config.barThickness + 8 : 0
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 300; implicitHeight: 175

    Timer { interval: 1000; running: Config.playerPlaying; repeat: true; onTriggered: { if (Config.currentPlayer) Config.currentPlayer.positionChanged() } }

    MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: Config.showPlayer(); onExited: Config.hidePlayer() }

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Config.cSurface
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22); border.width: 1

        ColumnLayout { anchors { fill: parent; margins: 18 }
            spacing: 12
            ColumnLayout { spacing: 3
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: Config.currentPlayer ? Config.currentPlayer.trackTitle : ""; color: Config.cOnSurface; font.pixelSize: 17; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font Mono" }
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: Config.currentPlayer ? (Config.currentPlayer.trackArtist || "") : ""; color: Config.cOnSurfaceVar; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font Mono" }
            }
            ColumnLayout { spacing: 4
                Rectangle {
                    Layout.fillWidth: true; height: 4; radius: 2
                    color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.18)
                    Rectangle {
                        height: parent.height; radius: 2; color: Config.cPrimary
                        width: { var p = Config.currentPlayer; if (!p || p.length <= 0) return 0; return Math.max(8, parent.parent.width * Math.min(1, p.position / p.length)) }
                        Behavior on width { NumberAnimation { duration: 1000 } }
                    }
                }
                RowLayout {
                    Text { text: { var p = Config.currentPlayer; if (!p) return "0:00"; var s=Math.floor(p.position); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                    color: "#7a6060"; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font Mono" }
                    Item { Layout.fillWidth: true }
                    Text { text: { var p = Config.currentPlayer; if (!p||p.length<=0) return ""; var s=Math.floor(p.length); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                    color: "#7a6060"; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font Mono" }
                }
            }
            RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 28
                Repeater {
                    model: [{ svg: Qt.resolvedUrl("icons/previous-filled.svg") }, { svg: Config.playerPlaying ? Qt.resolvedUrl("icons/pause-filled.svg") : Qt.resolvedUrl("icons/play-filled.svg") }, { svg: Qt.resolvedUrl("icons/next-filled.svg") }]
                    Item {
                        required property var modelData; required property int index; width: 28; height: 28
                        Image { id: ctrlImg; anchors.fill: parent; source: modelData.svg; smooth: true; mipmap: true }
                        MultiEffect { source: ctrlImg; anchors.fill: ctrlImg; colorization: 1.0; colorizationColor: index === 1 ? Config.cPrimary : Config.cOnSurfaceVar }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { var p = Config.currentPlayer; if (!p) return; if (index === 0) p.previous(); else if (index === 1) p.togglePlaying(); else p.next() } }
                    }
                }
            }
        }
    }
}
