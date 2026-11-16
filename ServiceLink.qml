import QtQuick

Item {
    id: link
    property var host: null
    property var fallbackHost: null
    property var service: null
    property string pluginId: "akash.sing-with-omarchy"
    property int misses: 0
    property bool warned: false
    function resolve() {
        var found = null;
        for (var candidate of [host, fallbackHost]) {
            if (candidate && typeof candidate.serviceFor === "function") {
                found = candidate.serviceFor(pluginId);
                if (found) break;
            }
        }
        service = found || null;
        if (service) { misses = 0; warned = false; }
        else if (++misses >= 60 && !warned) {
            warned = true;
            console.warn("Sing with Omarchy: waiting for the lyrics service. This bar may not expose plugin services.");
        }
    }
    onHostChanged: resolve()
    onFallbackHostChanged: resolve()
    Component.onCompleted: resolve()
    Timer { interval: 500; running: true; repeat: true; onTriggered: link.resolve() }
}
