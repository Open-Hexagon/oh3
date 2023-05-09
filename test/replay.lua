require("busted.runner")()
local Replay = loadfile("replay.lua")()

describe("Replay files", function()
    it("can be created", function()
        local rp = Replay:new()
        rp:set_game_data({ invincible = true }, true, 2323, "somepack", "somelevel", { somesetting = 10 })
        rp:save("test.ohr2.z")
    end)
    it("can be loaded", function()
        local rp = Replay:new("test.ohr2.z")
        assert.is_true(rp.data.config.invincible)
        assert.is.equal(rp.data.level_settings.somesetting, 10)
        assert.is.equal(rp.pack_id, "somepack")
        assert.is.equal(rp.level_id, "somelevel")
        assert.is.equal(rp.seed, 2323)
        assert.is_true(rp.first_play)
    end)
    it("can save and load inputs", function()
        local rp = Replay:new()
        rp:set_game_data({ debug = true }, false, 23453, "somepack", "somelevel", { somesetting = false })
        local to_record = {
            [10] = {
                left = true,
            },
            [11] = {
                right = true,
            },
            [12] = {
                right = false,
            },
            [20] = {
                left = false,
            },
            [30] = {
                right = true,
                left = true,
            },
            [35] = {
                right = false,
                left = false,
            },
        }
        -- order needs to be right
        local keys = { 10, 11, 12, 20, 30, 35 }
        for i = 1, #keys do
            local time = keys[i]
            local state = to_record[time]
            for key, bool in pairs(state) do
                rp:record_input(key, bool, time)
            end
        end
        rp:save("test.ohr2.z")
        local loaded_rp = Replay:new("test.ohr2.z")
        assert.is_true(loaded_rp.data.config.debug)
        assert.is_false(loaded_rp.data.level_settings.somesetting)
        assert.is.equal(rp.seed, 23453)
        assert.is.equal(loaded_rp.pack_id, "somepack")
        assert.is.equal(loaded_rp.level_id, "somelevel")
        assert.is_false(loaded_rp.first_play)
        for time, state in pairs(to_record) do
            local state_changes = loaded_rp:get_key_state_changes(time)
            local index = 1
            for key, bool in pairs(state) do
                assert.is.equal(state_changes[index], key)
                assert.is.equal(state_changes[index + 1], bool)
                index = index + 2
            end
        end
    end)
end)
