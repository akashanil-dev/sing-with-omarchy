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

    property real markerCenter: -1

    function followCue() {
        scrollMotion.stop();
        if (!session || !session.following) return;
        var previous = verses.contentY;
        verses.forceLayout();
        if (session.activeIndex >= 0) verses.positionViewAtIndex(session.activeIndex, ListView.Center);
        else verses.positionViewAtBeginning();
        var destination = verses.contentY;
        // The center stays still until the list reaches its lower scroll boundary.
        markerCenter = verses.currentItem ? verses.currentItem.y + verses.currentItem.height / 2 - destination : verses.height / 2;
        verses.contentY = previous;
        scrollMotion.to = destination;
        scrollMotion.start();
    }
    NumberAnimation {
        id: scrollMotion
        objectName: "lyricScrollMotion"
        target: verses
        property: "contentY"
        duration: 620
        easing.type: Easing.OutQuint
    }

    Connections {
        target: reader.session
        function onActiveIndexChanged() { reader.followCue(); }
        function onFollowingChanged() { reader.followCue(); }
        function onResultChanged() { Qt.callLater(reader.followCue); }
        function onFontSizeChanged() { Qt.callLater(reader.followCue); }
    }
    Component.onCompleted: Qt.callLater(followCue)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "♫"
                font.family: reader.theme.fontFamily
                font.pixelSize: 18
                color: reader.theme.accent
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                verticalAlignment: Text.AlignVCenter
                text: reader.detached ? "⠿  SING WITH OMARCHY" : "SING WITH OMARCHY"
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.captionSize
                font.letterSpacing: 0.8
                font.weight: Font.DemiBold
                color: reader.theme.muted
                MouseArea {
                    anchors.fill: parent
                    id: dragArea
                    enabled: reader.detached
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    onPressed: reader.moveRequested()
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Drag to move · pinned across workspaces"
                }
            }
            LyricButton {
                theme: reader.theme
                objectName: "detachButton"
                visible: !reader.detached
                text: "↗"
                hint: "Float lyrics across workspaces"
                onClicked: reader.detachRequested()
            }
            LyricButton {
                theme: reader.theme; text: "×"; hint: "Close lyrics"; onClicked: reader.dismissRequested() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.maximumWidth: reader.width * 0.56
                Layout.minimumWidth: 0
                text: reader.session ? reader.session.songTitle : "Starting…"
                textFormat: Text.PlainText
                font.family: reader.theme.fontFamily
                font.pixelSize: reader.theme.titleSize
                font.weight: Font.DemiBold
                color: reader.theme.foreground
                elide: Text.ElideRight
            }
            Text {
                text: "·"
                color: reader.theme.muted
                visible: reader.session && reader.session.artist.length > 0
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
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
            clip: true
            Rectangle {
                id: cueMarker
                objectName: "activeLyricMarker"
                z: 2
                width: 3
                radius: 1.5
                color: reader.theme.accent
                visible: verses.currentItem !== null && reader.session && reader.session.synced && reader.session.following
                property real centerY: reader.markerCenter < 0 ? verses.height / 2 : reader.markerCenter
                y: centerY - height / 2
                height: verses.currentItem ? verses.currentItem.height - 10 : 0
                Behavior on centerY { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }
            ListView {
                id: verses
                objectName: "verses"
                onHeightChanged: Qt.callLater(reader.followCue)
                anchors.fill: parent
                clip: true
                spacing: 10
                model: reader.session ? reader.session.lines : []
                currentIndex: reader.session ? reader.session.activeIndex : -1
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                topMargin: height / 2
                bottomMargin: 8
                onMovementStarted: { scrollMotion.stop(); if (reader.session) reader.session.following = false; }
                WheelHandler {
                    target: null
                    onWheel: event => {
                        scrollMotion.stop();
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
                    Text {
                        id: words
                        x: verse.active ? 19 : 15
                        width: parent.width - 26
                        transformOrigin: Item.Left
                        scale: verse.active || !reader.session.synced ? 1 : 0.96
                        Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.65 } }
                        anchors.verticalCenter: parent.verticalCenter
                        text: verse.modelData.text || "· · ·"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.family: reader.theme.fontFamily
                        font.pixelSize: reader.session ? reader.session.fontSize : 18
                        font.weight: Font.DemiBold
                        opacity: verse.active || !reader.session.synced ? 1 : 0.82
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        color: verse.active ? reader.theme.accent : !reader.session.synced ? reader.theme.foreground : reader.theme.muted
                        Behavior on color { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
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
                spacing: 8
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
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                ToolTip.visible: containsMouse
                ToolTip.text: reader.session ? (reader.session.synced ? "Timestamped lyrics · automatic following" : "Plain lyrics · no automatic following") + "\nSource: " + (reader.session.result.source || "Unavailable") + "\n" + Timeline.clock(reader.session.position) + " / " + Timeline.clock(reader.session.duration) : ""
            }
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
            spacing: 4
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
                text: "◎"
                highlightedAction: reader.session && reader.session.following
                enabled: reader.session && reader.session.synced
                hint: reader.session && reader.session.following ? "Following the current lyric" : "Resume following the current lyric"
                onClicked: { reader.session.following = true; reader.followCue(); }
            }
            LyricButton {
                theme: reader.theme
                text: reader.session && reader.session.retrySeconds > 0 ? reader.session.retrySeconds + "s" : "↻"
                hint: "Look up lyrics again"
                enabled: reader.session && (reader.session.player || reader.session.demo) && reader.session.result.state !== "loading" && reader.session.retrySeconds === 0
                onClicked: reader.session.refresh()
            }
            Rectangle { Layout.leftMargin: 4; Layout.rightMargin: 4; implicitWidth: 1; implicitHeight: 18; color: reader.theme.border }
            LyricButton {
                theme: reader.theme
                text: "−"; hint: "Show lyrics half a second later"
                enabled: reader.session && reader.session.synced && reader.session.offset > -10
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
                enabled: reader.session && reader.session.synced && reader.session.offset < 10
                onClicked: reader.session.offset += .5
            }
        }
    }
    Keys.onEscapePressed: dismissRequested()
}
