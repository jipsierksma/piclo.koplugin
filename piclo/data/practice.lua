--[[
The practice puzzles behind "Try a practice puzzle" in How to play: two tiny
boards with a guide that walks through them a line at a time. They are not
part of any pack: nothing is saved or counted.

Each step names the lines it is about (their clues are highlighted) and what
the player must do there:
  fill   "all" or positions along the line: those of the picture's squares
  cross  "all" or positions: those of its empty squares
  solve  the last step: finish the picture
A step is done as soon as the board shows it, even when the player got there
first. spec/practice_spec.lua checks that every step can be worked out from
the board the steps before it leave.
]]

return {
    {
        id = "practice/window",
        art = {
            "00000",
            "0.0.0",
            "00000",
            "0.0.0",
            "00000",
        },
        steps = {
            { lines = { { "row", 1 } }, fill = "all",
                text = _("The top row says 5, and it has five squares: every one of them is filled. Tap each square, or drag along the row.") },
            { lines = { { "row", 3 }, { "row", 5 } }, fill = "all",
                text = _("Rows 3 and 5 say 5 too. Fill them.") },
            { lines = { { "row", 2 } }, fill = "all",
                text = _("Row 2 says 1 1 1: three single squares with a gap between each. That takes exactly five squares, so they only fit one way. Fill the three.") },
            { lines = { { "row", 2 } }, cross = "all",
                text = _("The gaps stay empty. Choose Cross in the toolbar and cross them, so you can see the row is done.") },
            { lines = { { "row", 4 } }, solve = true,
                text = _("Row 4 is the same as row 2. Fill it to finish the picture.") },
        },
        done = _("Solved. Every puzzle works like this: find a line you can be sure of, mark it, and move on."),
    },
    {
        id = "practice/heart",
        art = {
            ".0.0.",
            "00000",
            "00000",
            ".000.",
            "..0..",
        },
        steps = {
            { lines = { { "row", 2 }, { "row", 3 } }, fill = "all",
                text = _("Rows 2 and 3 say 5. Fill them.") },
            { lines = { { "col", 3 } }, fill = { 2, 3, 4 },
                text = _("Column 3 says 4. Its run starts at the top or one square lower, and both ways cover the middle three squares. Fill those.") },
            { lines = { { "col", 2 }, { "col", 4 } }, fill = { 2, 3, 4 },
                text = _("Columns 2 and 4 say 4 as well. Fill their middle three.") },
            { lines = { { "row", 4 } }, cross = "all",
                text = _("Row 4 says 3, and its run of three is there. The row is complete: cross its other squares.") },
            { lines = { { "col", 1 }, { "col", 5 } }, cross = "all",
                text = _("Columns 1 and 5 say 2, and both have their two. Cross the rest of them.") },
            { lines = { { "row", 1 } }, fill = "all", cross = "all",
                text = _("Row 1 says 1 1, with three squares left. Two runs need a gap between them, so they take the outer two. Fill those and cross the middle.") },
            { lines = {}, solve = true,
                text = _("Finish the picture on your own. When you're stuck, the bulb in the toolbar shows the next step.") },
        },
        done = _("Solved. That's all there is to it. The packs start small and grow from there."),
    },
}
