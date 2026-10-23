// windows/dock/DockItem.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

import "root:/themes"
import "root:/config"
import "root:/config/ConstValues.js" as Consts
import "root:/utils"
import "root:/services"
import "root:/components/app_launcher"

Item {
    id: itemRoot

    required property string appId
    required property var appData
    required property bool isRunning
    required property string windowAddress
    required property int instanceCount
    required property bool isPinnedToDock
    required property string tooltipText
    required property int iconSize
    required property var windows

    required property var panelWindow

    readonly property bool isFavorite: App.favoriteApps.indexOf(appId) !== -1
    readonly property var colors: ThemeManager.selectedTheme.colors
    readonly property var dims: ThemeManager.selectedTheme.dimensions
    readonly property var typo: ThemeManager.selectedTheme.typography

    width: iconSize + 16
    height: iconSize + 16

    readonly property bool hovered: mouseArea.containsMouse

    function closeContextMenu() {
        if (panelWindow) {
            panelWindow.anyMenuOpen = false;
            if (panelWindow.currentOpenPopup === contextMenu) {
                panelWindow.currentOpenPopup = null;
            }
        }
    }

    function launchOrFocus() {
        if (isRunning && windowAddress) {
            // NOTE: list form — {command:[...]} throws TypeError on QS 0.3.0.
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({window = "address:${windowAddress}"})`]);
        } else if (appData && typeof appData.execute === "function") {
            appData.execute();
        } else if (appId) {
            let cleanCmd = appId.endsWith(".desktop") ? appId.slice(0, -8) : appId;
            Qt.openUrlExternally("bin/" + cleanCmd);
        }
    }

    // NOTE: list form — {command:[...], workingDirectory} throws TypeError on
    // QS 0.3.0, so the working directory is folded into the sh -c script.
    function _cdPrefix(workDir) {
        if (!workDir)
            return "";
        return "cd '" + String(workDir).replace(/'/g, "'\\''") + "' && ";
    }

    // تشغيل التطبيق مع تجاهل اللوكال الحالي للنظام
    function launchWithDefaultLocale() {
        // نمرر اللوكال عبر sh -c prefix (مضمون على كل إصدارات Quickshell).
        // execDetached list form passes argv verbatim (no shell), hence sh -c.
        const envPrefix = "LANG=C.UTF-8 LC_ALL=C.UTF-8 ";
        console.info("[Locale][Dock.launchWithDefaultLocale] ==== appId=" + appId);
        if (appData) {
            console.info("[Locale][Dock] appData keys:", Object.keys(appData).join(", "));
            console.info("[Locale][Dock] execString:", JSON.stringify(appData.execString));
            console.info("[Locale][Dock] command:", JSON.stringify(appData.command));
            console.info("[Locale][Dock] workingDirectory:", JSON.stringify(appData.workingDirectory));
            console.info("[Locale][Dock] has execute fn:", typeof appData.execute === "function");
        }
        if (appData && appData.execString) {
            const finalCmd = envPrefix + appData.execString;
            console.info("[Locale][Dock] path=execString, final command:", JSON.stringify(finalCmd));
            Quickshell.execDetached(["sh", "-c", itemRoot._cdPrefix(appData.workingDirectory) + finalCmd]);
        } else if (appData && appData.command) {
            const finalCmd = envPrefix + appData.command;
            console.info("[Locale][Dock] path=command, final command:", JSON.stringify(finalCmd));
            Quickshell.execDetached(["sh", "-c", itemRoot._cdPrefix(appData.workingDirectory) + finalCmd]);
        } else if (appId) {
            let cleanCmd = appId.endsWith(".desktop") ? appId.slice(0, -8) : appId;
            const finalCmd = envPrefix + "bin/" + cleanCmd;
            console.info("[Locale][Dock] path=appId, final command:", JSON.stringify(finalCmd));
            Quickshell.execDetached(["sh", "-c", finalCmd]);
        } else {
            console.warn("[Locale][Dock] لا يوجد appData ولا appId - لا يمكن التشغيل");
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: itemRoot.dims.elementRadius * 0.8
        color: hovered ? itemRoot.colors.primary.alpha(0.12) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // --- أيقونة التطبيق (محدثة لتستدعي خدمة الأيقونات المركزية) ---
    IconImage {
        id: icon
        anchors.centerIn: parent
        width: iconSize
        height: iconSize

        source: {
            let trigger = IconService.iconUpdateTrigger;
            let iconKey = appData ? appData.icon : "application-x-executable";
            return IconService.getCached(iconKey);
        }

        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        id: activeDot
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: isRunning ? (hovered ? 12 : 5) : 0
        height: 5
        radius: 2.5
        color: itemRoot.colors.primary

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 16
        height: 16
        radius: 8
        color: itemRoot.colors.error
        visible: isRunning && instanceCount > 1

        Text {
            anchors.centerIn: parent
            text: instanceCount
            font.pixelSize: 10
            font.bold: true
            color: itemRoot.colors.onError
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onContainsMouseChanged: {
            if (containsMouse) {
                tooltipDelay.restart();
            } else {
                tooltipDelay.stop();
                if (!tooltipHoverHandler.hovered) {
                    hideTooltipTimer.restart();
                }
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                bounceAnim.restart();
                itemRoot.launchOrFocus();
            } else if (mouse.button === Qt.RightButton) {
                if (contextMenu.opened) {
                    contextMenu.close();
                    if (panelWindow) {
                        panelWindow.anyMenuOpen = false;
                        if (panelWindow.currentOpenPopup === contextMenu) {
                            panelWindow.currentOpenPopup = null;
                        }
                    }
                } else {
                    if (panelWindow.currentOpenPopup && panelWindow.currentOpenPopup !== contextMenu) {
                        panelWindow.currentOpenPopup.close();
                    }
                    contextMenu.open();
                }
            }
        }
    }

    Timer {
        id: tooltipDelay
        interval: 250
        onTriggered: {
            if (mouseArea.containsMouse && !contextMenu.opened) {
                tooltip.opacity = 1;
                if (panelWindow)
                    panelWindow.anyDockTooltipVisible = true;
            }
        }
    }

    Timer {
        id: hideTooltipTimer
        interval: 100
        onTriggered: {
            if (!mouseArea.containsMouse && !tooltipHoverHandler.hovered) {
                tooltip.opacity = 0;
                if (panelWindow)
                    panelWindow.anyDockTooltipVisible = false;
            }
        }
    }

    Rectangle {
        id: tooltip
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - 10
        width: instanceCount > 1 ? instanceListRow.width + 16 : tooltipLabel.implicitWidth + 16
        height: instanceCount > 1 ? instanceListRow.height + 12 : tooltipLabel.implicitHeight + 10
        radius: itemRoot.dims.elementRadius * 0.6
        color: itemRoot.colors.surfaceContainerHigh
        border.color: itemRoot.colors.outlineVariant
        border.width: 1
        opacity: 0
        visible: opacity > 0
        z: 100

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        HoverHandler {
            id: tooltipHoverHandler
            onHoveredChanged: {
                if (!hovered && !mouseArea.containsMouse) {
                    hideTooltipTimer.restart();
                }
            }
        }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            visible: instanceCount <= 1
            text: appData ? appData.name : appId
            font.pixelSize: 11
            color: itemRoot.colors.onSurface
        }

        Row {
            id: instanceListRow
            visible: instanceCount > 1
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: instanceCount > 1 ? windows : []
                delegate: Item {
                    width: 32
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: itemRoot.dims.elementRadius * 0.5
                        color: instanceMouse.containsMouse ? itemRoot.colors.primary.alpha(0.2) : itemRoot.colors.surfaceContainerHigh
                    }

                    // أيقونة النوافذ المنبثقة المتعددة
                    IconImage {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: {
                            let trigger = IconService.iconUpdateTrigger;
                            let iconKey = appData ? appData.icon : "application-x-executable";
                            return IconService.getCached(iconKey);
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 14
                        height: 11
                        radius: 3
                        color: itemRoot.colors.primary

                        Text {
                            anchors.centerIn: parent
                            text: (modelData && modelData.workspaceId >= 0) ? modelData.workspaceId : "?"
                            font.pixelSize: 8
                            font.bold: true
                            color: itemRoot.colors.onPrimary
                        }
                    }

                    MouseArea {
                        id: instanceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData && modelData.address) {
                                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({window = "address:${modelData.address}"})`]);
                            }
                            tooltip.opacity = 0;
                            tooltipDelay.stop();
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: contextMenu
        width: 200
        padding: 6
        closePolicy: Popup.CloseOnEscape

        y: -height - 8
        x: (parent.width / 2) - (width / 2)

        onOpened: {
            tooltip.opacity = 0;
            tooltipDelay.stop();
            hideTooltipTimer.stop();
            if (panelWindow) {
                panelWindow.anyDockTooltipVisible = false;
                panelWindow.anyMenuOpen = true;
                panelWindow.currentOpenPopup = contextMenu;
            }
        }

        onClosed: {
            if (panelWindow) {
                panelWindow.anyMenuOpen = false;
                if (panelWindow.currentOpenPopup === contextMenu) {
                    panelWindow.currentOpenPopup = null;
                }
            }
        }

        background: Rectangle {
            radius: itemRoot.dims.elementRadius
            color: itemRoot.colors.surfaceContainerHigh
            border.color: itemRoot.colors.primary.alpha(0.3)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 4
            focus: true
            Keys.onEscapePressed: contextMenu.close()

            ContextMenuItem {
                iconText: itemRoot.isRunning ? "󰇄" : "󰐊"
                label: itemRoot.isRunning ? qsTr("Focus") : qsTr("Open")
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    itemRoot.launchOrFocus();
                }
            }

            ContextMenuItem {
                iconText: "󰗊"
                label: qsTr("Open with C locale")
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    itemRoot.launchWithDefaultLocale();
                }
            }

            ContextMenuItem {
                iconText: "󰐕"
                label: qsTr("New Window")
                visible: itemRoot.isRunning
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    bounceAnim.restart();
                    if (itemRoot.appData && typeof itemRoot.appData.execute === "function") {
                        itemRoot.appData.execute();
                    }
                }
            }

            ContextMenuItem {
                iconText: "󰅙"
                label: qsTr("Close")
                visible: itemRoot.isRunning
                hoverColor: itemRoot.colors.error.alpha(0.15)
                iconColor: itemRoot.colors.error
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    if (itemRoot.windowAddress) {
                        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.window.close({window = "address:${itemRoot.windowAddress}"})`]);
                    }
                }
            }

            ContextMenuItem { showDivider: true }

            ContextMenuItem {
                iconText: "󰓎"
                label: itemRoot.isFavorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")
                isHighlighted: itemRoot.isFavorite
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    var favs = [...App.favoriteApps];
                    var idx = favs.indexOf(itemRoot.appId);
                    if (idx >= 0) {
                        favs.splice(idx, 1);
                    } else {
                        favs.push(itemRoot.appId);
                    }
                    App.favoriteApps = favs;
                    App.updateConfig("favoriteApps", App.favoriteApps);
                }
            }

            ContextMenuItem {
                iconText: "󰋜"
                label: itemRoot.isPinnedToDock ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
                isHighlighted: itemRoot.isPinnedToDock
                onClicked: {
                    contextMenu.close();
                    itemRoot.closeContextMenu();
                    var dockApps = [...App.dockApps];
                    var idx = dockApps.indexOf(itemRoot.appId);
                    if (idx >= 0) {
                        dockApps.splice(idx, 1);
                    } else {
                        dockApps.push(itemRoot.appId);
                    }
                    App.dockApps = dockApps;
                    App.updateConfig("dockApps", App.dockApps);
                }
            }
        }
    }

    SequentialAnimation {
        id: bounceAnim
        running: false

        PropertyAnimation {
            target: icon
            property: "scale"
            to: 0.85
            duration: 80
            easing.type: Easing.InOutQuad
        }
        PropertyAnimation {
            target: icon
            property: "scale"
            to: 1.15
            duration: 100
            easing.type: Easing.OutQuad
        }
        PropertyAnimation {
            target: icon
            property: "scale"
            to: 1.0
            duration: 80
            easing.type: Easing.OutQuad
        }
    }
}
