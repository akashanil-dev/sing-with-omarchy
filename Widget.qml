import QtQuick
import Quickshell
import qs.Ui as Ui
import qs.Commons as Commons

Ui.Panel {
    id: widget
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""
    readonly property var session: serviceLink.service
    property var registeredSession: null
    readonly property string screenName: widget.QsWindow.window && widget.QsWindow.window.screen ? widget.QsWindow.window.screen.name : ""
    readonly property bool readerVisible: opened || detached.visible
    manageIpc: false
    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    Theme {
        id: currentTheme
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        accent: Commons.Color.accent
    }

    ServiceLink { id: serviceLink; host: widget.shell; fallbackHost: widget.bar ? widget.bar.shell : null }
    onSessionChanged: {
        if (registeredSession) registeredSession.detachView(widget);
        registeredSession = session;
        if (session) session.attachView(widget);
    }
    Component.onDestruction: if (registeredSession) registeredSession.detachView(widget)
    function presentReader() {
        if (detached.visible) detached.minimized = false;
        else widget.open();
    }
    function dismissReaders() { widget.close(); detached.visible = false; }

    Ui.BarIconButton {
        id: barButton
        anchors.fill: parent
        bar: widget.bar
        text: "♫"
        active: widget.readerVisible
        activeColor: currentTheme.accent
        tooltipText: "Sing with Omarchy"
        onPressed: button => {
            if (button === Qt.LeftButton)
                widget.readerVisible ? widget.dismissReaders() : widget.presentReader();
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Sing with Omarchy"
    Accessible.onPressAction: widget.readerVisible ? widget.dismissReaders() : widget.presentReader()

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
            theme: currentTheme
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
        color: currentTheme.background
        Reader {
            anchors.fill: parent
            detached: true
            session: widget.session
            theme: currentTheme
            focus: true
            onDismissRequested: detached.visible = false
            onMoveRequested: detached.startSystemMove()
        }
    }
}
