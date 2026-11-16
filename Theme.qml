import QtQuick

QtObject {
    id: theme
    property SystemPalette system: SystemPalette { colorGroup: SystemPalette.Active }
    property color background: system.window
    property color foreground: system.windowText
    property color accent: system.highlight
    property string fontFamily: Qt.application.font.family
    property int bodySize: 12
    property int captionSize: 10
    property int titleSize: 16
    property real cornerRadius: 0
    readonly property color muted: mix(0.65)
    readonly property color border: mix(0.18)
    property color button: mix(0.04)
    property color hover: mix(0.08)
    property color pressed: mix(0.22)
    property color selected: mix(0.18)
    property color buttonBorder: mix(0.4)
    property real buttonBorderWidth: 1
    readonly property color onAccent: luminance(accent) > 0.179 ? "black" : "white"
    function mix(amount) {
        return Qt.tint(background, Qt.rgba(foreground.r, foreground.g, foreground.b, amount));
    }
    function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4); }
    function luminance(color) { return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b); }
}
