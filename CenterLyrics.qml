import QtQuick

// The scoped bar API does not expose center visibility. Discover this monitor's
// visual section, then use reversible bindings; never rewrite another widget's
// settings or unload its service. Fail closed if the host layout is unfamiliar.
Item {
    id: root
    property var surface: null
    property bool requested: false
    property string lyric: ""
    property var theme: null
    property var center: null
    property var leftSection: null
    property var rightSection: null
    readonly property real sideExtent: center ? Math.max(leftSection ? leftSection.x + leftSection.width : 0, rightSection ? center.parent.width - rightSection.x : 0) + 12 : 0
    readonly property real availableWidth: center ? Math.max(0, center.parent.width - 2 * sideExtent) : 0
    readonly property bool active: requested && lyric.length > 0 && center !== null && leftSection !== null && rightSection !== null && availableWidth >= 100
    signal clicked()

    function discover(item, depth) {
        if (!item || item === root || depth > 16) return null;
        if ("hasAnchor" in item && "anchorEntry" in item && "entries" in item) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; ++i) {
            var found = discover(children[i], depth + 1);
            if (found) return found;
        }
        return null;
    }
    function locate() {
        var found = discover(surface, 0);
        var nextLeft = null, nextRight = null;
        if (found && found.parent) {
            var siblings = found.parent.children;
            for (var i = 0; i < siblings.length; ++i) {
                if (siblings[i].region === "left") nextLeft = siblings[i];
                if (siblings[i].region === "right") nextRight = siblings[i];
            }
        }
        // Do not clear references on each probe: doing so would restart the
        // lyric animation and briefly restore the old widgets every 1.5s.
        center = found;
        leftSection = nextLeft;
        rightSection = nextRight;
    }
    onSurfaceChanged: Qt.callLater(locate)
    Component.onCompleted: Qt.callLater(locate)
    Timer { interval: 1500; running: root.requested; repeat: true; onTriggered: root.locate() }
    Binding { target: root.center; property: "opacity"; value: 0; when: root.active; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: root.center; property: "enabled"; value: false; when: root.active; restoreMode: Binding.RestoreBindingOrValue }
    Item {
        parent: root.center ? root.center.parent : root
        visible: root.active
        z: 10
        x: root.sideExtent
        width: root.availableWidth
        height: root.center ? root.center.height : 0
        BarLyric {
            anchors.fill: parent
            lyric: root.active ? root.lyric : ""
            textColor: root.theme ? root.theme.foreground : "white"
            fontFamily: root.theme ? root.theme.fontFamily : "sans-serif"
            fontSize: root.theme ? root.theme.bodySize : 14
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    }
}
