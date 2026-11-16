"""Load actual Omarchy UI types without installing or changing the user's shell."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
host = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell"
if not (host / "Ui").is_dir():
    raise SystemExit("Omarchy UI modules unavailable; host check cannot run.")
with tempfile.TemporaryDirectory(prefix="sing-host-") as directory:
    stage = Path(directory)
    for extension in ("*.qml", "*.js"):
        for source in root.glob(extension):
            shutil.copy2(source, stage / source.name)
    for name in ("Ui", "Commons"):
        (stage / name).symlink_to(host / name, target_is_directory=True)
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    id: test
    property int step: 0
    Session { id: first; demo: true; players: [] }
    Session { id: second; demo: true; players: [] }
    QtObject {
        id: facade
        property var answer: null
        function serviceFor(id) { return answer; }
    }
    Widget { id: widget; shell: facade }
    Loader { id: extra; active: true; sourceComponent: Widget { shell: facade } }
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        interval: 700; running: true; repeat: true
        onTriggered: {
            if (test.step === 0) {
                test.check(first.views.length === 0, "unavailable service"); facade.answer = first;
            } else if (test.step === 1) {
                test.check(first.views.length === 2, "two widgets attach after late startup"); facade.answer = second;
            } else if (test.step === 2) {
                test.check(first.views.length === 0 && second.views.length === 2, "service replacement unregisters old views"); extra.active = false;
            } else {
                test.check(second.views.length === 1, "destroyed widget unregisters");
                console.log("PASS: Omarchy widget late-start, replacement and teardown"); Qt.quit();
            }
            test.step++;
        }
    }
}
''')
    result = subprocess.run(["quickshell", "-p", str(stage / "shell.qml")],
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or "PASS:" not in output or "FAIL:" in output:
        raise SystemExit(1)
