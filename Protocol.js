function trackInput(player, duration) {
    var input = {title: player.trackTitle || "", artist: player.trackArtist || "", album: player.trackAlbum || "", duration: duration};
    for (var name of ["title", "artist", "album"])
        if (typeof input[name] !== "string" || input[name].length > 500) throw new Error("Invalid track metadata");
    return JSON.stringify(input);
}

function response(text) {
    if (text.length > 524288) throw new Error("Oversized response");
    var value = JSON.parse(text);
    if (!value || ["ready", "missing", "instrumental", "error"].indexOf(value.state) < 0
            || !Array.isArray(value.lines) || value.lines.length > 2000)
        throw new Error("Invalid response");
    if (value.message !== undefined && (typeof value.message !== "string" || value.message.length > 500))
        throw new Error("Invalid message");
    if (value.source !== undefined && (typeof value.source !== "string" || value.source.length > 80))
        throw new Error("Invalid source");
    if (value.retryAfter !== undefined && (typeof value.retryAfter !== "number" || !isFinite(value.retryAfter) || value.retryAfter <= 0))
        throw new Error("Invalid cooldown");
    var previous = -1;
    for (var row of value.lines) {
        if (!row || typeof row.text !== "string" || row.text.length > 2048 || typeof row.at !== "number" || !isFinite(row.at))
            throw new Error("Invalid lyric cue");
        if (value.synced === true) {
            if (row.at < 0 || row.at < previous) throw new Error("Unordered lyric cues");
            previous = row.at;
        } else if (row.at !== -1) throw new Error("Invalid plain lyric cue");
    }
    if (value.state === "ready" && (!value.lines.length || typeof value.synced !== "boolean"))
        throw new Error("Missing lyrics");
    if (value.state !== "ready" && value.lines.length) throw new Error("Unexpected lyrics");
    return value;
}

