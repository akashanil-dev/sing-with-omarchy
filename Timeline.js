function activeCue(lines, seconds) {
    var lo = 0, hi = lines.length;
    while (lo < hi) {
        var mid = Math.floor((lo + hi) / 2);
        if (lines[mid].at <= seconds) lo = mid + 1;
        else hi = mid;
    }
    return lo - 1;
}

function clock(seconds) {
    var whole = Math.max(0, Math.floor(Number(seconds) || 0));
    return Math.floor(whole / 60) + ":" + (whole % 60 < 10 ? "0" : "") + whole % 60;
}

function choosePlayer(players, preferred) {
    var eligible = players.filter(function(p) { return !!p.trackTitle; });
    return eligible.find(function(p) { return p.dbusName === preferred; })
        || eligible.find(function(p) { return p.isPlaying; }) || eligible[0] || null;
}
