import QtQuick
import QtTest
import "../Timeline.js" as Timeline

TestCase {
    name: "Timeline"
    function test_boundaries_and_seek_back() {
        var lines = [{at: 5}, {at: 10}, {at: 30}];
        compare(Timeline.activeCue(lines, 0), -1);
        compare(Timeline.activeCue(lines, 5), 0);
        compare(Timeline.activeCue(lines, 29.9), 1);
        compare(Timeline.activeCue(lines, 100), 2);
        compare(Timeline.activeCue(lines, 6), 0);
        compare(Timeline.activeCue([], 20), -1);
    }
    function test_player_selection() {
        var paused = {dbusName: "a", trackTitle: "Song", isPlaying: false};
        var playing = {dbusName: "b", trackTitle: "Other", isPlaying: true};
        compare(Timeline.choosePlayer([paused, playing], ""), playing);
        compare(Timeline.choosePlayer([paused, playing], "a"), paused);
        compare(Timeline.choosePlayer([playing], "a"), playing);
        compare(Timeline.choosePlayer([], ""), null);
    }
    function test_time_format() {
        compare(Timeline.clock(0), "0:00");
        compare(Timeline.clock(125.9), "2:05");
        compare(Timeline.clock(-1), "0:00");
    }
}
