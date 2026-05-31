pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // ── Bar settings ──────────────────────────────────────────────
    property string barPosition:    "top"
    property real   barOpacity:     0.88
    property int    barRounding:    0
    property bool   outerCorners:   true
    property int    barThickness:   44
    property int    windowRounding: 8
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property bool isBottom:   barPosition === "bottom"
    readonly property bool isLeft:     barPosition === "left"

    // ── Colors ────────────────────────────────────────────────────
    property color cPrimary:       "#ffb3b4"
    property color cOnPrimary:     "#690005"
    property color cSurface:       "#1a1111"
    property color cSurfaceCont:   "#2e2020"
    property color cSurfaceContHi: "#392828"
    property color cOnSurface:     "#f0dede"
    property color cOnSurfaceVar:  "#d8bfbf"
    property color cSecondary:     "#e6bfbf"
    property color cTertiary:      "#e5c18d"
    property color cError:         "#ffb4ab"
    property color cOutline:       "#a08c8c"

    // ── App state ─────────────────────────────────────────────────
    property real   brightness:   0.5
    property string networkName:  ""
    property string layoutName:   "EN"
    property int    batPercent:   100
    property bool   batCharging:  false
    property bool   wifiOpen:     false
    property bool   btOpen:       false
    property bool   settingsOpen: false

    // ── Media ─────────────────────────────────────────────────────
    property var  currentPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property bool playerPlaying: currentPlayer !== null && currentPlayer.playbackState === MprisPlaybackState.Playing

    // ── Hover state ───────────────────────────────────────────────
    property bool batHovered:  false
    property bool vVolHovered: false
    property bool vBriHovered: false
    property bool vBatHovered: false

    // Tooltip text — вычисляется здесь, где все данные доступны
    readonly property string vVolTooltip: {
        var s = Pipewire.defaultAudioSink
        if (!s || !s.audio) return "—"
        return s.audio.muted ? "Mute" : Math.round(Math.min(s.audio.volume, 1.5) * 100) + "%"
    }
    readonly property string vBriTooltip: Math.round(root.brightness * 100) + "%"
    readonly property string vBatTooltip: root.batPercent + "%" + (root.batCharging ? " · charging" : "")

    // ── Player popup ──────────────────────────────────────────────
    property bool playerPopupShow: false
    function showPlayer() { _plHide.stop();    playerPopupShow = true  }
    function hidePlayer() { _plHide.restart()                          }
    Timer { id: _plHide; interval: 250; onTriggered: root.playerPopupShow = false }

    // ── Workspace → app icon map (IPC events) ────────────────────
    property var wsApps: ({})
    function setWsApp(wsId, appClass) {
        if (!appClass) return
        var m = Object.assign({}, wsApps)
        m[wsId] = appClass
        wsApps = m
    }

    // ── OSD ───────────────────────────────────────────────────────
    signal osdRequested(string icon)

    // ── Color loaders ─────────────────────────────────────────────
    Process {
        id: colorLoader; running: true
        command: ["sh", "-c", "cat ~/.config/hypr/colors.conf"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/\$color_(\w+)\s*=\s*rgba\(([0-9a-f]{6})/)
                if (!m) return
                var hex = "#" + m[2]
                switch (m[1]) {
                    case "primary":   root.cPrimary   = hex; break
                    case "surface":   root.cSurface   = hex; break
                    case "secondary": root.cSecondary = hex; break
                    case "tertiary":  root.cTertiary  = hex; break
                    case "error":     root.cError     = hex; break
                    case "outline":   root.cOutline   = hex; break
                }
            }
        }
    }
    Process {
        id: colorLoaderExt; running: true
        command: ["sh", "-c", "grep -E '(^foreground|^background)=' ~/.config/foot/colors 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/^(\w+)=([0-9a-f]{6})/)
                if (!m) return
                if (m[1] === "foreground") { root.cOnSurface = "#" + m[2]; root.cOnSurfaceVar = "#" + m[2] }
                if (m[1] === "background") { root.cSurfaceCont = "#" + m[2]; root.cSurfaceContHi = "#" + m[2] }
            }
        }
    }

    // ── Brightness ────────────────────────────────────────────────
    Timer { interval: 5000; running: true; repeat: true; onTriggered: brightnessProc.running = true }
    Process {
        id: brightnessProc; running: true
        command: ["sh", "-c", "brightnessctl | grep -oP '\\(\\K[0-9]+(?=%)'| head -1"]
        stdout: SplitParser {
            onRead: data => { var v = parseFloat(data.trim()); if (!isNaN(v)) root.brightness = v / 100 }
        }
    }
    Process { id: brightnessSet }
    function adjustBrightness(up) {
        brightnessSet.command = ["brightnessctl", "s", up ? "5%+" : "5%-"]
        brightnessSet.running = true
        // читаем яркость и сразу показываем OSD
        Qt.callLater(() => { osdBriRead.running = false; osdBriRead.running = true })
    }
    Process {
        id: osdBriRead
        command: ["sh", "-c", "brightnessctl | grep -oP '\\(\\K[0-9]+(?=%)'| head -1"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseFloat(data.trim())
                if (!isNaN(v)) { root.brightness = v / 100; root.osdRequested("brightness") }
            }
        }
    }
    function triggerBrightnessOsd() { osdBriRead.running = false; osdBriRead.running = true }

    // ── Network ───────────────────────────────────────────────────
    Timer { interval: 15000; running: true; repeat: true; onTriggered: netProc.running = true }
    Process {
        id: netProc; running: true
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -1"]
        stdout: SplitParser { onRead: data => root.networkName = data.trim() }
    }

    // ── Battery ───────────────────────────────────────────────────
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true }
    Process {
        id: batProc; running: true
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100) $(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown)"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                if (p.length >= 2) { root.batPercent = parseInt(p[0]) || 0; root.batCharging = p[1] === "Charging" || p[1] === "Full" }
            }
        }
    }

    // ── Layout ────────────────────────────────────────────────────
    property string _mainKbName: ""
    property string _jsonBuf:    ""
    Process {
        id: layoutInitProc; running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: SplitParser { onRead: data => root._jsonBuf += data }
        onExited: {
            try {
                var parsed = JSON.parse(root._jsonBuf)
                var kbs = parsed["keyboards"] || []
                var main = kbs.find(k => k.main === true) || kbs.find(k => k.name && k.name.indexOf("virtual") < 0) || kbs[0]
                if (main) { root._mainKbName = main.name || ""; root.layoutName = main.active_keymap.indexOf("Russian") >= 0 ? "RU" : "EN" }
            } catch(e) {}
            root._jsonBuf = ""
        }
    }

    // ── Settings persistence ──────────────────────────────────────
    Process {
        id: loadProc; running: true
        command: ["sh", "-c", "cat ~/.config/quickshell/settings.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text)
                    if (j.barPosition    !== undefined) root.barPosition    = j.barPosition
                    if (j.barOpacity     !== undefined) root.barOpacity     = j.barOpacity
                    if (j.barRounding    !== undefined) root.barRounding    = j.barRounding
                    if (j.outerCorners   !== undefined) root.outerCorners   = j.outerCorners
                    if (j.barThickness   !== undefined) root.barThickness   = j.barThickness
                    if (j.windowRounding !== undefined) root.windowRounding = j.windowRounding
                } catch(e) {}
            }
        }
    }
    function save() {
        var j = JSON.stringify({ barPosition: root.barPosition, barOpacity: root.barOpacity,
            barRounding: root.barRounding, outerCorners: root.outerCorners,
            barThickness: root.barThickness, windowRounding: root.windowRounding }, null, 2)
        saveProc.command = ["sh", "-c", "printf '%s' '" + j.replace(/\\/g,"\\\\").replace(/'/g,"'\\''") + "' > ~/.config/quickshell/settings.json"]
        saveProc.running = true
    }
    function applyHyprlandRounding() {
        hyprProc.command = ["hyprctl", "keyword", "decoration:rounding", String(root.windowRounding)]
        hyprProc.running = true
    }
    Process { id: saveProc }
    Process { id: hyprProc }
    onWindowRoundingChanged: Qt.callLater(applyHyprlandRounding)
}
