import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "derekross.rgb"
  ipcTarget: "derekross.rgb"

  // Set by BarWidget.qml, which owns the bar button.
  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root

  // Why lighting isn't running, from the plugin's service.
  readonly property string setupMessage: {
    if (!service) return "The RGB service isn't running. Enable the plugin with: omarchy plugin enable derekross.rgb"
    if (service.lastError) return service.lastError
    return "Starting OpenRGB and the effects daemon…"
  }

  // The daemon script ships with the plugin; ask it directly so the panel
  // works without anything else on PATH.
  readonly property string tool: decodeURIComponent(Qt.resolvedUrl("bin/omarchy-rgb").toString().replace("file://", ""))

  property var status: ({ running: false, effect: "", devices: [], palette: [] })
  readonly property bool running: status.running === true
  readonly property string effect: status.effect || ""
  readonly property var devices: status.devices || []
  readonly property var palette: status.palette || []
  readonly property var room: status.room || ({})
  readonly property bool roomShown: running && (room.available === true || room.enabled === true)

  // Keyboard cursor across the action buttons, in reading order.
  readonly property var actions: ["static", "pulse", "wave", "manual", "off", "openrgb", "room"]
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var effectInfo: ({
    "static": { label: "Static", icon: "󰝥", detail: "Theme color" },
    "pulse": { label: "Pulse", icon: "󰐰", detail: "Theme color breathing" },
    "wave": { label: "Wave", icon: "󰞍", detail: "Theme palette" },
    "manual": { label: "Manual", icon: "󰏘", detail: "Your OpenRGB colors" },
    "off": { label: "Off", icon: "󰹏", detail: "Lights off" }
  })

  readonly property bool lit: running && effect !== "off"

  function toggleLights() {
    setEffect(effect === "off" ? "static" : "off")
  }

  readonly property color tint: {
    if (!running || effect === "off" || effect === "manual") return root.bar ? root.bar.foreground : Color.foreground
    if (effect === "wave" && palette.length > 0) return palette[Math.floor(palette.length / 2)]
    return status.color || (root.bar ? root.bar.foreground : Color.foreground)
  }

  function deviceIcon(type) {
    if (type === "keyboard") return "󰌌"
    if (type === "mouse") return "󰍽"
    if (type === "headset") return "󰋋"
    if (type === "light") return "󰌵"
    return "󰛨"
  }

  function themeName() {
    return (status.theme || "").split("-").map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1) }).join(" ")
  }

  function statusLine() {
    if (!running) return "Not running"
    var info = effectInfo[effect]
    var line = info ? info.label : effect
    if (effect === "static" || effect === "pulse" || effect === "wave") line += " · " + themeName()
    return line
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function setEffect(name) {
    if (actionProc.running) return
    actionProc.command = [root.tool, "effect", name]
    actionProc.running = true
  }

  function toggleRoom() {
    if (actionProc.running) return
    actionProc.command = [root.tool, "room", "toggle"]
    actionProc.running = true
  }

  function roomDetail() {
    if (room.error) return room.error
    var areas = (room.areas || []).join(", ")
    if (!room.available) return "Hue Entertainment area not found"
    if (!room.enabled) return "Match " + areas + " to the effect"
    if (effect === "manual") return areas + " · back to its own colors"
    return areas + " · following the effect"
  }

  function openOpenRgb() {
    // The app connects to the running OpenRGB server; switch to manual first
    // so the daemon stops painting over whatever gets picked there.
    setEffect("manual")
    Quickshell.execDetached(["openrgb"])
    root.close()
  }

  function activate(index) {
    var action = actions[index]
    if (action === "openrgb") openOpenRgb()
    else if (action === "room") toggleRoom()
    else setEffect(action)
  }

  function moveCursor(dx, dy) {
    // Rows: [static pulse wave] [manual off] [openrgb] [room]
    var rows = roomShown ? [[0, 1, 2], [3, 4], [5], [6]] : [[0, 1, 2], [3, 4], [5]]
    var row = 0, col = 0
    for (var r = 0; r < rows.length; r++) {
      var c = rows[r].indexOf(cursorIndex)
      if (c >= 0) { row = r; col = c }
    }
    if (dy !== 0) {
      row = Math.max(0, Math.min(rows.length - 1, row + dy))
      col = Math.min(col, rows[row].length - 1)
    } else {
      col = Math.max(0, Math.min(rows[row].length - 1, col + dx))
    }
    cursorIndex = rows[row][col]
  }

  Process {
    id: statusProc
    command: [root.tool, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.status = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  // Effect and theme changes reach the daemon through files, so polling the
  // status is enough to keep the tint current; faster while the panel is open.
  Timer {
    interval: root.opened ? 1500 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      var idx = actions.indexOf(effect)
      cursorIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive && root.running) root.activate(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title/status · current colors ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰌌"
            color: root.tint
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: swatches.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "Lighting"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusLine().toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // The colors the current effect is painting with.
          Row {
            id: swatches
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            visible: root.running && (root.effect === "static" || root.effect === "pulse" || root.effect === "wave")

            Repeater {
              model: root.effect === "wave" ? root.palette : (root.status.color ? [root.status.color] : [])
              Rectangle {
                required property var modelData
                width: Style.space(14)
                height: Style.space(14)
                radius: width / 2
                color: modelData
                border.width: 1
                border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)
              }
            }
          }
        }

        // ---------- Not running yet, or missing a dependency ----------
        Text {
          visible: !root.running
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: root.setupMessage
          color: root.bar.foreground
          opacity: 0.7
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---------- Theme effects ----------
        PanelSeparator {
          visible: root.running
          foreground: root.bar.foreground
        }

        Column {
          visible: root.running
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "THEME COLORS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          EffectRow { effects: ["static", "pulse", "wave"]; firstIndex: 0 }
        }

        // ---------- Without the theme ----------
        Column {
          visible: root.running
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "YOUR OWN COLORS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          EffectRow { effects: ["manual", "off"]; firstIndex: 3 }

          Button {
            width: parent.width
            text: "Open OpenRGB"
            iconText: "󰏘"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            hasCursor: root.cursorActive && root.cursorIndex === 5
            onClicked: root.openOpenRgb()
            onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = 5 } }
          }
        }

        // ---------- Room lights ----------
        Column {
          visible: root.roomShown
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "ROOM"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Room lights"
            description: root.roomDetail()
            checked: root.room.enabled === true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            hasCursor: root.cursorActive && root.cursorIndex === 6
            onClicked: root.toggleRoom()
            onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = 6 } }
          }
        }

        // ---------- Devices ----------
        PanelSeparator {
          visible: root.running
          foreground: root.bar.foreground
        }

        Column {
          visible: root.running
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "DEVICES"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Text {
            visible: root.devices.length === 0
            textFormat: Text.PlainText
            text: "Looking for devices…"
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.devices
            Row {
              required property var modelData
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: root.deviceIcon(modelData.type)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }
  }

  component EffectRow: Row {
    id: effectRow
    property var effects: []
    property int firstIndex: 0

    width: parent.width
    spacing: Style.space(6)

    readonly property real cellWidth: effects.length > 0 ? (width - spacing * (effects.length - 1)) / effects.length : 0

    Repeater {
      model: effectRow.effects
      Button {
        required property var modelData
        required property int index
        width: effectRow.cellWidth
        iconText: root.effectInfo[modelData].icon
        iconSize: Style.font.title
        text: root.effectInfo[modelData].label
        tooltipText: root.effectInfo[modelData].detail
        fontSize: Style.font.bodySmall
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
        bordered: true
        active: root.effect === modelData
        hasCursor: root.cursorActive && root.cursorIndex === effectRow.firstIndex + index
        onClicked: root.setEffect(modelData)
        onHovered: function(h) {
          if (h) {
            root.cursorActive = true
            root.cursorIndex = effectRow.firstIndex + index
          }
        }
      }
    }
  }
}
