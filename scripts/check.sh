#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -m unittest discover -s tests -v
if command -v omarchy >/dev/null; then omarchy plugin validate .; fi

qt_bin=${QT_BIN_DIR:-/usr/lib/qt6/bin}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/runtime" "$scratch/cache"
chmod 700 "$scratch/runtime"
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_CACHE_HOME="$scratch/cache"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic
export QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
unset DISPLAY WAYLAND_DISPLAY

"$qt_bin/qmllint" Theme.qml LyricButton.qml Reader.qml Session.qml ServiceLink.qml preview.qml
"$qt_bin/qmltestrunner" -input tests
for test_file in session-check.qml worker-check.qml; do
    log="$scratch/${test_file}.log"
    timeout 10s quickshell -p "$test_file" >"$log" 2>&1 || { cat "$log"; exit 1; }
    cat "$log"
    if ! grep -q 'PASS:' "$log" || grep -q 'FAIL:' "$log"; then exit 1; fi
done
if command -v omarchy >/dev/null; then python3 scripts/check_host.py; fi
