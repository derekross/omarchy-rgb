import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "derekross.rgb"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("derekross.rgb") : null

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  onServiceChanged: injectPanel()

  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function toggleLights() { if (panelLoader.item) panelLoader.item.toggleLights() }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool lit: panelLoader.item ? panelLoader.item.lit : false
  readonly property color tint: panelLoader.item ? panelLoader.item.tint : (root.bar ? root.bar.barForeground : Color.foreground)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    foreground: root.tint
    dimmed: !root.lit
    tooltipText: "Lighting · right-click to turn off or back on"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleLights()
      else root.togglePanel()
    }
  }
}
