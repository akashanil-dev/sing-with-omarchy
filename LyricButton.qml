import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool highlightedAction: false
    property string hint: ""
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
        color: !control.enabled ? "#686873" : control.highlightedAction ? "#17140e" : "#e7e5e1"
        font.pixelSize: 13
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 10
        color: control.highlightedAction ? "#eac184" : control.down ? "#393940" : control.hovered ? "#303037" : "#24242b"
        border.width: control.activeFocus ? 2 : 0
        border.color: "#eac184"
    }
}
