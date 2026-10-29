import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: configDevice

    visible: false
    width: 0
    height: 0

    property bool powerCapAvailable: false
    property bool powerCapEnabled: false
    property string backend: "none"

    readonly property string intelPstateNoTurboPath: "/sys/devices/system/cpu/intel_pstate/no_turbo"
    readonly property string cpufreqBoostPath: "/sys/devices/system/cpu/cpufreq/boost"

    Plasma5Support.DataSource {
        id: deviceSource
        engine: "executable"
        connectedSources: []
        interval: 0

        onNewData: (source, data) => {
            var out = String(data["stdout"] || "").trim()

            if (source === configDevice.powerCapReadCommand()) {
                if (out.indexOf("intel:") === 0) {
                    configDevice.backend = "intel"
                    configDevice.powerCapAvailable = true
                    configDevice.powerCapEnabled = out.substring(6).trim() === "1"
                } else if (out.indexOf("cpufreq:") === 0) {
                    configDevice.backend = "cpufreq"
                    configDevice.powerCapAvailable = true
                    configDevice.powerCapEnabled = out.substring(8).trim() === "0"
                } else {
                    configDevice.backend = "none"
                    configDevice.powerCapAvailable = false
                    configDevice.powerCapEnabled = false
                }
            } else if (source === configDevice.powerCapWriteCommand(true)
                    || source === configDevice.powerCapWriteCommand(false)) {
                configDevice.updatePowerCap()
            }

            disconnectSource(source)
        }
    }

    function updatePowerCap() {
        deviceSource.connectSource(powerCapReadCommand())
    }

    function setPowerCap(enabled) {
        powerCapEnabled = enabled
        deviceSource.connectSource(powerCapWriteCommand(enabled))
    }

    function powerCapReadCommand() {
        return "sh -c 'if [ -r " + intelPstateNoTurboPath + " ]; then echo \"intel:$(cat " + intelPstateNoTurboPath + ")\"; elif [ -r " + cpufreqBoostPath + " ]; then echo \"cpufreq:$(cat " + cpufreqBoostPath + ")\"; else echo \"none\"; fi'"
    }

    function powerCapWriteCommand(enabled) {
        return "pkexec sh -c 'if [ -w " + intelPstateNoTurboPath + " ]; then echo " + (enabled ? "1" : "0") + " > " + intelPstateNoTurboPath + "; elif [ -w " + cpufreqBoostPath + " ]; then echo " + (enabled ? "0" : "1") + " > " + cpufreqBoostPath + "; fi'"
    }
}
