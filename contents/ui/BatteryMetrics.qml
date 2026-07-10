import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: metrics

    visible: false
    width: 0
    height: 0

    property var batteryEntries: []
    property string batteryStatus: "Unknown"
    property bool noBattery: false
    property int probeIdx: 0
    property string batteryPath: ""

    property real watts: 0
    property real energyNowWh: -1
    property real energyFullWh: -1
    property real chargeNowAh: -1
    property real chargeFullAh: -1
    property real voltageV: -1
    property real currentA: -1

    readonly property var pollFiles: [
        "power_now",
        "energy_now",
        "energy_full",
        "charge_now",
        "charge_full",
        "voltage_now",
        "current_now",
        "status"
    ]

    Plasma5Support.DataSource {
        id: batterySource
        engine: "executable"
        connectedSources: []
        interval: 0

        onNewData: (source, data) => {
            var out = String(data["stdout"] || "").trim()
            metrics.handleSource(source, out)
            disconnectSource(source)
        }
    }

    function rediscover() {
        batteryPath = ""
        noBattery = false
        batteryEntries = []
        probeIdx = 0
        resetReadings()
        batterySource.connectSource("ls /sys/class/power_supply/")
    }

    function refresh() {
        if (batteryPath === "") {
            if (batteryEntries.length === 0 && !noBattery) {
                rediscover()
            }
            return
        }

        for (var i = 0; i < pollFiles.length; i++) {
            batterySource.connectSource("cat " + batteryPath + "/" + pollFiles[i])
        }
    }

    function handleSource(source, output) {
        if (source === "ls /sys/class/power_supply/") {
            batteryEntries = output.split(/\s+/).filter(function(entry) {
                return entry.length > 0
            })
            noBattery = batteryEntries.length === 0
            if (!noBattery) {
                probeIdx = 0
                probeNext()
            }
            return
        }

        if (source.includes("/type")) {
            if (output === "Battery") {
                batteryPath = "/sys/class/power_supply/" + batteryEntries[probeIdx]
                refresh()
                return
            }

            probeIdx++
            if (probeIdx < batteryEntries.length) {
                probeNext()
            } else {
                noBattery = true
            }
            return
        }

        updateReading(source, output)
    }

    function probeNext() {
        batterySource.connectSource("cat /sys/class/power_supply/" + batteryEntries[probeIdx] + "/type")
    }

    function resetReadings() {
        watts = 0
        energyNowWh = -1
        energyFullWh = -1
        chargeNowAh = -1
        chargeFullAh = -1
        voltageV = -1
        currentA = -1
        batteryStatus = "Unknown"
    }

    function updateReading(source, output) {
        if (source.includes("power_now")) {
            var powerRaw = parseFloat(output)
            if (!isNaN(powerRaw)) {
                watts = powerRaw / 1000000
            }
            return
        }

        if (source.includes("energy_now")) {
            energyNowWh = toMegaUnit(output)
            return
        }

        if (source.includes("energy_full")) {
            energyFullWh = toMegaUnit(output)
            return
        }

        if (source.includes("charge_now")) {
            chargeNowAh = toMegaUnit(output)
            return
        }

        if (source.includes("charge_full")) {
            chargeFullAh = toMegaUnit(output)
            return
        }

        if (source.includes("voltage_now")) {
            voltageV = toMegaUnit(output)
            return
        }

        if (source.includes("current_now")) {
            currentA = toMegaUnit(output)
            if (watts <= 0 && currentA > 0 && voltageV > 0) {
                watts = currentA * voltageV
            }
            return
        }

        if (source.includes("status")) {
            batteryStatus = output
        }
    }

    function formattedRemainingTime() {
        if (batteryStatus === "Full") return "Charged"
        if (batteryStatus !== "Charging" && batteryStatus !== "Discharging") return batteryStatus

        var hours = remainingHours()
        if (hours < 0) return "--:--"

        return formatDuration(Math.round(hours * 3600))
    }

    function formatDuration(totalSeconds) {
        var wholeHours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = totalSeconds % 60

        if (wholeHours > 0) {
            return wholeHours + "h " + minutes + "m " + seconds + "s"
        }

        if (minutes > 0) {
            return minutes + "m " + seconds + "s"
        }

        return seconds + "s"
    }

    function toMegaUnit(output) {
        var raw = parseFloat(output)
        return isNaN(raw) ? -1 : raw / 1000000
    }

    function remainingHours() {
        var powerWatts = currentPowerWatts()
        if (noBattery || batteryPath === "" || powerWatts <= 0) return -1
        if (batteryStatus === "Full") return 0

        var nowWh = currentEnergyWh()
        if (nowWh < 0) return -1

        if (batteryStatus === "Charging") {
            var fullWh = fullEnergyWh()
            if (fullWh > nowWh) {
                return (fullWh - nowWh) / powerWatts
            }
        }

        return nowWh / powerWatts
    }

    function currentPowerWatts() {
        if (watts > 0) return watts
        if (currentA > 0 && voltageV > 0) return currentA * voltageV
        return -1
    }

    function currentEnergyWh() {
        if (energyNowWh >= 0) return energyNowWh
        if (chargeNowAh >= 0 && voltageV > 0) return chargeNowAh * voltageV
        return -1
    }

    function fullEnergyWh() {
        if (energyFullWh >= 0) return energyFullWh
        if (chargeFullAh >= 0 && voltageV > 0) return chargeFullAh * voltageV
        return -1
    }
}
