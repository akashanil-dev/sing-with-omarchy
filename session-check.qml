import QtQuick
import Quickshell
import "." as Sing

ShellRoot {
    Sing.Session { id: session; players: []; demo: false }
    QtObject {
        id: left
        property string screenName: "left"
        property bool readerVisible: false
        function presentReader() { readerVisible = true; }
        function dismissReaders() { readerVisible = false; }
    }
    QtObject {
        id: right
        property string screenName: "right"
        property bool readerVisible: false
        function presentReader() { readerVisible = true; }
        function dismissReaders() { readerVisible = false; }
    }
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        interval: 50; running: true
        onTriggered: {
            session.result = {state: "idle", lines: []};
            session.jobKey = "old recording";
            session.acceptOutput(JSON.stringify({state: "ready", lines: [{at: 0, text: "Stale"}], synced: true}));
            check(session.result.state === "idle", "discard stale result");
            session.jobKey = session.trackKey;
            session.jobGeneration = session.requestGeneration;
            session.acceptOutput("not JSON");
            check(session.result.state === "error", "invalid response recovery");
            session.jobKey = "old recording";
            session.acceptOutput(JSON.stringify({state: "error", lines: [], retryAfter: 300}));
            check(session.retryAt > Date.now() + 290000, "respect stale rate limit response");
            session.demo = true;
            session.refresh();
            check(session.activeIndex === 2, "preview cue");
            session.seek(7);
            check(session.activeIndex === 1, "seek backward");
            session.seek(0);
            check(session.activeIndex === 0, "seek to start");
            session.attachView(left);
            session.attachView(right);
            session.attachView(left);
            check(session.views.length === 2, "no duplicate view registration");
            session.showReader("right");
            check(right.readerVisible && !left.readerVisible && session.panelOpen, "focused monitor opens alone");
            session.showReader("left");
            check(left.readerVisible && !right.readerVisible && session.panelOpen, "switch monitor preserves open state");
            session.hideReaders();
            check(!session.panelOpen, "hide closes every reader");
            session.detachView(left);
            session.showReader("missing");
            check(right.readerVisible, "missing monitor falls back to available reader");
            session.detachView(right);
            check(!session.panelOpen && !session.showReader("left"), "unregistered views are not used");
            console.log("PASS: 12 session checks");
            Qt.quit();
        }
    }
}
