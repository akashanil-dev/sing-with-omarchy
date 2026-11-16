import QtQuick
import QtTest
import ".." as Sing

TestCase {
    id: tests
    name: "Reader"
    when: windowShown
    visible: true
    width: 440
    height: 650
    QtObject {
        id: fake
        property string songTitle: "A little room for music"
        property string artist: "Sing with Omarchy"
        property var player: null
        property var players: []
        property bool demo: true
        property real duration: 120
        property real position: 16
        property real offset: 0
        property bool synced: true
        property int activeIndex: 2
        property bool following: true
        property int fontSize: 18
        property int retrySeconds: 0
        property var result: ({state: "ready", source: "Preview"})
        property var lines: [{at: 0, text: "Let the day slow down"}, {at: 7, text: "There is a song in this room"}, {at: 14, text: "Keep the words close"}, {at: 21, text: "And find your own tune"}, {at: 28, text: "A quiet moment, just for you"}]
        function seek(value) { position = value; }
        function refresh() {}
    }
    Sing.Reader { id: reader; anchors.fill: parent; session: fake }
    SignalSpy { id: detachSpy; target: reader; signalName: "detachRequested" }
    function test_controls() {
        mouseClick(findChild(reader, "fontUp"));
        compare(fake.fontSize, 20);
        fake.fontSize = 18;
        fake.following = false;
        mouseClick(findChild(reader, "followButton"));
        compare(fake.following, true);
        mouseClick(findChild(reader, "detachButton"));
        compare(detachSpy.count, 1);
    }
    function test_follow_animation() {
        var list = findChild(reader, "verses");
        var motion = findChild(reader, "lyricScrollMotion");
        var original = fake.lines;
        fake.lines = Array.from({length: 30}, function(_, i) { return {at: i * 5, text: "Lyric number " + i}; });
        fake.activeIndex = 0;
        wait(450);
        var before = list.contentY;
        fake.activeIndex = 15;
        verify(motion.running);
        wait(180);
        verify(list.contentY > before);
        var middle = list.contentY;
        wait(300);
        verify(!motion.running);
        verify(list.contentY > middle);
        fake.following = false;
        var stopped = list.contentY;
        fake.activeIndex = 20;
        wait(100);
        compare(list.contentY, stopped);
        fake.lines = original;
        fake.activeIndex = 2;
        fake.following = true;
    }
    function test_render_and_states() {
        wait(250);
        verify(reader.width === 440);
        var shot = grabImage(reader);
        compare(shot.width, 440);
        shot.save("/tmp/sing-with-omarchy-preview.png");
        fake.result = {state: "error", message: "Connection unavailable"};
        fake.lines = [];
        wait(50);
        verify(reader.visible);
        tests.width = 360;
        tests.height = 430;
        wait(50);
        grabImage(reader).save("/tmp/sing-with-omarchy-small.png");
    }
}
