import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import BatteryWatts

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    readonly property string defaultChargingFormat: "⚡ +{watts} W"
    readonly property string defaultDischargingFormat: "🔋 -{watts} W"
    readonly property string defaultFullFormat: "✓ {watts} W"
    readonly property string defaultOtherFormat: "🔌 {watts} W"

    function roundedSignificant(value, digits) {
        if (value === 0) {
            return "0";
        }

        const places = Math.max(0, digits - Math.floor(Math.log10(Math.abs(value))) - 1);
        return Number(value).toFixed(places).replace(/\.?0+$/, "");
    }

    function formattedWatts() {
        const value = Math.abs(battery.watts);
        if (settings.precisionMode === 1) {
            return roundedSignificant(value, Math.max(1, settings.precisionValue));
        }
        return value.toFixed(Math.max(0, settings.precisionValue));
    }

    function formatTemplate(templateText) {
        return templateText.replace(/\{watts\}/g, formattedWatts());
    }

    function activeTemplate() {
        if (battery.status === "Charging") {
            return settings.chargingFormat;
        }
        if (battery.status === "Discharging") {
            return settings.dischargingFormat;
        }
        if (battery.status === "Full") {
            return settings.fullFormat;
        }
        return settings.otherFormat;
    }

    function displayText() {
        return formatTemplate(activeTemplate());
    }

    function resetFormats() {
        settings.chargingFormat = defaultChargingFormat;
        settings.dischargingFormat = defaultDischargingFormat;
        settings.fullFormat = defaultFullFormat;
        settings.otherFormat = defaultOtherFormat;
        settings.sync();
    }

    function hasOldTokens(templateText) {
        return templateText.indexOf("{emoji}") !== -1
            || templateText.indexOf("{sign}") !== -1
            || templateText.indexOf("{status}") !== -1
            || /\{watts\.\d+(?:sf|dp)?\}/.test(templateText);
    }

    Component.onCompleted: {
        if (hasOldTokens(settings.chargingFormat)
                || hasOldTokens(settings.dischargingFormat)
                || hasOldTokens(settings.fullFormat)
                || hasOldTokens(settings.otherFormat)) {
            resetFormats();
        }
    }

    Settings {
        id: settings
        category: "BatteryWatts"

        property int precisionMode: 0
        property int precisionValue: 1
        property int pollingSeconds: 2
        property string chargingFormat: root.defaultChargingFormat
        property string dischargingFormat: root.defaultDischargingFormat
        property string fullFormat: root.defaultFullFormat
        property string otherFormat: root.defaultOtherFormat
    }

    BatteryWatts {
        id: battery
        pollingInterval: settings.pollingSeconds * 1000
    }

    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredWidth: Math.min(label.implicitWidth + Kirigami.Units.smallSpacing * 2, Kirigami.Units.gridUnit * 5)
        Layout.maximumWidth: Kirigami.Units.gridUnit * 5
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium

        implicitWidth: Layout.preferredWidth
        implicitHeight: Math.max(label.implicitHeight, Layout.minimumHeight)

        PlasmaComponents.Label {
            id: label
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.displayText()
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize + 2
            minimumPixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 2)
            fontSizeMode: Text.Fit
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        id: contentColumn
        spacing: Kirigami.Units.smallSpacing
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22

        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true
            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.displayText()
                    elide: Text.ElideRight
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: battery.status + " • " + battery.batteryPath
                    elide: Text.ElideMiddle
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "Precision"
            }

            PlasmaComponents.ComboBox {
                Layout.fillWidth: true
                model: ["Decimal places", "Significant figures"]
                currentIndex: settings.precisionMode
                onActivated: index => {
                    settings.precisionMode = index;
                    settings.sync();
                }
            }

            PlasmaComponents.Label {
                text: "Digits"
            }

            PlasmaComponents.SpinBox {
                Layout.fillWidth: true
                from: settings.precisionMode === 1 ? 1 : 0
                to: 6
                value: Math.max(from, settings.precisionValue)
                onValueModified: {
                    settings.precisionValue = value;
                    settings.sync();
                }
            }

            PlasmaComponents.Label {
                text: "Polling"
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.SpinBox {
                    id: pollingSpinBox
                    Layout.fillWidth: true
                    from: 1
                    to: 60
                    value: settings.pollingSeconds
                    onValueModified: {
                        settings.pollingSeconds = value;
                        settings.sync();
                    }
                }

                PlasmaComponents.Label {
                    text: "s"
                }
            }

            PlasmaComponents.Label {
                text: "Charging"
            }

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                text: settings.chargingFormat
                placeholderText: root.defaultChargingFormat
                onEditingFinished: {
                    settings.chargingFormat = text;
                    settings.sync();
                }
            }

            PlasmaComponents.Label {
                text: "Discharging"
            }

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                text: settings.dischargingFormat
                placeholderText: root.defaultDischargingFormat
                onEditingFinished: {
                    settings.dischargingFormat = text;
                    settings.sync();
                }
            }

            PlasmaComponents.Label {
                text: "Full"
            }

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                text: settings.fullFormat
                placeholderText: root.defaultFullFormat
                onEditingFinished: {
                    settings.fullFormat = text;
                    settings.sync();
                }
            }

            PlasmaComponents.Label {
                text: "Not charging"
            }

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                text: settings.otherFormat
                placeholderText: root.defaultOtherFormat
                onEditingFinished: {
                    settings.otherFormat = text;
                    settings.sync();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing

            PlasmaComponents.Button {
                text: "Refresh"
                icon.name: "view-refresh-symbolic"
                onClicked: battery.refresh()
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents.Button {
                text: "Reset"
                icon.name: "edit-undo-symbolic"
                onClicked: root.resetFormats()
            }
        }
    }
}
