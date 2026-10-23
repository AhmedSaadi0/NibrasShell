// animations/SlideFadeIn_Vertical_FromTop.qml
import QtQuick

Transition {

    SequentialAnimation {
        PropertyAction {
            property: "opacity"
            value: 0
        }
        PropertyAction {
            property: "y"
            value: -parent.height / 3
        }

        // ثانيًا، قم بتشغيل الأنيميشن لإظهاره
        ParallelAnimation {
            // 1. حرك العنصر من الأعلى إلى مكانه الأصلي (y=0)
            NumberAnimation {
                property: "y"
                from: -parent.height / 3
                to: 0
                duration: 280
                easing.type: Easing.OutQuart
            }
            // 2. اجعل العنصر يظهر تدريجيًا أثناء حركته
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 280
                easing.type: Easing.OutQuad
            }
        }
    }
}
