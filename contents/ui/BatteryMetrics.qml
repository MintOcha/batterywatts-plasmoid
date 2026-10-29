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

    property real watts: NaN
    property bool powerNowValid: false
    property real energyNowWh: NaN
    property real energyFullWh: NaN
    property real chargeNowAh: NaN
    property real chargeFullAh: NaN
    property real voltageV: NaN
    property real currentA: NaN

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
        powerNowValid = false
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
            } else {
                handleNoBattery()
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
                handleNoBattery()
            }
            return

        updateReading(source, output)
    }

    function probeNext() {
        batterySource.connectSource("cat /sys/class/power_supply/" + batteryEntries[probeIdx] + "/type")
    }

    function handleNoBattery() {
        noBattery = true
        batteryStatus = "Desktop"
        watts = NaN
    }

    function resetReadings() {
        watts = NaN
        powerNowValid = false
        energyNowWh = NaN
        energyFullWh = NaN
        chargeNowAh = NaN
        chargeFullAh = NaN
        voltageV = NaN
        currentA = NaN
        batteryStatus = "Unknown"
    }
    function updateReading(source, output) {
        if (source.includes("power_now")) {
            var powerRaw = parseFloat(output)
            if (isFinite(powerRaw) && powerRaw > 0) {
                watts = powerRaw / 1000000
                powerNowValid = true
            } else {
                powerNowValid = false
                updateFallbackWatts()
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
            if (!powerNowValid) {
                updateFallbackWatts()
            }
            return
        }

        if (source.includes("current_now")) {
            currentA = toMegaUnit(output)
            if (!powerNowValid) {
                updateFallbackWatts()
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
        return isFinite(raw) ? raw / 1000000 : NaN
    }
    function updateFallbackWatts() {
        if (powerNowValid) return

        var absCurrent = Math.abs(currentA)
        var absVoltage = Math.abs(voltageV)

        if (isFinite(absCurrent) && isFinite(absVoltage) && absCurrent > 0 && absVoltage > 0 && voltageV > 0) {
            watts = absCurrent * absVoltage
        } else {
            watts = NaN
        }
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
        if (isFinite(watts) && watts > 0) return watts
        var absCurrent = Math.abs(currentA)
        if (isFinite(absCurrent) && absCurrent > 0 && isFinite(voltageV) && voltageV > 0) {
            return absCurrent * voltageV
        }
        return -1
    }

    function currentEnergyWh() {
        if (isFinite(energyNowWh) && energyNowWh >= 0) return energyNowWh
        var absCharge = Math.abs(chargeNowAh)
        if (isFinite(absCharge) && absCharge >= 0 && isFinite(voltageV) && voltageV > 0) {
            return absCharge * voltageV
        }
        return -1
    }

    function fullEnergyWh() {
        if (isFinite(energyFullWh) && energyFullWh >= 0) return energyFullWh
        var absCharge = Math.abs(chargeFullAh)
        if (isFinite(absCharge) && absCharge >= 0 && isFinite(voltageV) && voltageV > 0) {
            return absCharge * voltageV
        }
        return -1
    }
}
