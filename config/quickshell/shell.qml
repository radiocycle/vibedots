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
