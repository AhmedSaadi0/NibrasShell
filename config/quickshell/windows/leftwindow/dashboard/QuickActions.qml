import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Io

import "root:/components"
import "root:/themes"

MenuCard {
    id: root

    title: qsTr("Quick Actions")
    icon: ""
    cardColor: ThemeManager.selectedTheme.colors.surfaceContainer
    textColor: ThemeManager.selectedTheme.colors.onSurface

    function _findWifiDevice() {
        return Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null;
    }

    property var wifiDevice: null
    property bool wifiAvailable: wifiDevice !== null
    property bool wifiEnabled: Networking.wifiEnabled

    property bool bluetoothAvailable: Bluetooth.defaultAdapter !== null
    property bool bluetoothEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

    property bool airplaneAvailable: wifiAvailable || bluetoothAvailable
    property bool airplaneEnabled: airplaneAvailable && (!wifiAvailable || !wifiEnabled) && (!bluetoothAvailable || !bluetoothEnabled)

    function toggleAction(actionName) {
        switch (actionName) {
        case "wifi":
            Networking.wifiEnabled = !Networking.wifiEnabled;
            break;
        case "bluetooth":
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
            break;
        case "airplane":
            if (root.airplaneEnabled) {
                if (root.wifiAvailable)
                    Networking.wifiEnabled = true;
                if (root.bluetoothAvailable && Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = true;
            } else {
                if (root.wifiAvailable)
                    Networking.wifiEnabled = false;
                if (root.bluetoothAvailable && Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = false;
            }
            break;
        }
    }

    RowLayout {
        spacing: 7
        Layout.fillWidth: true

        MButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            text: "Wi-Fi"
            iconText: root.wifiEnabled ? "" : "󰖪"
            iconFirst: true
            iconSize: 16
            enabled: root.wifiAvailable
            isActive: root.wifiEnabled && !root.airplaneEnabled
            onClicked: root.toggleAction("wifi")

            normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
            normalForeground: ThemeManager.selectedTheme.colors.onSurface
            hoverOpacity: 0.16
        }

        MButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            text: "Bluetooth"
            iconText: root.bluetoothEnabled ? "󰂯" : "󰂲"
            iconFirst: true
            iconSize: 16
            enabled: root.bluetoothAvailable
            isActive: root.bluetoothEnabled && !root.airplaneEnabled
            onClicked: root.toggleAction("bluetooth")
            normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
            normalForeground: ThemeManager.selectedTheme.colors.onSurface
            hoverOpacity: 0.16
        }

        MButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            text: "Airplane"
            iconText: "󰀝"
            iconSize: 16
            iconFirst: true
            enabled: root.airplaneAvailable
            isActive: root.airplaneEnabled
            onClicked: root.toggleAction("airplane")
            normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
            normalForeground: ThemeManager.selectedTheme.colors.onSurface
            hoverOpacity: 0.16
        }
    }

    Connections {
        target: Networking.devices
        function onValuesChanged() {
            root.wifiDevice = root._findWifiDevice();
        }
    }

    Component.onCompleted: {
        root.wifiDevice = root._findWifiDevice();
    }
}
