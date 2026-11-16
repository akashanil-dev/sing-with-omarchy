import QtQuick
import QtTest
import "../Protocol.js" as Protocol
import ".." as Sing

TestCase {
    name: "Boundaries"
    QtObject {
        id: host
        property var answer: null
        function serviceFor(id) { return answer; }
    }
    Sing.ServiceLink { id: link; host: host }
    function test_late_service_and_replacement() {
        // Plain function lookup deliberately has no binding notification.
        compare(link.service, null);
        host.answer = {marker: "first"};
        tryCompare(link, "service", host.answer, 1200);
        host.answer = {marker: "replacement"};
        tryCompare(link, "service", host.answer, 1200);
        host.answer = null;
        tryCompare(link, "service", null, 1200);
    }
    function test_protocol_rejects_bad_results() {
        var bad = [
            {state: "ready", synced: true, lines: []},
            {state: "ready", synced: true, lines: [{at: -1, text: "bad"}]},
            {state: "ready", synced: true, lines: [{at: 10, text: "a"}, {at: 5, text: "b"}]},
            {state: "error", lines: [], retryAfter: "100"},
            {state: "ready", synced: true, lines: [{at: 0, text: "x".repeat(2049)}]}
        ];
        for (var value of bad) {
            var rejected = false;
            try { Protocol.response(JSON.stringify(value)); } catch (error) { rejected = true; }
            verify(rejected);
        }
        compare(Protocol.response(JSON.stringify({state:"ready", synced:true, lines:[{at:0,text:"<b>Literal</b>"}]})).lines[0].text, "<b>Literal</b>");
    }
}
