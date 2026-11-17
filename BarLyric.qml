import QtQuick

Item {
    id: root
    property string lyric: ""
    property color textColor: "white"
    property string fontFamily: "sans-serif"
    property int fontSize: 14
    property string shown: ""
    property string previous: ""
    property real phase: 1
    property real pan: 0
    readonly property real overflow: Math.max(0, current.implicitWidth - width)
    clip: true

    function changeLine() {
        transition.stop();
        marquee.stop();
        previous = shown;
        shown = lyric;
        pan = 0;
        phase = 0;
        transition.start();
    }
    onLyricChanged: changeLine()
    onWidthChanged: { marquee.stop(); pan = 0; if (overflow > 0) marquee.restart(); }
    NumberAnimation {
        id: transition
        target: root; property: "phase"; from: 0; to: 1
        duration: 560; easing.type: Easing.OutCubic
        onFinished: if (root.overflow > 0) marquee.restart()
    }
    SequentialAnimation {
        id: marquee
        loops: Animation.Infinite
        PauseAnimation { duration: 1200 }
        NumberAnimation { target: root; property: "pan"; to: root.overflow; duration: Math.max(1800, root.overflow * 28); easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1200 }
        NumberAnimation { target: root; property: "pan"; to: 0; duration: Math.max(1800, root.overflow * 28); easing.type: Easing.InOutSine }
    }
    Text {
        text: root.previous; textFormat: Text.PlainText
        x: Math.max(0, (root.width - implicitWidth) / 2)
        y: (root.height - height) / 2 - root.phase * root.height
        opacity: 1 - root.phase
        color: root.textColor; font.family: root.fontFamily; font.pixelSize: root.fontSize
    }
    Text {
        id: current
        text: root.shown; textFormat: Text.PlainText
        x: root.overflow > 0 ? -root.pan : (root.width - implicitWidth) / 2
        y: (root.height - height) / 2 + (1 - root.phase) * root.height
        opacity: root.phase
        color: root.textColor; font.family: root.fontFamily; font.pixelSize: root.fontSize
        font.weight: Font.Medium
    }
}
