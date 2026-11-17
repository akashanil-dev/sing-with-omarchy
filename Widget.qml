import QtQuick
import Quickshell
import Quickshell.Io
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
    readonly property bool centerLyricsEnabled: !!setting("centerLyrics", false)
    readonly property bool centerLyricsActive: centerLyrics.active
    function setCenterLyrics(value) {
        if (!!value === centerLyricsEnabled) return true;
        var entry = Object.assign({}, widget.settings, {id: "akash.sing-with-omarchy", centerLyrics: !!value});
        var api = widget.shell || (widget.bar ? widget.bar.shell : null);
        if (!api || !api.updateEntryInline("akash.sing-with-omarchy", entry)) return false;
        widget.settings = entry;
        return true;
    }
    CenterLyrics {
        id: centerLyrics
        surface: widget.QsWindow.window ? widget.QsWindow.window.contentItem : null
        requested: widget.centerLyricsEnabled && widget.bar !== null && !widget.bar.vertical
        lyric: widget.session && (widget.session.demo || (widget.session.player && widget.session.player.isPlaying)) && widget.session.synced && widget.session.activeIndex >= 0 ? widget.session.lines[widget.session.activeIndex].text : ""
        theme: currentTheme
        onClicked: widget.presentReader()
    }
    property bool detachPending: false
    readonly property bool readerVisible: opened || detached.visible || detachPending
    manageIpc: false
    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    Theme {
        id: currentTheme
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        accent: Commons.Color.accent
        fontFamily: Commons.Style.font.family
        bodySize: Commons.Style.font.body
        captionSize: Commons.Style.font.caption
        titleSize: Commons.Style.font.heading
        cornerRadius: Commons.Style.cornerRadius
        button: Commons.Style.normalFillFor(foreground, accent)
        hover: Commons.Style.hoverFillFor(foreground, accent)
        pressed: Commons.Style.pressedFillFor(foreground, accent)
        selected: Commons.Style.selectedFillFor(foreground, accent)
        buttonBorder: Commons.Style.normalBorderFor(foreground, accent)
        buttonBorderWidth: Commons.Style.normalBorderWidth
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
    function dismissReaders() { detachPending = false; widget.close(); detached.visible = false; }
    function presentDetached() {
        if (detached.visible) { detached.minimized = false; return; }
        detachPending = true;
        if (!floatRule.running) floatRule.running = true;
    }
    Process {
        id: floatRule
        command: ["hyprctl", "eval",
            'if sing_with_omarchy_popout == nil then '
            + 'sing_with_omarchy_popout = hl.window_rule({'
            + 'name="sing-with-omarchy-popout", '
            + 'match={class="^org[.]quickshell$",title="^Sing with Omarchy$"}, '
            + 'float=true,pin=true}) '
            + 'else sing_with_omarchy_popout:set_enabled(true) end']
        onExited: (exitCode, exitStatus) => {
            if (!widget.detachPending) return;
            widget.detachPending = false;
            if (exitCode !== 0 || exitStatus !== 0) {
                console.warn("Sing with Omarchy: could not prepare pinned reader");
                widget.open();
                return;
            }
            widget.closeForPopoutSwitch();
            detached.visible = true;
        }
    }

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
            centerLyricsAvailable: true
            centerLyricsEnabled: widget.centerLyricsEnabled
            onCenterLyricsToggled: widget.setCenterLyrics(!widget.centerLyricsEnabled)
            onDismissRequested: widget.close()
            onDetachRequested: widget.presentDetached()
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
            centerLyricsAvailable: true
            centerLyricsEnabled: widget.centerLyricsEnabled
            onCenterLyricsToggled: widget.setCenterLyrics(!widget.centerLyricsEnabled)
            focus: true
            onDismissRequested: detached.visible = false
            onMoveRequested: detached.startSystemMove()
        }
    }
}
