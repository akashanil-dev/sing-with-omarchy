import QtQuick
import Quickshell

ShellRoot {
    Session { id: demoSession; demo: true }
    FloatingWindow {
        visible: true
        title: "Sing with Omarchy — preview"
        implicitWidth: 440
        implicitHeight: 650
        color: "#111115"
        Reader {
            anchors.fill: parent
            session: demoSession
            detached: true
            focus: true
            onDismissRequested: Qt.quit()
        }
    }
}
