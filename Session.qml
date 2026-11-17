import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import "Timeline.js" as Timeline
import "Protocol.js" as Protocol

Item {
    id: session
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""
    property string helperPath: decodeURIComponent(Qt.resolvedUrl("backend/lyrics.py").toString().replace(/^file:\/\//, ""))
    readonly property string supervisorPath: decodeURIComponent(Qt.resolvedUrl("backend/worker.py").toString().replace(/^file:\/\//, ""))
    property bool demo: false
    property var players: Mpris.players.values
    property string preferredPlayer: ""
    readonly property var player: Timeline.choosePlayer(players, preferredPlayer)
    readonly property string songTitle: demo ? "A little room for music" : (player ? player.trackTitle : "Nothing playing yet")
    readonly property string artist: demo ? "Sing with Omarchy" : (player ? player.trackArtist : "Open your music player to begin")
    readonly property real duration: demo ? 120 : (player && player.lengthSupported ? player.length : 0)
    readonly property string trackKey: demo ? "demo" : JSON.stringify(player ? [player.dbusName, player.metadata["mpris:trackid"], player.trackTitle, player.trackArtist, player.trackAlbum, duration] : [])
    property real position: 0
    property real offset: 0
    property int fontSize: 18
    property bool following: true
    property var result: ({state: "idle", lines: [], synced: false})
    readonly property var lines: result.lines || []
    readonly property bool synced: !!result.synced
    readonly property int activeIndex: synced ? Timeline.activeCue(lines, position + offset) : -1
    property var cache: ({})
    property var cacheOrder: []
    property string jobKey: ""
    property string requestedKey: ""
    property bool jobActive: false
    property string jobInput: ""
    property int requestGeneration: 0
    property int jobGeneration: 0
    property double retryAt: 0
    property double retrySeconds: 0
    property var views: []
    readonly property bool panelOpen: views.some(view => view.readerVisible)

    function attachView(view) {
        if (views.indexOf(view) < 0) views = views.concat([view]);
    }
    function detachView(view) { views = views.filter(item => item !== view); }
    function hideReaders() { views.slice().forEach(view => view.dismissReaders()); }
    function showReader(screenName, floating) {
        var chosen = views.find(view => view.screenName === screenName) || views[0];
        if (!chosen) return false;
        // Close other readers before opening so host popup coordination cannot undo the selection.
        views.filter(view => view !== chosen).forEach(view => view.dismissReaders());
        if (floating) chosen.presentDetached();
        else chosen.presentReader();
        return true;
    }
    function focusedScreen() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""; }

    IpcHandler {
        target: "akash.sing-with-omarchy"
        function show(): string { return session.showReader(session.focusedScreen()) ? "ok" : "unavailable"; }
        function open(): string { return show(); }
        function popout(): string { return session.showReader(session.focusedScreen(), true) ? "ok" : "unavailable"; }
        function hide(): string { session.hideReaders(); return "ok"; }
        function close(): string { return hide(); }
        function toggle(): string {
            if (session.panelOpen) { session.hideReaders(); return "ok"; }
            return show();
        }
        function status(): string { return JSON.stringify({open: session.panelOpen, views: session.views.length, state: session.result.state, centerLyrics: session.views.some(view => view.centerLyricsEnabled), centerLyricsActive: session.views.some(view => view.centerLyricsActive)}); }
        function centerLyrics(enabled: bool): string {
            var view = session.views[0];
            return view && view.setCenterLyrics(enabled) ? "ok" : "unavailable";
        }
        function refresh(): string { session.refresh(); return "ok"; }
    }

    function refresh() {
        if (demo) {
            result = {state: "ready", synced: true, source: "Preview", lines: [
                {at: 0, text: "Let the day slow down"}, {at: 7, text: "There is a song in this room"},
                {at: 14, text: "Keep the words close"}, {at: 21, text: "And find your own tune"},
                {at: 28, text: "A quiet moment, just for you"}, {at: 35, text: "Sing it all the way through"}]};
            position = 16;
            return;
        }
        if (!player || retrySeconds > 0) return;
        requestGeneration++;
        delete cache[trackKey];
        requestedKey = trackKey;
        result = {state: "loading", lines: []};
        launchDelay.restart();
    }

    function changedTrack() {
        requestGeneration++;
        offset = 0;
        following = true;
        position = 0;
        requestedKey = "";
        if (demo) { refresh(); return; }
        if (!player) { result = {state: "idle", lines: []}; return; }
        if (cache[trackKey]) { result = cache[trackKey]; return; }
        if (retrySeconds > 0) {
            result = {state: "error", lines: [], message: "Provider is busy. Try again after the countdown."};
            return;
        }
        refresh();
    }

    function startLookup() {
        if (jobActive || !requestedKey || !player || demo) return;
        if (retryAt > Date.now()) {
            requestedKey = "";
            result = {state: "error", lines: [], message: "Provider is busy. Try again after the countdown."};
            return;
        }
        try { jobInput = Protocol.trackInput(player, duration); }
        catch (error) {
            requestedKey = "";
            result = {state: "error", lines: [], message: "The player supplied invalid or oversized track metadata."};
            return;
        }
        jobKey = requestedKey;
        jobGeneration = requestGeneration;
        requestedKey = "";
        worker.command = ["/usr/bin/python3", supervisorPath, helperPath];
        jobActive = true;
        worker.running = true;
        deadline.restart();
    }

    function acceptOutput(text) {
        try {
            const answer = Protocol.response(text);
            if (answer.retryAfter) retryAt = Date.now() + answer.retryAfter * 1000;
            if (jobKey !== trackKey || jobGeneration !== requestGeneration) return;
            result = answer;
            if (answer.state === "ready" || answer.state === "instrumental") {
                cache[jobKey] = answer;
                cacheOrder = cacheOrder.filter(key => key !== jobKey).concat([jobKey]);
                if (cacheOrder.length > 20) delete cache[cacheOrder.shift()];
            }
        } catch (error) {
            if (jobKey === trackKey && jobGeneration === requestGeneration) result = {state: "error", lines: [], message: "The lyrics helper returned an invalid response."};
        }
    }

    function seek(seconds) {
        if (demo) { position = seconds; return; }
        if (player && player.canSeek && player.positionSupported) player.position = Math.max(0, seconds - offset);
    }

    onTrackKeyChanged: changedTrack()
    Component.onCompleted: changedTrack()
    Timer { id: launchDelay; interval: 350; onTriggered: session.startLookup() }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            session.retrySeconds = Math.max(0, Math.ceil((session.retryAt - Date.now()) / 1000));
            if (!session.demo) session.position = session.player && session.player.positionSupported ? session.player.position : 0;
        }
    }
    Timer {
        id: deadline; interval: 25000
        onTriggered: {
            worker.running = false;
            session.jobActive = false;
            if (session.jobKey === session.trackKey && session.jobGeneration === session.requestGeneration)
                session.result = {state: "error", lines: [], message: "The request timed out. Try again."};
        }
    }
    Process {
        id: worker
        stdinEnabled: true
        onStarted: { write(session.jobInput + "\n"); session.jobInput = ""; }
        stdout: StdioCollector { onStreamFinished: session.acceptOutput(text) }
        onExited: (exitCode, exitStatus) => {
            deadline.stop();
            session.jobActive = false;
            if (session.jobKey === session.trackKey && session.jobGeneration === session.requestGeneration && session.result.state === "loading")
                session.result = {state: "error", lines: [], message: "The lyrics helper could not finish. Try again."};
            if (session.requestedKey) launchDelay.restart();
        }
    }
}
