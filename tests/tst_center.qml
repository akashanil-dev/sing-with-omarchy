import QtQuick
import QtTest
import ".." as Sing

TestCase {
    id: test
    name: "CenterLyrics"
    when: windowShown
    width: 1000; height: 40
    visible: true
    Item {
        id: surface
        anchors.fill: parent
        Item {
            id: middle
            anchors.fill: parent
            property bool hasAnchor: true
            property var anchorEntry: ({id: "clock"})
            property var entries: [{id: "clock"}]
        }
        Item { id: leftSide; property string region: "left"; width: 150; height: 40 }
        Item { id: rightSide; property string region: "right"; x: 750; width: 250; height: 40 }
    }
    Sing.CenterLyrics { id: overlay; surface: surface; lyric: "A line in the middle" }
    Sing.BarLyric { id: line; width: 180; height: 30 }
    function test_reversible_layout() {
        overlay.locate();
        overlay.requested = true;
        verify(overlay.active);
        compare(middle.opacity, 0);
        compare(middle.enabled, false);
        compare(overlay.availableWidth, 476);
        overlay.lyric = "";
        compare(middle.opacity, 1);
        compare(middle.enabled, true);
        overlay.lyric = "Next line";
        verify(overlay.active);
        rightSide.x = 490;
        verify(!overlay.active);
        compare(middle.opacity, 1);
        rightSide.x = 750;
        overlay.requested = false;
        compare(middle.opacity, 1);
        compare(middle.enabled, true);
    }
    function test_animation_and_overflow() {
        line.lyric = "Short";
        wait(600);
        compare(line.shown, "Short");
        compare(line.overflow, 0);
        line.lyric = "A very long lyric line that should scroll rather than get cut off";
        wait(180);
        verify(line.phase > 0 && line.phase < 1);
        compare(line.previous, "Short");
        wait(450);
        verify(line.overflow > 0);
        wait(1500);
        verify(line.pan > 0);
        line.lyric = "Next";
        compare(line.pan, 0);
    }
}
