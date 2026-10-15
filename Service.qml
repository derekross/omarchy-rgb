import QtQuick
import Quickshell
import Quickshell.Io

// Headless lighting service. Keeps two processes running for the session:
// an OpenRGB SDK server (unless one is already listening, e.g. the user runs
// their own) and the omarchy-rgb effects daemon shipped in bin/. Either is
// restarted if it exits. Both stop with the shell; the daemon hands headsets
// back to their own lighting on the way out.
Item {
  id: root
  property var manifest: null
  property var shell: null

  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace("file://", "")).replace(/\/$/, "")
  readonly property string tool: pluginDir + "/bin/omarchy-rgb"

  // State the bar widget and panel read.
  property bool checked: false
  property bool openrgbAvailable: false
  property bool python3Available: false
  readonly property bool ready: openrgbAvailable && python3Available
  property bool ownServer: false
  property string lastError: ""

  readonly property int restartDelay: 3000

  Component.onCompleted: depsProc.running = true

  function startServer() {
    // Leave an OpenRGB server someone else started alone.
    if (portProc.running || serverProc.running) return
    portProc.running = true
  }

  Process {
    id: depsProc
    command: ["bash", "-c", "command -v openrgb >/dev/null && echo openrgb; command -v python3 >/dev/null && echo python3"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.openrgbAvailable = text.indexOf("openrgb") >= 0
        root.python3Available = text.indexOf("python3") >= 0
        root.checked = true
        if (!root.openrgbAvailable) root.lastError = "OpenRGB is not installed. Install it with: omarchy pkg add openrgb"
        else if (!root.python3Available) root.lastError = "python3 is not installed."
        else {
          root.lastError = ""
          root.startServer()
          daemonProc.running = true
        }
      }
    }
  }

  // Exits 0 when something already listens on the SDK port.
  Process {
    id: portProc
    command: ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/6742"]
    onExited: function(exitCode) {
      root.ownServer = exitCode !== 0
      if (root.ownServer) serverProc.running = true
    }
  }

  Process {
    id: serverProc
    command: ["openrgb", "--server", "--server-host", "127.0.0.1", "--noautoconnect"]
    onExited: if (root.ready) serverRestart.restart()
  }

  Timer {
    id: serverRestart
    interval: root.restartDelay
    onTriggered: root.startServer()
  }

  Process {
    id: daemonProc
    command: ["python3", root.tool, "daemon"]
    onExited: if (root.ready) daemonRestart.restart()
  }

  Timer {
    id: daemonRestart
    interval: root.restartDelay
    onTriggered: if (!daemonProc.running) daemonProc.running = true
  }
}
