-- First Steps: one story, a chick growing up, from egg to first flight. The
-- grid grows with the chick (6x6 to 8x8). The story sets the order, so the
-- validator doesn't hold this pack to easy-to-hard. Original art, see
-- CREDITS.md and docs/ART_STYLE.md.
return {
    id = "starter",
    title = _("First Steps"),
    license = "CC-BY-4.0",
    credit = "Jip Sierksma",
    story = true,
    puzzles = {
        {
            id = "starter/egg",
            title = _("Egg"),
            art = {
                "..44..",
                ".4443.",
                "344432",
                "344332",
                "233322",
                ".2222.",
            },
        },
        {
            id = "starter/chick",
            title = _("Chick"),
            art = {
                "...332.",
                "..32020",
                ".32222.",
                ".321121",
                "..22111",
                "..0..0.",
                "..00.00",
            },
        },
        {
            id = "starter/flap",
            title = _("First flap"),
            art = {
                "1......1",
                "11.332.1",
                "11330201",
                ".322211.",
                "..22211.",
                "..2211..",
                "...0.00.",
                "..00....",
            },
        },
        {
            id = "starter/flight",
            title = _("Flight"),
            art = {
                ".33.....",
                ".333..22",
                "..333202",
                "2.222221",
                "222222..",
                "........",
                "..4444..",
                ".444444.",
            },
        },
    },
}
