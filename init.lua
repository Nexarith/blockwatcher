-- blockwatcher/init.lua
-- Logs every block dig/place on the server into daily files
-- Author: Cashia ©2025

local log_folder = minetest.get_worldpath() .. "/blockloader"

-- Make sure folder exists
minetest.mkdir(log_folder)

-- Helper to get today's filename
local function get_today_file()
    local date_str = os.date("%m-%d-%Y")
    return log_folder .. "/" .. date_str .. ".txt"
end

-- Function to log events
local function log_event(playername, action, pos, node)
    local f = io.open(get_today_file(), "a")
    if f then
        local line = minetest.serialize({
            time = os.time(),
            player = playername,
            action = action,
            nodename = node.name,
            pos = {x=pos.x, y=pos.y, z=pos.z}
        })
        f:write(line .. "\n")
        f:close()
    end
end

-- Register BlockWatcher admin privilege
minetest.register_privilege("blockwatcher_admin", {
    description = "Allows use of BlockWatcher admin commands",
    give_to_singleplayer = true
})

-- Register digging event
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() then
        log_event(digger:get_player_name(), "dug", pos, oldnode)
    end
end)

-- Register placing event
minetest.register_on_placenode(function(pos, newnode, placer)
    if placer and placer:is_player() then
        log_event(placer:get_player_name(), "placed", pos, newnode)
    end
end)

-- Load logs from all files
local function load_logs()
    local logs = {}
    for _, file in ipairs(minetest.get_dir_list(log_folder, false)) do
        local f = io.open(log_folder .. "/" .. file, "r")
        if f then
            for line in f:lines() do
                local data = minetest.deserialize(line)
                if data then table.insert(logs, data) end
            end
            f:close()
        end
    end
    return logs
end

-- Helper function to get WorldEdit positions (//1 and //2)
local function get_pos(name, pos)
    local we = rawget(_G, "worldedit")
    if we and we.pos and we.pos[name] then
        return we.pos[name][pos] and vector.new(we.pos[name][pos]) or nil
    end
    return nil
end

-- /bw_check <player> command
minetest.register_chatcommand("bw_check", {
    params = "<player>",
    description = "Show block edits made by a specific player",
    privs = {blockwatcher_admin=true},
    func = function(name, param)
        if param == "" then return false, "Usage: /bw_check <player>" end
        local player = param
        local logs = load_logs()
        local result = {}
        for i = #logs, 1, -1 do
            local row = logs[i]
            if row.player == player then
                table.insert(result, os.date("%Y-%m-%d %H:%M:%S", row.time)
                    .. " | " .. row.action .. " | " .. row.nodename
                    .. " at (" .. row.pos.x .. "," .. row.pos.y .. "," .. row.pos.z .. ")")
                if #result >= 50 then break end
            end
        end
        if #result == 0 then return true, "No edits found for player " .. player end
        return true, table.concat(result, "\n")
    end,
})

-- /bw_area command
minetest.register_chatcommand("bw_area", {
    description = "Show edits inside a selected region (use //1 and //2 from WorldEdit)",
    privs = {blockwatcher_admin=true},
    func = function(name)
        local p1 = get_pos(name, 1)
        local p2 = get_pos(name, 2)
        if not p1 or not p2 then return false, "Set positions with //1 and //2 first!" end

        local minp = {x=math.min(p1.x,p2.x), y=math.min(p1.y,p2.y), z=math.min(p1.z,p2.z)}
        local maxp = {x=math.max(p1.x,p2.x), y=math.max(p1.y,p2.y), z=math.max(p1.z,p2.z)}

        local logs = load_logs()
        local result = {}
        for i = #logs, 1, -1 do
            local row = logs[i]
            local pos = row.pos
            if pos.x >= minp.x and pos.x <= maxp.x and
               pos.y >= minp.y and pos.y <= maxp.y and
               pos.z >= minp.z and pos.z <= maxp.z then
                table.insert(result, os.date("%Y-%m-%d %H:%M:%S", row.time)
                    .. " | " .. row.player .. " " .. row.action
                    .. " " .. row.nodename
                    .. " at (" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ")")
                if #result >= 100 then break end
            end
        end

        if #result == 0 then return true, "No edits found in this region." end
        return true, table.concat(result, "\n")
    end,
})

-- /bw_undo command
minetest.register_chatcommand("bw_undo", {
    params = "[player <name> [count]] | [area]",
    description = "Undo block changes by player or in area",
    privs = {blockwatcher_admin=true},
    func = function(name, param)
        local args = {}
        for word in param:gmatch("%S+") do table.insert(args, word) end
        if #args == 0 then return false, "Usage: /bw_undo player <name> [count] OR /bw_undo area" end

        local logs = load_logs()
        local changes = {}

        -- Undo by player
        if args[1] == "player" then
            local player_name = args[2]
            local count = tonumber(args[3]) or 50
            if not player_name then return false, "Specify player name!" end

            for i = #logs, 1, -1 do
                local row = logs[i]
                if row.player == player_name then
                    table.insert(changes, row)
                    if #changes >= count then break end
                end
            end

        -- Undo in area
        elseif args[1] == "area" then
            local p1 = get_pos(name, 1)
            local p2 = get_pos(name, 2)
            if not p1 or not p2 then return false, "Set positions with //1 and //2 first!" end

            local minp = {x=math.min(p1.x,p2.x), y=math.min(p1.y,p2.y), z=math.min(p1.z,p2.z)}
            local maxp = {x=math.max(p1.x,p2.x), y=math.max(p1.y,p2.y), z=math.max(p1.z,p2.z)}

            for i = #logs, 1, -1 do
                local row = logs[i]
                local pos = row.pos
                if pos.x >= minp.x and pos.x <= maxp.x and
                   pos.y >= minp.y and pos.y <= maxp.y and
                   pos.z >= minp.z and pos.z <= maxp.z then
                    table.insert(changes, row)
                    if #changes >= 100 then break end
                end
            end
        else
            return false, "Invalid parameters. Usage: /bw_undo player <name> [count] OR /bw_undo area"
        end

        for _, row in ipairs(changes) do
            local pos = row.pos
            if row.action == "placed" then
                minetest.set_node(pos, {name="air"})
            elseif row.action == "dug" then
                minetest.set_node(pos, {name=row.nodename})
            end
        end

        return true, "Undid " .. #changes .. " actions."
    end,
})

-- Retroactive logging of all existing blocks into daily files
minetest.register_on_mods_loaded(function()
    local files = minetest.get_dir_list(log_folder, false)
    if #files > 0 then return end -- skip if logs already exist

    minetest.log("action", "[blockwatcher] Starting retroactive logging...")
    local mapblocks = minetest.get_mapgen_params().chunks or {}
    for _, blockpos in ipairs(mapblocks) do
        for x = 0, 15 do
            for y = 0, 15 do
                for z = 0, 15 do
                    local pos = vector.add(blockpos, {x=x, y=y, z=z})
                    local node = minetest.get_node(pos)
                    if node and node.name ~= "ignore" then
                        log_event("<unknown>", "placed", pos, node)
                    end
                end
            end
        end
    end
    minetest.log("action", "[blockwatcher] Retroactive logging complete.")
end)

minetest.log("action", "[blockwatcher] Loaded successfully (file logging by day, WorldEdit //1 and //2, retroactive logging).")
