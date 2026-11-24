// windows/settings/components/general/LockIdlePage.qml

import QtQuick
import QtQuick.Layouts

import "root:/components"
import "root:/components/settings"
import "root:/windows/settings/components"
import "root:/config"
import "root:/themes"

BaseGeneralSettings {
    id: page

    title: qsTr("Lock & Idle")
    icon: "\uf023"

    property var theme: page.selectedTheme

    property bool localLockEnabled: true
    property bool localAutoLockEnabled: false
    property int localDimTimeoutSec: 300
    property int localLockTimeoutSec: 900
    property int localDpmsOffAfterLockSec: 60
    property int localAutoSuspendSec: 0
    property real localDimOverlayOpacity: 0.65
    property int localDimBacklightPercent: 20
    property bool localRespectIdleInhibitors: true
    property bool localLockOnSuspend: true

    function clampInt(value, min, max) {
        let n = Number(value);
        if (!isFinite(n))
            n = min;
        return Math.min(max, Math.max(min, Math.round(n)));
    }

    function formatDuration(sec) {
        const s = clampInt(sec, 0, 86400);
        if (s === 0)
            return qsTr("Disabled");
        if (s < 60)
            return qsTr("%1 s").arg(s);
        if (s < 3600) {
            const m = Math.floor(s / 60);
            const rest = s % 60;
            return rest === 0 ? qsTr("%1 m").arg(m) : qsTr("%1 m %2 s").arg(m).arg(rest);
        }
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return m === 0 ? qsTr("%1 h").arg(h) : qsTr("%1 h %2 m").arg(h).arg(m);
    }

    function formatPercent(value) {
        return Math.round(Number(value) || 0) + "%";
    }

    function formatOpacity(value) {
        return Math.round((Number(value) || 0) * 100) + "%";
    }

    function setDimTimeout(value) {
        localDimTimeoutSec = clampInt(value, 0, 3600);
        if (localDimTimeoutSec > 0 && localLockTimeoutSec <= localDimTimeoutSec)
            localLockTimeoutSec = localDimTimeoutSec + 60;
    }

    function setLockTimeout(value) {
        const min = localDimTimeoutSec > 0 ? localDimTimeoutSec + 60 : 30;
        localLockTimeoutSec = clampInt(value, min, 7200);
    }

    function setDpmsTimeout(value) {
        localDpmsOffAfterLockSec = clampInt(value, 0, 600);
    }

    function setAutoSuspend(value) {
        localAutoSuspendSec = clampInt(value, 0, 7200);
    }

    function setBacklightPercent(value) {
        localDimBacklightPercent = clampInt(value, 1, 100);
    }

    function syncFromConfig() {
        localLockEnabled = App.lockEnabled;
        localAutoLockEnabled = App.autoLockEnabled;
        setDimTimeout(App.dimTimeoutSec);
        setLockTimeout(App.lockTimeoutSec);
        setDpmsTimeout(App.dpmsOffAfterLockSec);
        setAutoSuspend(App.autoSuspendSec);
        localDimOverlayOpacity = Math.min(1, Math.max(0, App.dimOverlayOpacity));
        setBacklightPercent(App.dimBacklightPercent);
        localRespectIdleInhibitors = App.respectIdleInhibitors;
        localLockOnSuspend = App.lockOnSuspend;
    }

    function serializeData() {
        return {
            "lockEnabled": localLockEnabled,
            "autoLockEnabled": localAutoLockEnabled,
            "dimTimeoutSec": localDimTimeoutSec,
            "lockTimeoutSec": localLockTimeoutSec,
            "dpmsOffAfterLockSec": localDpmsOffAfterLockSec,
            "autoSuspendSec": localAutoSuspendSec,
            "dimOverlayOpacity": localDimOverlayOpacity,
            "dimBacklightPercent": localDimBacklightPercent,
            "respectIdleInhibitors": localRespectIdleInhibitors,
            "lockOnSuspend": localLockOnSuspend
        };
    }

    ColumnLayout {
        spacing: theme.dimensions.spacingMedium
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter

        SectionCard {
            title: qsTr("Lock Behavior")
            subtitle: qsTr("Manual lock is always available. Auto-lock stays off until the lock flow is verified live.")
            Layout.preferredWidth: 600
            Layout.alignment: Qt.AlignHCenter

            SettingSwitch {
                Layout.fillWidth: true
                label: qsTr("Enable lock screen")
                isChecked: page.localLockEnabled
                onIsCheckedChanged: page.localLockEnabled = isChecked
            }

            SettingSwitch {
                Layout.fillWidth: true
                label: qsTr("Auto-lock when idle")
                isChecked: page.localAutoLockEnabled
                onIsCheckedChanged: page.localAutoLockEnabled = isChecked
            }

            SettingSwitch {
                Layout.fillWidth: true
                label: qsTr("Lock on suspend")
                isChecked: page.localLockOnSuspend
                onIsCheckedChanged: page.localLockOnSuspend = isChecked
            }

            SettingSwitch {
                Layout.fillWidth: true
                label: qsTr("Respect idle inhibitors")
                tooltip: qsTr("Fullscreen video and media players can prevent idle actions.")
                isChecked: page.localRespectIdleInhibitors
                onIsCheckedChanged: page.localRespectIdleInhibitors = isChecked
            }
        }

        SectionCard {
            title: qsTr("Idle Timings")
            subtitle: qsTr("Values are seconds. 0 disables dim, DPMS-off, or auto-suspend; lock time is kept above dim time.")
            Layout.preferredWidth: 600
            Layout.alignment: Qt.AlignHCenter

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Dim after (seconds)")
                from: 0
                to: 1800
                stepSize: 30
                value: page.localDimTimeoutSec
                valueFormatter: page.formatDuration
                onEditingFinished: value => page.setDimTimeout(value)
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Lock after (seconds)")
                from: 30
                to: 7200
                stepSize: 30
                value: page.localLockTimeoutSec
                valueFormatter: page.formatDuration
                onEditingFinished: value => page.setLockTimeout(value)
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("DPMS off after lock (seconds)")
                from: 0
                to: 600
                stepSize: 10
                value: page.localDpmsOffAfterLockSec
                valueFormatter: page.formatDuration
                onEditingFinished: value => page.setDpmsTimeout(value)
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Auto-suspend after idle (seconds)")
                from: 0
                to: 7200
                stepSize: 60
                value: page.localAutoSuspendSec
                valueFormatter: page.formatDuration
                onEditingFinished: value => page.setAutoSuspend(value)
            }
        }

        SectionCard {
            title: qsTr("Dim Appearance")
            subtitle: qsTr("The overlay covers every screen; backlight dimming applies only to a detected panel.")
            Layout.preferredWidth: 600
            Layout.alignment: Qt.AlignHCenter

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Overlay opacity")
                from: 0
                to: 1
                stepSize: 0.05
                decimals: 2
                value: page.localDimOverlayOpacity
                valueFormatter: page.formatOpacity
                onEditingFinished: value => page.localDimOverlayOpacity = Math.min(1, Math.max(0, value))
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Backlight percent while dimmed")
                from: 1
                to: 100
                stepSize: 1
                value: page.localDimBacklightPercent
                valueFormatter: page.formatPercent
                onEditingFinished: value => page.setBacklightPercent(value)
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
