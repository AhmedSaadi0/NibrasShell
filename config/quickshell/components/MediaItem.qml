import QtQuick
import QtQuick.Controls
import QtMultimedia

import "root:/services"

Item {
    id: mItem

    // --- Public API ---
    property string source: ""
    property bool active: false
    // "High": جودة كاملة، "Low": أداء عالي (دقة أقل)
    property string quality: "High"
    property bool muted: false
    // Lock surfaces set this so cached wallpapers are present on frame 1.
    property bool syncLoad: false

    // --- State & Getters ---
    readonly property bool isVideoType: _isVideo(source)

    property bool isReady: {
        if (!loader.item)
            return false;
        if (isVideoType) {
            return loader.item.playbackState === MediaPlayer.PlayingState || loader.item.mediaStatus === MediaPlayer.Buffered;
        }
        return loader.item.status === Image.Ready;
    }

    property bool isError: {
        if (!loader.item)
            return false;
        return isVideoType ? loader.item.error !== MediaPlayer.NoError : loader.item.status === Image.Error;
    }

    // --- Internal Helpers ---
    function _isVideo(path) {
        if (!path)
            return false;
        return /\.(mp4|mkv|webm|avi|mov|flv)$/i.test(path.toString());
    }

    function _resolvePath(path) {
        if (!path)
            return "";
        const str = path.toString();
        if (str.indexOf("://") === -1 && str.indexOf("/") === 0)
            return "file://" + str;
        return str;
    }

    // --- Main Loader ---
    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: !mItem.syncLoad
        sourceComponent: {
            if (!mItem.source)
                return undefined;
            return mItem.isVideoType ? videoComp : imageComp;
        }
    }

    // --- 1. Video Component (Fixed) ---
    Component {
        id: videoComp
        VideoOutput {
            id: vOut
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop

            // تم إزالة flushMode لأنه غير مدعوم في Qt 6
            // بدلاً منه نستخدم Layering لتحسين الأداء في وضع Low:
            // عند تفعيله، يتم رسم الفيديو في ذاكرة مؤقتة بحجم أصغر، ثم تكبيره.
            // هذا يقلل الحمل على GPU بنسبة تصل لـ 75%
            layer.enabled: mItem.quality === "Low"

            // نجعل دقة الرسم نصف حجم العنصر
            layer.textureSize: mItem.quality === "Low" ? Qt.size(width / 2, height / 2) : Qt.size(0, 0)

            // نلغي التنعيم في وضع Low لكسب المزيد من الأداء
            layer.smooth: mItem.quality === "High"

            MediaPlayer {
                id: player
                videoOutput: vOut
                audioOutput: AudioOutput { id: audioOut; volume: mItem.muted ? 0 : 1 }
                source: mItem.source ? Qt.resolvedUrl(mItem._resolvePath(mItem.source)) : ""
                loops: MediaPlayer.Infinite

                // تشغيل فقط إذا كان العنصر نشطاً ومرئياً
                // property bool shouldPlay: MusicService.isPlaying && mItem.active && mItem.visible
                property bool shouldPlay: mItem.active && mItem.visible
                onShouldPlayChanged: shouldPlay ? play() : pause()

                // onSourceChanged: {
                //     pauseTimer.stop();
                //     play();
                //     pauseTimer.start();
                // }

                Component.onCompleted: if (shouldPlay)
                    play()
            }
            Timer {
                id: pauseTimer
                repeat: false
                interval: 400
                onTriggered: {
                    player.pause();
                }
            }
        }
    }

    // --- 2. Image/GIF Component ---
    Component {
        id: imageComp
        AnimatedImage {
            id: img
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: !mItem.syncLoad
            cache: true

            source: mItem.source
            playing: mItem.active && mItem.visible
            paused: !playing

            // في وضع Low: نحمل الصورة بنصف الحجم الأصلي
            sourceSize: mItem.quality === "Low" ? Qt.size(parent.width / 2, parent.height / 2) : undefined

            // في وضع Low: نلغي التنعيم
            smooth: mItem.quality === "High"
            mipmap: mItem.quality === "High"
        }
    }
}
