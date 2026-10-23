// animations/SlideFadeIn_Vertical.qml
import QtQuick

Transition {

    SequentialAnimation {
        PropertyAction {
            property: "opacity"
            value: 0
        }

        ParallelAnimation {
            NumberAnimation {
                property: "y"
                from: parent.height
                to: 0
                duration: 280
                easing.type: Easing.OutQuart
            }
            // اجعل العنصر يظهر تدريجيًا
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250
                easing.type: Easing.OutQuad
            }
        }
    }
}
