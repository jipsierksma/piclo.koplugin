local Codec = require("piclogic/model/codec")
local H = require("helpers")

describe("codec", function()
    it("run-length encodes", function()
        assert.are.equal("1:3.#2x", Codec.encode(H.line("...#xx"), 6))
    end)

    it("round-trips mixed boards", function()
        for _, s in ipairs({ ".", "#", "x", "#x#x#x", "..........##########xxxxxxxxxx", "x.#" }) do
            local cells = H.line(s)
            assert.are.same(cells, (Codec.decode(Codec.encode(cells, #s), #s)))
        end
    end)

    it("round-trips a full 15x15 board compactly", function()
        local s = string.rep("#", 100) .. string.rep(".", 100) .. string.rep("x", 25)
        local enc = Codec.encode(H.line(s), 225)
        assert.is_true(#enc < 20)
        assert.are.equal(s, H.str(Codec.decode(enc, 225)))
    end)

    it("rejects the wrong length", function()
        assert.is_nil((Codec.decode("1:4.", 5)))
        assert.is_nil((Codec.decode("1:6.", 5)))
    end)

    it("rejects garbage and unknown versions", function()
        assert.is_nil((Codec.decode("1:3?", 3)))
        assert.is_nil((Codec.decode("1:12", 12)))
        assert.is_nil((Codec.decode("2:3.", 3)))
        assert.is_nil((Codec.decode(nil, 3)))
        assert.is_nil((Codec.decode("1:0.", 0)))
    end)
end)
