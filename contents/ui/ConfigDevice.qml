import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: configDevice

    visible: false
    width: 0
    height: 0

    property bool intelPstateAvailable: false
    property bool intelPstateNoTurboEnabled: false

    readonly property string intelPstateNoTurboPath: "/sys/devices/system/cpu/intel_pstate/no_turbo"

    Plasma5Support.DataSource {
        id: deviceSource
        engine: "executable"
        connectedSources: []
        interval: 0

        onNewData: (source, data) => {
            var out = String(data["stdout"] || "").trim()

            if (source === configDevice.intelPstateReadCommand()) {
                configDevice.intelPstateAvailable = out === "0" || out === "1"
                if (configDevice.intelPstateAvailable) {
                    configDevice.intelPstateNoTurboEnabled = out === "1"
                }
            } else if (source === configDevice.intelPstateWriteCommand(true)
                    || source === configDevice.intelPstateWriteCommand(false)) {
                configDevice.updateIntelPstate()
            }

            disconnectSource(source)
        }
    }

    function updateIntelPstate() {
        deviceSource.connectSource(intelPstateReadCommand())
    }

    function setIntelPstateNoTurbo(enabled) {
        intelPstateNoTurboEnabled = enabled
        deviceSource.connectSource(intelPstateWriteCommand(enabled))
    }

    function intelPstateReadCommand() {
        return "sh -c 'test -r " + intelPstateNoTurboPath + " && cat " + intelPstateNoTurboPath + " || true'"
    }

    function intelPstateWriteCommand(enabled) {
        return "pkexec sh -c 'echo " + (enabled ? "1" : "0") + " > " + intelPstateNoTurboPath + "'"
    }
}
