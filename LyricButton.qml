import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool highlightedAction: false
    property string hint: ""
    property var theme: fallbackTheme
    Theme { id: fallbackTheme }
    implicitHeight: 34
    implicitWidth: Math.max(34, label.implicitWidth + 22)
    padding: 0
    hoverEnabled: true
    Accessible.name: hint || text
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    contentItem: Text {
        id: label
        text: control.text
        textFormat: Text.PlainText
        color: !control.enabled ? control.theme.muted : control.highlightedAction ? control.theme.onAccent : control.theme.foreground
        font.pixelSize: 13
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 10
        color: control.highlightedAction ? control.theme.accent : control.down ? control.theme.pressed : control.hovered ? control.theme.hover : control.theme.button
        border.width: control.activeFocus ? 2 : 0
        border.color: control.theme.accent
    }
}
