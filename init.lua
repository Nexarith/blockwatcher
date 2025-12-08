-- blockwatcher/init.lua
-- Fully standalone BlockWatcher mod with particle region visualization
-- Author: Cashia ©2025

-- Load config
local config_path = minetest.get_modpath("blockwatcher") .. "/config.lua"
local config = {}
if pcall(dofile, config_path) then
    config = BlockWatcherConfig or {}
else
    minetest.log("warning", "[blockwatcher] config.lua not found or failed to load. Using defaults.")
end

-- Defaults if config entries missing
config.log_folder = config.log_folder or (minetest.get_worldpath() .. "/blockloader")
config.particle_enabled = config.particle_enabled ~= false
config.particle_duration = config.particle_duration or 3
config.particle_size = config.particle_size or 4
config.particle_color = config.particle_color or "#0000FF:80"
config.particle_glow = config.particle_glow or 10
config.max_undo_player = config.max_undo_player or 50
config.max_undo_area = config.max_undo_area or 100
config.admin_priv = config.admin_priv or "blockwatcher_admin"
config.view_priv = config.view_priv or "blockwatcher_view"
config.cache_logs = config.cache_logs ~= false
config.max_cached_logs = config.max_cached_logs or 10000
config.preserve_metadata = config.preserve_metadata ~= false
config.undo_preview = config.undo_preview == true

-- Ensure log folder exists
minetest.mkdir(config.log_folder)

-- Table to store per-player region selection
local region_pos = {}

-- Admin privilege
minetest.register_privilege(config.admin_priv, {
    description = "Allows use of BlockWatcher commands",
    give_to_singleplayer = true
})

-- Optional: Read-only view privilege
minetest.register_privilege(config.view_priv, {
    description = "Allows viewing logs but not undoing"
})

-- Helper: today's file
local function get_today_file()
    return config.log_folder .. "/" .. os.date("%m-%d-%Y") .. ".txt"
end

-- Log a block action
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

-- Load logs (with optional cache)
local logs_cache = {}
local function load_logs()
    if config.cache_logs and next(logs_cache) ~= nil then
        return logs_cache
    end

    local logs = {}
    for _, file in ipairs(minetest.get_dir_list(config.log_folder, false)) do
        local f = io.open(config.log_folder .. "/" .. file, "r")
        if f then
            for line in f:lines() do
                local data = minetest.deserialize(line)
                if data then table.insert(logs, data) end
            end
            f:close()
        end
    end

    if config.cache_logs then logs_cache = logs end
    return logs
end

-- Particle visualization helper
local function show_region_particles(name)
    if not config.particle_enabled then return end
    local p1 = region_pos[name] and region_pos[name].pos1
    local p2 = region_pos[name] and region_pos[name].pos2
    if not p1 or not p2 then return end

    local minp = {x=math.min(p1.x,p2.x), y=math.min(p1.y,p2.y), z=math.min(p1.z,p2.z)}
    local maxp = {x=math.max(p1.x,p2.x), y=math.max(p1.y,p2.y), z=math.max(p1.z,p2.z)}

    for x=minp.x,maxp.x do
        for y=minp.y,maxp.y do
            for z=minp.z,maxp.z do
                if x==minp.x or x==maxp.x or y==minp.y or y==maxp.y or z==minp.z or z==maxp.z then
                    minetest.add_particle({
                        pos = {x=x+0.5, y=y+0.5, z=z+0.5},
                        velocity = {x=0, y=0, z=0},
                        acceleration = {x=0, y=0, z=0},
                        expirationtime = config.particle_duration,
                        size = config.particle_size,
                        texture = "default_obsidian_glass.png^[colorize:"..config.particle_color,
                        glow = config.particle_glow
                    })
                end
            end
        end
    end
end

-- Helper to get selected region positions
local function get_selected_pos(name, pos)
    if region_pos[name] then
        return region_pos[name]["pos"..pos]
    end
    return nil
end

-- Dig/place event logging
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() then
        log_event(digger:get_player_name(), "dug", pos, oldnode)
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer)
    if placer and placer:is_player() then
        log_event(placer:get_player_name(), "placed", pos, newnode)
    end
end)

-- Region selection commands
minetest.register_chatcommand("bw_set1", {
    description = "Set first corner of region",
    privs = {[config.admin_priv]=true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found!" end
        region_pos[name] = region_pos[name] or {}
        region_pos[name].pos1 = vector.round(player:get_pos())
        if region_pos[name].pos2 then show_region_particles(name) end
        return true, "First corner set at ("..region_pos[name].pos1.x..","..region_pos[name].pos1.y..","..region_pos[name].pos1.z..")"
    end,
})

minetest.register_chatcommand("bw_set2", {
    description = "Set second corner of region",
    privs = {[config.admin_priv]=true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found!" end
        region_pos[name] = region_pos[name] or {}
        region_pos[name].pos2 = vector.round(player:get_pos())
        if region_pos[name].pos1 then show_region_particles(name) end
        return true, "Second corner set at ("..region_pos[name].pos2.x..","..region_pos[name].pos2.y..","..region_pos[name].pos2.z..")"
    end,
})

-- /bw_check <player>
minetest.register_chatcommand("bw_check", {
    params = "<player>",
    description = "Show last 50 edits by player",
    privs = {[config.admin_priv]=true},
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

-- /bw_area
minetest.register_chatcommand("bw_area", {
    description = "Show edits inside selected region",
    privs = {[config.admin_priv]=true},
    func = function(name)
        local p1 = get_selected_pos(name, 1)
        local p2 = get_selected_pos(name, 2)
        if not p1 or not p2 then return false, "Set region with /bw_set1 and /bw_set2 first!" end

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
                if #result >= config.max_undo_area then break end
            end
        end
        if #result == 0 then return true, "No edits found in this region." end
        return true, table.concat(result, "\n")
    end,
})

-- /bw_undo
minetest.register_chatcommand("bw_undo", {
    params = "[player <name> [count]] | [area]",
    description = "Undo block changes by player or in area",
    privs = {[config.admin_priv]=true},
    func = function(name, param)
        local args = {}
        for word in param:gmatch("%S+") do table.insert(args, word) end
        if #args == 0 then return false, "Usage: /bw_undo player <name> [count] OR /bw_undo area" end

        local logs = load_logs()
        local changes = {}

        if args[1] == "player" then
            local player_name = args[2]
            local count = tonumber(args[3]) or config.max_undo_player
            if not player_name then return false, "Specify player name!" end
            for i = #logs, 1, -1 do
                local row = logs[i]
                if row.player == player_name then
                    table.insert(changes, row)
                    if #changes >= count then break end
                end
            end
        elseif args[1] == "area" then
            local p1 = get_selected_pos(name, 1)
            local p2 = get_selected_pos(name, 2)
            if not p1 or not p2 then return false, "Set region with /bw_set1 and /bw_set2 first!" end

            local minp = {x=math.min(p1.x,p2.x), y=math.min(p1.y,p2.y), z=math.min(p1.z,p2.z)}
            local maxp = {x=math.max(p1.x,p2.x), y=math.max(p1.y,p2.y), z=math.max(p1.z,p2.z)}

            for i = #logs, 1, -1 do
                local row = logs[i]
                local pos = row.pos
                if pos.x >= minp.x and pos.x <= maxp.x and
                   pos.y >= minp.y and pos.y <= maxp.y and
                   pos.z >= minp.z and pos.z <= maxp.z then
                    table.insert(changes, row)
                    if #changes >= config.max_undo_area then break end
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

minetest.log("action", "[blockwatcher] Loaded successfully (particle region selection, daily logs, /bw_set1/2, /bw_area, /bw_check, /bw_undo).")
