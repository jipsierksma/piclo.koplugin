-- One valid puzzle among malformed entries.
return {
    id = "mixed",
    title = "Mixed",
    license = "CC0-1.0",
    puzzles = {
        { id = "mixed/ragged", rows = { "##", "#" } },
        { id = "mixed/ok", rows = { "#" } },
        "not a table",
        { id = "good/a", rows = { "#" } },
        { id = "mixed/badshade", rows = { "#" }, shade = { "9" } },
    },
}
