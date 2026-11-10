import QtQuick
import Quickshell
import "." as Sing

ShellRoot {
    Sing.Session { id: session; players: []; demo: false }
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
            console.log("PASS: 6 session checks");
            Qt.quit();
        }
    }
}
