import QtQuick

QtObject {
    id: theme
    property SystemPalette system: SystemPalette { colorGroup: SystemPalette.Active }
    property color background: system.window
    property color foreground: system.windowText
    property color accent: system.highlight
    readonly property color muted: mix(0.65)
    readonly property color border: mix(0.18)
    readonly property color button: mix(0.08)
    readonly property color hover: mix(0.14)
    readonly property color pressed: mix(0.22)
    readonly property color onAccent: luminance(accent) > 0.179 ? "black" : "white"
    function mix(amount) {
        return Qt.tint(background, Qt.rgba(foreground.r, foreground.g, foreground.b, amount));
    }
    function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4); }
    function luminance(color) { return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b); }
}
