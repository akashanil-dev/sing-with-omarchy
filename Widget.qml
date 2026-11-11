import QtQuick
import Quickshell
import qs.Ui as Ui
import qs.Commons as Commons

Ui.Panel {
    id: widget
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""
    readonly property var session: shell ? shell.serviceFor("akash.sing-with-omarchy") : null
    ipcTarget: "akash.sing-with-omarchy"
    implicitWidth: 30
    implicitHeight: 30

    Text {
        anchors.centerIn: parent
        text: "♫"
        font.pixelSize: 22
        color: widget.opened ? "#eac184" : widget.barForeground
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: widget.toggle()
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Sing with Omarchy"
    Accessible.onPressAction: toggle()

    Ui.PopupCard {
        anchorItem: widget
        bar: widget.bar
        owner: widget
        open: widget.opened
        padding: 0
        contentWidth: Math.min(440, availableCardWidth || 440)
        contentHeight: Math.min(620, availableCardHeight || 620)
        Reader {
            anchors.fill: parent
            session: widget.session
            onDismissRequested: widget.close()
            onDetachRequested: {
                widget.closeForPopoutSwitch();
                detached.visible = true;
            }
        }
    }
    FloatingWindow {
        id: detached
        visible: false
        title: "Sing with Omarchy"
        implicitWidth: 480
        implicitHeight: 680
        minimumSize: Qt.size(360, 430)
        color: "#111115"
        Reader {
            anchors.fill: parent
            detached: true
            session: widget.session
            focus: true
            onDismissRequested: detached.visible = false
            onMoveRequested: detached.startSystemMove()
        }
    }
}
