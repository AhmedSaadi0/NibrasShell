// windows/leftwindow/base/BaseMenuView.qml

import QtQuick
import QtQuick.Layouts
import "root:/themes"
import "root:/components"

Item {
    id: root

    // ─── خصائص عامة ──────────────────────────────────────────────
    property string menuTitle: ""
    property string menuIcon: ""
    property bool showPrimaryAction: false
    property string primaryActionIcon: "󰅗"
    property var menuActions: []

    default property alias pageContent: innerContent.data

    readonly property int sidePadding: ThemeManager.selectedTheme.dimensions.menuWidgetsMargin
    readonly property int topAppBarHeight: 64
    property alias headerContent: headerContainer.data

    // The vertical scroller of the menu body. Exposed so child views can
    // scroll a specific item into view.
    readonly property alias contentFlickable: scrollArea

    signal primaryActionTriggered
    signal menuActionTriggered(int index, var action)

    // ─── TopAppBar ثابت في الأعلى ────────────────────────────────
    TopAppBar {
        id: appBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10  // فوق كل شيء

        title: root.menuTitle
        icon: root.menuIcon
        scrollY: scrollArea.contentY
        actions: root.menuActions
        primaryActionVisible: root.showPrimaryAction
        primaryActionIcon: root.primaryActionIcon

        onPrimaryActionTriggered: root.primaryActionTriggered()
        onActionTriggered: (index, action) => root.menuActionTriggered(index, action)
    }

    Column {
        id: headerContainer
        anchors.top: appBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: children.length > 0
        spacing: 0
        z: 9
    }

    Rectangle {
        id: appBarShadow
        anchors.top: headerContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 12
        z: 9

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: ThemeManager.selectedTheme.colors.surface.alpha(Math.min(scrollArea.contentY / 30.0, 1.0) * 0.05)
            }
            GradientStop {
                position: 0.4
                color: "transparent"
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // ─── Flickable يبدأ من تحت TopAppBar ─────────────────────────
    Flickable {
        id: scrollArea
        // anchors.top: appBar.bottom
        // anchors.top: headerContainer.visible ? headerContainer.bottom : appBar.bottom
        anchors.top: headerContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        // contentHeight: Math.max(height, innerContent.implicitHeight)
        contentHeight: innerContent.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: innerContent
            width: scrollArea.width
            // height: Math.max(implicitHeight, scrollArea.height)
            spacing: 0
        }
    }
}
