pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Timeline.js" as Timeline

Rectangle {
    id: reader
    required property var session
    property var theme: fallbackTheme
    Theme { id: fallbackTheme }
    property bool detached: false
    signal detachRequested()
    signal dismissRequested()
    signal moveRequested()
    color: theme.background
    radius: detached ? 0 : theme.cornerRadius
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
                font.family: reader.theme.fontFamily
                font.pixelSize: 26
                color: reader.theme.accent
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                text: "SING WITH OMARCHY"
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.captionSize
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                color: reader.theme.muted
                MouseArea {
                    anchors.fill: parent
                    enabled: reader.detached
                    cursorShape: Qt.SizeAllCursor
                    onPressed: reader.moveRequested()
                }
            }
            LyricButton {
                theme: reader.theme
                objectName: "detachButton"
                visible: !reader.detached
                text: "↗"
                hint: "Open a separate lyrics window"
                onClicked: reader.detachRequested()
            }
            LyricButton {
                theme: reader.theme; text: "×"; hint: "Close lyrics"; onClicked: reader.dismissRequested() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: reader.session ? reader.session.songTitle : "Starting…"
                textFormat: Text.PlainText
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.titleSize
                font.weight: Font.DemiBold
                color: reader.theme.foreground
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: reader.session ? reader.session.artist : ""
                textFormat: Text.PlainText
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.bodySize
                color: reader.theme.muted
                elide: Text.ElideRight
            }
        }
        ComboBox {
            id: playerPicker
            visible: count > 1
            Layout.fillWidth: true
            model: reader.session ? reader.session.players : []
            palette.base: reader.theme.button
            palette.button: reader.theme.button
            palette.text: reader.theme.foreground
            palette.buttonText: reader.theme.foreground
            palette.highlight: reader.theme.accent
            palette.highlightedText: reader.theme.onAccent
            font.family: reader.theme.fontFamily
            font.pixelSize: reader.theme.bodySize
            textRole: "identity"
            currentIndex: reader.session ? model.indexOf(reader.session.player) : -1
            Accessible.name: "Music player"
            onActivated: index => reader.session.preferredPlayer = model[index].dbusName
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: reader.theme.border }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            ListView {
                id: verses
                anchors.fill: parent
                clip: true
                spacing: 10
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
                    height: words.implicitHeight + 10
                    Rectangle {
                        visible: verse.active
                        width: 3; radius: 1.5
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: reader.theme.accent
                    }
                    Text {
                        id: words
                        x: 15; width: parent.width - 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: verse.modelData.text || "· · ·"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.family: reader.theme.fontFamily
                        font.pixelSize: reader.session ? reader.session.fontSize : 18
                        font.weight: verse.active ? Font.DemiBold : Font.Normal
                        color: verse.active ? reader.theme.accent : !reader.session.synced ? reader.theme.foreground : reader.theme.muted
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
                    font.family: reader.theme.fontFamily
                    font.pixelSize: 24
                    color: reader.theme.accent
                }
                Text {
                    width: parent.width
                    text: reader.session ? reader.session.result.message || (reader.session.result.state === "instrumental" ? "This recording is marked as instrumental." : reader.session.result.state === "idle" ? "Play a song in an MPRIS-compatible player." : "") : "Connecting to the lyrics session."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    font.family: reader.theme.fontFamily
                    font.pixelSize: reader.theme.bodySize
                    color: reader.theme.muted
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: reader.session && reader.session.result.state === "ready" ? (reader.session.synced ? "SYNCED" : "PLAIN LYRICS") + "  ·  " + reader.session.result.source : ""
                color: reader.theme.muted
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.captionSize
                elide: Text.ElideRight
            }
            Text {
                text: reader.session ? Timeline.clock(reader.session.position) + " / " + Timeline.clock(reader.session.duration) : ""
                color: reader.theme.muted
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.captionSize
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: reader.theme.border
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * (reader.session && reader.session.duration > 0 ? Math.min(1, reader.session.position / reader.session.duration) : 0)
                color: reader.theme.accent
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            LyricButton {
                theme: reader.theme
                text: "A−"; hint: "Smaller lyrics"
                enabled: reader.session && reader.session.fontSize > 14
                onClicked: reader.session.fontSize -= 2
            }
            LyricButton {
                theme: reader.theme
                objectName: "fontUp"
                text: "A+"; hint: "Larger lyrics"
                enabled: reader.session && reader.session.fontSize < 40
                onClicked: reader.session.fontSize += 2
            }
            Item { Layout.fillWidth: true }
            LyricButton {
                theme: reader.theme
                objectName: "followButton"
                text: reader.session && reader.session.following ? "Following" : "Follow"
                highlightedAction: reader.session && reader.session.following
                enabled: reader.session && reader.session.synced
                hint: "Follow the current lyric"
                onClicked: { reader.session.following = true; reader.followCue(); }
            }
            LyricButton {
                theme: reader.theme
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
            Text { text: "Timing"; color: reader.theme.muted; font.family: reader.theme.fontFamily; font.pixelSize: reader.theme.captionSize }
            Item { Layout.fillWidth: true }
            LyricButton {
                theme: reader.theme
                text: "−"; hint: "Show lyrics half a second later"
                enabled: reader.session && reader.session.offset > -10
                onClicked: reader.session.offset -= .5
            }
            Text {
                text: reader.session ? (reader.session.offset > 0 ? "+" : "") + reader.session.offset.toFixed(1) + "s" : "0.0s"
                font.family: reader.theme.fontFamily
                color: reader.theme.foreground; font.pixelSize: reader.theme.bodySize
                Layout.minimumWidth: 35
                horizontalAlignment: Text.AlignHCenter
            }
            LyricButton {
                theme: reader.theme
                text: "+"; hint: "Show lyrics half a second sooner"
                enabled: reader.session && reader.session.offset < 10
                onClicked: reader.session.offset += .5
            }
        }
    }
    Keys.onEscapePressed: dismissRequested()
}
