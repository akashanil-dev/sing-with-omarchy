pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Timeline.js" as Timeline

Rectangle {
    id: reader
    required property var session
    property bool detached: false
    signal detachRequested()
    signal dismissRequested()
    signal moveRequested()
    color: "#111115"
    radius: detached ? 0 : 16
    implicitWidth: 420
    implicitHeight: 570

    function followCue() {
        if (!session || !session.following) return;
        if (session.activeIndex >= 0) verses.positionViewAtIndex(session.activeIndex, ListView.Center);
        else verses.positionViewAtBeginning();
    }

    Connections {
        target: reader.session
        function onActiveIndexChanged() { reader.followCue(); }
        function onFollowingChanged() { reader.followCue(); }
        function onResultChanged() { Qt.callLater(reader.followCue); }
    }
    Component.onCompleted: Qt.callLater(followCue)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "♫"
                font.pixelSize: 26
                color: "#eac184"
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                text: "SING WITH OMARCHY"
                font.pixelSize: 10
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                color: "#aaa6a0"
                MouseArea {
                    anchors.fill: parent
                    enabled: reader.detached
                    cursorShape: Qt.SizeAllCursor
                    onPressed: reader.moveRequested()
                }
            }
            LyricButton {
                objectName: "detachButton"
                visible: !reader.detached
                text: "↗"
                hint: "Open a separate lyrics window"
                onClicked: reader.detachRequested()
            }
            LyricButton { text: "×"; hint: "Close lyrics"; onClicked: reader.dismissRequested() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: reader.session ? reader.session.songTitle : "Starting…"
                textFormat: Text.PlainText
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: "#f1eeea"
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: reader.session ? reader.session.artist : ""
                textFormat: Text.PlainText
                font.pixelSize: 13
                color: "#a9a6af"
                elide: Text.ElideRight
            }
        }
        ComboBox {
            id: playerPicker
            visible: count > 1
            Layout.fillWidth: true
            model: reader.session ? reader.session.players : []
            textRole: "identity"
            currentIndex: reader.session ? model.indexOf(reader.session.player) : -1
            Accessible.name: "Music player"
            onActivated: index => reader.session.preferredPlayer = model[index].dbusName
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#2c2a30" }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            ListView {
                id: verses
                anchors.fill: parent
                clip: true
                spacing: 16
                model: reader.session ? reader.session.lines : []
                boundsBehavior: Flickable.StopAtBounds
                topMargin: 28
                bottomMargin: 32
                onMovementStarted: if (reader.session) reader.session.following = false
                WheelHandler {
                    target: null
                    onWheel: event => {
                        if (reader.session) reader.session.following = false;
                        event.accepted = false;
                    }
                }
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: verse
                    required property var modelData
                    required property int index
                    readonly property bool active: reader.session && reader.session.activeIndex === index
                    width: verses.width - 14
                    height: words.implicitHeight + 16
                    Rectangle {
                        visible: verse.active
                        width: 3; radius: 1.5
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: "#eac184"
                    }
                    Text {
                        id: words
                        x: 15; width: parent.width - 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: verse.modelData.text || "· · ·"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.pixelSize: reader.session ? reader.session.fontSize : 24
                        font.weight: verse.active ? Font.DemiBold : Font.Normal
                        color: verse.active ? "#f3d3a1" : !reader.session.synced ? "#c9c5cc" : "#85818d"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: reader.session && reader.session.synced && (reader.session.demo || (reader.session.player && reader.session.player.canSeek && reader.session.player.positionSupported))
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            reader.session.seek(verse.modelData.at);
                            reader.session.following = true;
                        }
                    }
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.text
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 16
                visible: !reader.session || reader.session.lines.length === 0
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: reader.session && reader.session.result.state === "loading" ? "Finding the words…" : reader.session && reader.session.result.state === "instrumental" ? "Let the music speak." : reader.session && reader.session.result.state === "idle" ? "Your next song starts here." : "No words just yet."
                    wrapMode: Text.Wrap
                    font.pixelSize: 24
                    color: "#eac184"
                }
                Text {
                    width: parent.width
                    text: reader.session ? reader.session.result.message || (reader.session.result.state === "instrumental" ? "This recording is marked as instrumental." : reader.session.result.state === "idle" ? "Play a song in an MPRIS-compatible player." : "") : "Connecting to the lyrics session."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    color: "#aaa6b1"
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: reader.session && reader.session.result.state === "ready" ? (reader.session.synced ? "SYNCED" : "PLAIN LYRICS") + "  ·  " + reader.session.result.source : ""
                color: "#96919b"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Text {
                text: reader.session ? Timeline.clock(reader.session.position) + " / " + Timeline.clock(reader.session.duration) : ""
                color: "#aaa6b1"
                font.pixelSize: 11
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: "#302d33"
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * (reader.session && reader.session.duration > 0 ? Math.min(1, reader.session.position / reader.session.duration) : 0)
                color: "#eac184"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            LyricButton {
                text: "A−"; hint: "Smaller lyrics"
                enabled: reader.session && reader.session.fontSize > 16
                onClicked: reader.session.fontSize -= 2
            }
            LyricButton {
                objectName: "fontUp"
                text: "A+"; hint: "Larger lyrics"
                enabled: reader.session && reader.session.fontSize < 40
                onClicked: reader.session.fontSize += 2
            }
            Item { Layout.fillWidth: true }
            LyricButton {
                objectName: "followButton"
                text: reader.session && reader.session.following ? "Following" : "Follow"
                highlightedAction: reader.session && reader.session.following
                enabled: reader.session && reader.session.synced
                hint: "Follow the current lyric"
                onClicked: { reader.session.following = true; reader.followCue(); }
            }
            LyricButton {
                text: reader.session && reader.session.retrySeconds > 0 ? reader.session.retrySeconds + "s" : "↻"
                hint: "Look up lyrics again"
                enabled: reader.session && (reader.session.player || reader.session.demo) && reader.session.result.state !== "loading" && reader.session.retrySeconds === 0
                onClicked: reader.session.refresh()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: reader.session && reader.session.synced
            spacing: 8
            Text { text: "Timing"; color: "#96919b"; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            LyricButton {
                text: "−"; hint: "Show lyrics half a second later"
                enabled: reader.session && reader.session.offset > -10
                onClicked: reader.session.offset -= .5
            }
            Text {
                text: reader.session ? (reader.session.offset > 0 ? "+" : "") + reader.session.offset.toFixed(1) + "s" : "0.0s"
                color: "#c5c0c9"; font.pixelSize: 12
                Layout.minimumWidth: 35
                horizontalAlignment: Text.AlignHCenter
            }
            LyricButton {
                text: "+"; hint: "Show lyrics half a second sooner"
                enabled: reader.session && reader.session.offset < 10
                onClicked: reader.session.offset += .5
            }
        }
    }
    Keys.onEscapePressed: dismissRequested()
}
