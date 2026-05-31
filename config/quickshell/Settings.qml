import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "."

PanelWindow {
    id: root


    anchors.top:    Config.barPosition !== "bottom"
    anchors.bottom: Config.barPosition === "bottom"
    anchors.left:   Config.barPosition === "left"
    anchors.right:  Config.barPosition !== "left"
    margins {
        top:    Config.barPosition === "top"    ? Config.barThickness + 4 : 8
        bottom: Config.barPosition === "bottom" ? Config.barThickness + 4 : 0
        left:   Config.barPosition === "left"   ? Config.barThickness + 8 : 0
        right:  Config.barPosition !== "left"   ? 8 : 0
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 340
    implicitHeight: settingsCol.implicitHeight + 32

    component SectionLabel: Text {
        property string text_: ""
        text: text_
        font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 11; font.weight: Font.Bold
        color: Qt.rgba(0.94, 0.87, 0.87, 0.45); topPadding: 4
    }

    component LabeledSlider: ColumnLayout {
        id: slRoot
        property string label: ""
        property real   value: 0.5
        property real   from:  0.0
        property real   to:    1.0
        property int    steps: 0
        property string unit:  ""
        signal moved(val: real)
        spacing: 3
        RowLayout {
            Text { text: slRoot.label; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: Config.cOnSurface }
            Item { Layout.fillWidth: true }
            Text {
                text: slRoot.steps > 0 ? Math.round(slRoot.value) + slRoot.unit : (Math.round(slRoot.value * 100) / 100) + slRoot.unit
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; color: Config.cPrimary
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 4; radius: 2
            color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.12)
            Rectangle {
                width: Math.max(4, parent.width * (slRoot.value - slRoot.from) / (slRoot.to - slRoot.from))
                height: parent.height; radius: 2; color: Config.cPrimary
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                onPressed: mv(mouseX); onPositionChanged: if (pressed) mv(mouseX)
                function mv(x) {
                    var raw = slRoot.from + (slRoot.to - slRoot.from) * Math.max(0, Math.min(1, x / width))
                    slRoot.moved(slRoot.steps > 0 ? Math.round(raw) : Math.round(raw * 100) / 100)
                }
            }
        }
    }

    component PosBtn: Rectangle {
        id: pb
        property string pos: ""
        property string icon_: ""
        height: 34; implicitWidth: 66; radius: 8
        color: Config.barPosition === pos
               ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22)
               : pMa.containsMouse ? Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.07) : "transparent"
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, Config.barPosition === pos ? 0.55 : 0.18); border.width: 1
        ColumnLayout { anchors.centerIn: parent; spacing: 1
            Text { text: pb.icon_; font.pixelSize: 14
                   color: Config.barPosition === pb.pos ? Config.cPrimary : Config.cOnSurfaceVar }
            Text { Layout.alignment: Qt.AlignHCenter; text: pb.pos
                   font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 9
                   color: Config.barPosition === pb.pos ? Config.cPrimary : Config.cOnSurfaceVar }
        }
        MouseArea { id: pMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { Config.barPosition = pb.pos; Config.save() } }
    }

    Rectangle {
        anchors.fill: parent; radius: 16
        color: Config.cSurface
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22); border.width: 1

        ColumnLayout {
            id: settingsCol
            anchors { fill: parent; margins: 16 }
            spacing: 7

            RowLayout {
                Text { text: "Bar Settings"; font.family: "JetBrainsMono Nerd Font Mono"
                       font.pixelSize: 16; font.weight: Font.Bold; color: Config.cOnSurface }
                Item { Layout.fillWidth: true }
                Rectangle { width: 26; height: 26; radius: 7
                    color: xMa.containsMouse ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: Config.cOnSurfaceVar }
                    MouseArea { id: xMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Config.settingsOpen = false }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.12) }

            SectionLabel { text_: "POSITION" }
            RowLayout { spacing: 6
                PosBtn { pos: "top";    icon_: "▲" }
                PosBtn { pos: "bottom"; icon_: "▼" }
                PosBtn { pos: "left";   icon_: "◀" }
                PosBtn { pos: "right";  icon_: "▶" }
            }

            SectionLabel { text_: "SIZE & APPEARANCE" }

            LabeledSlider { label: "Thickness"; from: 32; to: 64; steps: 1; unit: "px"
                value: Config.barThickness
                onMoved: val => { Config.barThickness = val; Config.save() } }

            LabeledSlider { label: "Opacity"; from: 0.3; to: 1.0; unit: ""
                value: Config.barOpacity
                onMoved: val => { Config.barOpacity = val; Config.save() } }

            LabeledSlider { label: "Bar corners"; from: 0; to: 20; steps: 1; unit: "px"
                value: Config.barRounding
                onMoved: val => { Config.barRounding = val; Config.save() } }

            RowLayout {
                Text { text: "Outer corner caps"; Layout.fillWidth: true
                       font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: Config.cOnSurface }
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: Config.outerCorners ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.25)
                                              : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.18)
                    border.color: Config.outerCorners ? Config.cPrimary : Config.cOnSurfaceVar; border.width: 1
                    Rectangle {
                        width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                        x: Config.outerCorners ? parent.width - 20 : 4; color: Config.outerCorners ? Config.cPrimary : Config.cOnSurfaceVar
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { Config.outerCorners = !Config.outerCorners; Config.save() } }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.08) }

            SectionLabel { text_: "HYPRLAND" }

            LabeledSlider { label: "Window corners"; from: 0; to: 24; steps: 1; unit: "px"
                value: Config.windowRounding
                onMoved: val => { Config.windowRounding = val; Config.save() } }

            Text { text: "All changes apply instantly"; Layout.alignment: Qt.AlignHCenter
                   font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 11; color: Config.cOnSurfaceVar; topPadding: 2 }
        }
    }
}
