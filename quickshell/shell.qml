// ~/.config/quickshell/shell.qml
// A simple top bar for Hyprland: workspaces (left), window title (centre), clock (right).
// Quickshell live-reloads this file whenever you save it.

import Quickshell
import Quickshell.Io
import Quickshell.I3
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

pragma ComponentBehavior: Bound

ShellRoot {
    id: root
    // ---- Theme (Catppuccin-ish; change freely) ----
    readonly property color colBg: "#1e1e2e"
    readonly property color colFg: "#cdd6f4"
    readonly property color colDim: "#6c7086"
    readonly property color colAccent: "#89b4fa"
    readonly property color colOccupied: "#45475a"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colPurple: "#ad8ee6"
    property color colRed: "#f7768e"
    property color colYellow: "#e0af68"
    property color colBlue: "#7aa2f7"

    property string kernelVersion: "Linux"
    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property int volumeLevel: 0
    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property int fontSize: 12
    property string fontFamily: "Lilex"

    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: SplitParser {
            onRead: data => {
                if (data) root.kernelVersion = data.trim()
            }
        }
        Component.onCompleted: running = true
    }

    // CPU usage
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var user = parseInt(parts[1]) || 0
                var nice = parseInt(parts[2]) || 0
                var system = parseInt(parts[3]) || 0
                var idle = parseInt(parts[4]) || 0
                var iowait = parseInt(parts[5]) || 0
                var irq = parseInt(parts[6]) || 0
                var softirq = parseInt(parts[7]) || 0

                var total = user + nice + system + idle + iowait + irq + softirq
                var idleTime = idle + iowait

                if (root.lastCpuTotal > 0) {
                    var totalDiff = total - root.lastCpuTotal
                    var idleDiff = idleTime - root.lastCpuIdle
                    if (totalDiff > 0) {
                        root.cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                }
                root.lastCpuTotal = total
                root.lastCpuIdle = idleTime
            }
        }
        Component.onCompleted: running = true
    }

    // Memory usage
     Process {
         id: memProc
         command: ["sh", "-c", "free | grep Mem"]
         stdout: SplitParser {
             onRead: data => {
                 if (!data) return
                 var parts = data.trim().split(/\s+/)
                 var total = parseInt(parts[1]) || 1
                 var used = parseInt(parts[2]) || 0
                 root.memUsage = Math.round(100 * used / total)
             }
         }
         Component.onCompleted: running = true
     }

     // Disk usage
     Process {
         id: diskProc
         command: ["sh", "-c", "df / | tail -1"]
         stdout: SplitParser {
             onRead: data => {
                 if (!data) return
                 var parts = data.trim().split(/\s+/)
                 var percentStr = parts[4] || "0%"
                 root.diskUsage = parseInt(percentStr.replace('%', '')) || 0
             }
         }
         Component.onCompleted: running = true
     }

     // Volume level (wpctl for PipeWire)
     Process {
         id: volProc
         command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
         stdout: SplitParser {
             onRead: data => {
                 if (!data) return
                 var match = data.match(/Volume:\s*([\d.]+)/)
                 if (match) {
                     root.volumeLevel = Math.round(parseFloat(match[1]) * 100)
                 }
             }
         }
         Component.onCompleted: running = true
     }
     // Current layout (Hyprland: dwindle/master/floating)

     Timer {
         interval: 1000
         running: true
         repeat: true
         onTriggered: {
             cpuProc.running = true
             memProc.running = true
             diskProc.running = true
         }
     }

     Timer {
         interval: 100
         running: true
         repeat: true
         onTriggered: {
             volProc.running = true
         }
     }

    // One bar per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            color: root.colBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: 8

                // ---- Workspaces: always show 1-5, plus any occupied one up to 10 ----
                Repeater {
                    model: 15

                    Rectangle {
                        id: wsButton
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property var ws: I3.workspaces.values.find(w => w.number === wsId)
                        readonly property bool focused: I3.focusedWorkspace?.number === wsId
                        readonly property bool hasWindow: ws !== undefined

                        visible: wsId <= 3 || hasWindow
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 22
                        radius: 6
                        color : "transparent"
                        // color: focused ? colAccent : hasWindow ? colOccupied : "transparent"


                        Text {
                            text: wsButton.wsId
                            color: wsButton.focused ? root.colCyan : wsButton.hasWindow ? "#cccccc" : root.colMuted
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            font.bold: true
                            anchors.centerIn: parent
                        }

                        Rectangle {
                            width: 20
                            height: 3
                            color: wsButton.focused ? root.colCyan : root.colBg
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: I3.dispatch("workspace " + (wsButton.wsId))
                        }
                    }
                }

                Text {
                    text: ToplevelManager.activeToplevel?.title ?? ""
                    color: "#33ff99"
                    font.pixelSize: root.fontSize + 2
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    horizontalAlignment: Text.AlignHCenter
                }


                Text {
                    text: "Linux " + root.kernelVersion
                    color: root.colRed
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: 8
                    color: root.colMuted
                }

                Text {
                    text: "CPU: " + root.cpuUsage + "%"
                    color: root.colYellow
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: 8
                    color: root.colMuted
                }

                Text {
                    text: "Mem: " + root.memUsage + "%"
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: 8
                    color: root.colMuted
                }

                Text {
                    text: "Disk: " + root.diskUsage + "%"
                    color: root.colBlue
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: 8
                    color: root.colMuted
                }

                Text {
                    text: "Vol: " + root.volumeLevel + "%"
                    color: root.colPurple
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: 8
                    color: root.colMuted
                }
                // ---- Clock ----
                Text {
                    id: clockText
                    text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                    Layout.rightMargin: 8

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
                    }
                }

            }
        }
    }
}
