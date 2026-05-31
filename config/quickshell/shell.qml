//@ pragma UseQApplication
import Quickshell
import "."
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick

ShellRoot {
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // Начальная загрузка: какое приложение на каком воркспейсе
    Process {
        id: clientsProc; running: true
        command: ["hyprctl", "-j", "clients"]
        stdout: SplitParser { onRead: data => _clientsBuf += data }
        property string _clientsBuf: ""
        onExited: {
            try {
                var clients = JSON.parse(_clientsBuf)
                clients.forEach(function(cl) {
                    if (cl.workspace && cl.workspace.id && cl.class)
                        Config.setWsApp(cl.workspace.id, cl.class)
                })
            } catch(e) {}
            _clientsBuf = ""
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                var comma = event.data.indexOf(",")
                if (comma < 0) return
                var kb  = event.data.substring(0, comma)
                var lay = event.data.substring(comma + 1)
                if (Config._mainKbName && kb !== Config._mainKbName) return
                Config.layoutName = lay.indexOf("Russian") >= 0 ? "RU" : "EN"
            } else if (event.name === "activewindow") {
                // data = "class,title" — сохраняем class для текущего воркспейса
                var c = event.data.indexOf(",")
                var cls = c >= 0 ? event.data.substring(0, c) : event.data
                var focused = Hyprland.workspaces.values.find(w => w.focused)
                if (focused && cls) Config.setWsApp(focused.id, cls)
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggleSettings(): void { Config.settingsOpen = !Config.settingsOpen }
        function osdVolume(): void      { Config.osdRequested("volume") }
        function osdBrightness(): void  { Config.triggerBrightnessOsd() }
    }

    Loader {
        active: Config.settingsOpen
        sourceComponent: Settings { Component.onCompleted: visible = true }
    }

    Bar            { }
    PlayerPopup    { }
    OsdPopup       { }
    CornerCap      { capNum: 1 }
    CornerCap      { capNum: 2 }
    BatteryTooltip { }
    VerticalTooltip{ }

    WifiPopup      { visible: Config.wifiOpen  }
    BluetoothPopup { visible: Config.btOpen    }
}
