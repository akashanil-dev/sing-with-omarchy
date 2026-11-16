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
        color: !control.enabled ? control.theme.muted : control.highlightedAction ? control.theme.accent : control.theme.foreground
        font.family: control.theme.fontFamily
        font.pixelSize: control.theme.bodySize
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: control.theme.cornerRadius
        color: control.down ? control.theme.pressed : control.hovered ? control.theme.hover : control.highlightedAction ? control.theme.selected : control.theme.button
        border.width: control.activeFocus ? 1 : control.highlightedAction ? 0 : control.theme.buttonBorderWidth
        border.color: control.activeFocus ? control.theme.accent : control.theme.buttonBorder
    }
}
