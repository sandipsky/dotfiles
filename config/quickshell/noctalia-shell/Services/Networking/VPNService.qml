pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var connections: ({})
  property bool refreshing: false
  property bool connecting: false
  property bool disconnecting: false
  property bool removing: false
  property bool importing: false
  property string connectingUuid: ""
  property string disconnectingUuid: ""
  property string removingUuid: ""
  property string lastError: ""
  property bool refreshPending: false

  readonly property var activeConnections: {
    const result = [];
    const map = connections;
    for (const key in map) {
      const conn = map[key];
      if (conn && conn.active) {
        result.push(conn);
      }
    }
    return result;
  }

  readonly property var inactiveConnections: {
    const result = [];
    const map = connections;
    for (const key in map) {
      const conn = map[key];
      if (conn && !conn.active) {
        result.push(conn);
      }
    }
    return result;
  }

  readonly property bool hasActiveConnection: activeConnections.length > 0

  // Slow fallback poll only — real-time updates come from nmcli monitor events
  // below, so this just catches anything the event stream might miss. The old
  // 5 s poll spawned ~720 nmcli processes per hour for no benefit.
  Timer {
    id: refreshTimer
    interval: 60000
    running: true
    repeat: true
    onTriggered: refresh()
  }

  Timer {
    id: delayedRefreshTimer
    interval: 1000
    repeat: false
    onTriggered: refresh()
  }

  // Refresh on NetworkManager events (VPN/WireGuard activation shows up as
  // device or connection-profile lines). Debounced through delayedRefreshTimer
  // so event bursts trigger a single nmcli call.
  Connections {
    target: NetworkService
    function onMonitorLine(line) {
      if (/connect|profile|vpn|wireguard|tun[0-9]|removed|added/i.test(line)) {
        delayedRefreshTimer.restart();
      }
    }
  }

  Component.onCompleted: {
    Logger.i("VPN", "Service started");
    refresh();
  }

  function refresh() {
    if (refreshing) {
      refreshPending = true;
      return;
    }
    refreshing = true;
    lastError = "";
    refreshProcess.running = true;
  }

  function connect(uuid) {
    if (connecting || !uuid) {
      return;
    }
    const conn = connections[uuid];
    if (!conn) {
      return;
    }
    connecting = true;
    connectingUuid = uuid;
    lastError = "";
    connectProcess.uuid = uuid;
    connectProcess.name = conn.name;
    connectProcess.running = true;
  }

  function disconnect(uuid) {
    if (disconnecting || !uuid) {
      return;
    }
    const conn = connections[uuid];
    if (!conn) {
      return;
    }
    disconnecting = true;
    disconnectingUuid = uuid;
    lastError = "";
    disconnectProcess.uuid = uuid;
    disconnectProcess.name = conn.name;
    disconnectProcess.running = true;
  }

  function toggle(uuid) {
    const conn = connections[uuid];
    if (!conn) {
      return;
    }
    if (conn.active) {
      disconnect(uuid);
    } else {
      connect(uuid);
    }
  }

  // Delete a VPN profile from NetworkManager entirely
  function remove(uuid) {
    if (removing || !uuid) {
      return;
    }
    const conn = connections[uuid];
    if (!conn) {
      return;
    }
    removing = true;
    removingUuid = uuid;
    lastError = "";
    removeProcess.uuid = uuid;
    removeProcess.name = conn.name;
    removeProcess.running = true;
  }

  // Import a new VPN profile from a config file (WireGuard .conf / OpenVPN .ovpn)
  function importConfig(path) {
    if (importing || !path) {
      return;
    }
    // NetworkManager needs the VPN type up-front; infer it from the extension
    const lower = path.toLowerCase();
    var type = "wireguard";
    if (lower.endsWith(".ovpn")) {
      type = "openvpn";
    }
    importing = true;
    lastError = "";
    importProcess.path = path;
    importProcess.vpnType = type;
    importProcess.running = true;
  }

  function setConnection(uuid, data) {
    if (!uuid) {
      return;
    }
    const map = Object.assign({}, connections);
    if (map[uuid]) {
      map[uuid] = Object.assign({}, map[uuid], data);
      connections = map;
    }
  }

  function scheduleRefresh(interval) {
    delayedRefreshTimer.interval = interval;
    delayedRefreshTimer.restart();
  }

  Process {
    id: refreshProcess
    running: false
    command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n");
        const map = {};
        for (let i = 0; i < lines.length; ++i) {
          const line = lines[i].trim();
          if (!line) {
            continue;
          }
          const lastColonIdx = line.lastIndexOf(":");
          if (lastColonIdx === -1) {
            continue;
          }
          const device = line.substring(lastColonIdx + 1);
          const remaining = line.substring(0, lastColonIdx);
          const secondLastColonIdx = remaining.lastIndexOf(":");
          if (secondLastColonIdx === -1) {
            continue;
          }
          const type = remaining.substring(secondLastColonIdx + 1);
          if (type !== "vpn" && type !== "wireguard") {
            continue;
          }
          const remaining2 = remaining.substring(0, secondLastColonIdx);
          const thirdLastColonIdx = remaining2.lastIndexOf(":");
          if (thirdLastColonIdx === -1) {
            continue;
          }
          const uuid = remaining2.substring(thirdLastColonIdx + 1);
          const name = remaining2.substring(0, thirdLastColonIdx);
          if (!uuid || !name) {
            continue;
          }
          const active = device && device !== "--";
          map[uuid] = {
            "uuid": uuid,
            "name": name,
            "device": device,
            "active": active
          };
        }
        connections = map;
        const pending = refreshPending;
        refreshing = false;
        refreshPending = false;
        if (pending) {
          scheduleRefresh(200);
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const pending = refreshPending;
        refreshing = false;
        refreshPending = false;
        if (text.trim()) {
          lastError = text.split("\n")[0].trim();
          Logger.w("VPN", "Refresh error: " + text);
        }
        if (pending) {
          scheduleRefresh(2000);
        }
      }
    }
  }

  Process {
    id: connectProcess
    property string uuid: ""
    property string name: ""
    running: false
    command: ["nmcli", "connection", "up", "uuid", uuid]

    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (!output || (!output.includes("successfully activated") && !output.includes("Connection successfully"))) {
          return;
        }
        setConnection(connectProcess.uuid, {
                        "active": true
                      });
        connecting = false;
        connectingUuid = "";
        lastError = "";
        Logger.i("VPN", "Connected to " + connectProcess.name);
        ToastService.showNotice(connectProcess.name, I18n.tr("toast.vpn.connected", {
                                                               "name": connectProcess.name
                                                             }), "shield-lock");
        scheduleRefresh(1000);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const trimmed = text.trim();
        if (trimmed) {
          lastError = trimmed.split("\n")[0].trim();
          Logger.w("VPN", "Connect error: " + trimmed);
          ToastService.showWarning(connectProcess.name, lastError);
        }
        connecting = false;
        connectingUuid = "";
      }
    }
  }

  Process {
    id: disconnectProcess
    property string uuid: ""
    property string name: ""
    running: false
    command: ["nmcli", "connection", "down", "uuid", uuid]

    stdout: StdioCollector {
      onStreamFinished: {
        Logger.i("VPN", "Disconnected from " + disconnectProcess.name);
        setConnection(disconnectProcess.uuid, {
                        "active": false,
                        "device": ""
                      });
        disconnecting = false;
        disconnectingUuid = "";
        lastError = "";
        ToastService.showNotice(disconnectProcess.name, I18n.tr("toast.vpn.disconnected", {
                                                                  "name": disconnectProcess.name
                                                                }), "shield-off");
        scheduleRefresh(1000);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const trimmed = text.trim();
        if (trimmed) {
          lastError = trimmed.split("\n")[0].trim();
          Logger.w("VPN", "Disconnect error: " + trimmed);
          ToastService.showWarning(disconnectProcess.name, lastError);
        }
        disconnecting = false;
        disconnectingUuid = "";
      }
    }
  }

  Process {
    id: removeProcess
    property string uuid: ""
    property string name: ""
    running: false
    command: ["nmcli", "connection", "delete", "uuid", uuid]

    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (!output || !output.includes("successfully deleted")) {
          return;
        }
        const map = Object.assign({}, connections);
        delete map[removeProcess.uuid];
        connections = map;
        removing = false;
        removingUuid = "";
        lastError = "";
        Logger.i("VPN", "Removed " + removeProcess.name);
        ToastService.showNotice(removeProcess.name, I18n.tr("vpn.panel.remove-success"), "trash");
        scheduleRefresh(500);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const trimmed = text.trim();
        if (trimmed) {
          lastError = trimmed.split("\n")[0].trim();
          Logger.w("VPN", "Remove error: " + trimmed);
          ToastService.showWarning(removeProcess.name, lastError);
        }
        removing = false;
        removingUuid = "";
      }
    }
  }

  Process {
    id: importProcess
    property string path: ""
    property string vpnType: "wireguard"
    running: false
    command: ["nmcli", "connection", "import", "type", vpnType, "file", path]

    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (!output || !output.includes("successfully added")) {
          return;
        }
        importing = false;
        lastError = "";
        Logger.i("VPN", "Imported " + importProcess.path);
        ToastService.showNotice(I18n.tr("vpn.panel.title"), I18n.tr("vpn.panel.import-success"), "shield-plus");
        scheduleRefresh(500);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const trimmed = text.trim();
        if (trimmed) {
          lastError = trimmed.split("\n")[0].trim();
          Logger.w("VPN", "Import error: " + trimmed);
          ToastService.showWarning(I18n.tr("vpn.panel.title"), lastError);
        }
        importing = false;
      }
    }
  }
}
