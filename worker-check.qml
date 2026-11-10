import QtQuick
import Quickshell
import "." as Sing

ShellRoot {
    id: test
    property bool switched: false
    Sing.Session {
        id: session
        players: []
        helperPath: decodeURIComponent(Qt.resolvedUrl("tests/provider_fixture.py").toString().replace(/^file:\/\//, ""))
        onJobActiveChanged: {
            if (jobActive && !test.switched) {
                test.switched = true;
                Qt.callLater(() => { session.players = [test.track("Second song")]; });
            }
        }
        onResultChanged: {
            if (result.state === "ready") {
                if (result.lines[0].text !== "Second song") { console.error("FAIL: stale subprocess result"); Qt.exit(1); }
                else { console.log("PASS: subprocess lookup and track-switch race"); Qt.quit(); }
            }
        }
    }
    function track(title) {
        return {dbusName: "test", metadata: {"mpris:trackid": title}, trackTitle: title,
                trackArtist: "Test artist", trackAlbum: "", lengthSupported: true, length: 100,
                isPlaying: true, positionSupported: true, position: 10};
    }
    Timer { interval: 50; running: true; onTriggered: session.players = [test.track("First song")] }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: worker timed out"); Qt.exit(1); } }
}
