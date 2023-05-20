local Replay = require("game_handler.replay")

describe("Replay files", function()
    it("can be created", function()
        local rp = Replay:new()
        rp:set_game_data(21, { invincible = true }, true, "somepack", "somelevel", { somesetting = 10 })
        rp:record_seed(2323)
        rp:record_seed(23232)
        rp:save("test_replay")
    end)
    it("can be loaded", function()
        local rp = Replay:new("test_replay")
        assert.is.equal(rp.game_version, 21)
        assert.is_true(rp.data.config.invincible)
        assert.is.equal(rp.data.level_settings.somesetting, 10)
        assert.is.equal(rp.pack_id, "somepack")
        assert.is.equal(rp.level_id, "somelevel")
        assert.is.equal(rp.data.seeds[1], 2323)
        assert.is.equal(rp.data.seeds[2], 23232)
        assert.is_true(rp.first_play)
    end)
    it("can save and load inputs", function()
        local rp = Replay:new()
        rp:set_game_data(192, { debug = true }, false, "somepack", "somelevel", { somesetting = false })
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
        rp:save("test_replay")
        local loaded_rp = Replay:new("test_replay")
        assert.is.equal(loaded_rp.game_version, 192)
        assert.is_true(loaded_rp.data.config.debug)
        assert.is_false(loaded_rp.data.level_settings.somesetting)
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
