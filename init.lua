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

-- Defaults
config.log_folder = config.log_folder or (minetest.get_worldpath() .. "/blockwatcher")
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

-- Region storage
local region_pos = {}

-- Log cache
local logs_cache = {}
local cache_loaded = false

-- Privileges
minetest.register_privilege(config.admin_priv, {
    description = "Allows use of BlockWatcher commands",
    give_to_singleplayer = true
})

minetest.register_privilege(config.view_priv, {
    description = "Allows viewing BlockWatcher logs"
})

-- Today's log file
local function get_today_file()
    return config.log_folder .. "/" .. os.date("%m-%d-%Y") .. ".txt"
end

-- Load logs (disk → cache)
local function load_logs(force_reload)
    if config.cache_logs and cache_loaded and not force_reload then
        return logs_cache
    end

    logs_cache = {}
    cache_loaded = true

    for _, file in ipairs(minetest.get_dir_list(config.log_folder, false)) do
        local f = io.open(config.log_folder .. "/" .. file, "r")
        if f then
            for line in f:lines() do
                local data = minetest.deserialize(line)
                if data then
                    table.insert(logs_cache, data)
                end
            end
            f:close()
        end
    end

    -- Trim cache
    if #logs_cache > config.max_cached_logs then
        local excess = #logs_cache - config.max_cached_logs
        for i = 1, excess do
            table.remove(logs_cache, 1)
        end
    end

    return logs_cache
end

-- Log an event (disk + live cache)
local function log_event(playername, action, pos, node)
    local entry = {
        time = os.time(),
        player = playername,
        action = action,
        nodename = node.name,
        pos = {x = pos.x, y = pos.y, z = pos.z}
    }

    -- Write to file
    local f = io.open(get_today_file(), "a")
    if f then
        f:write(minetest.serialize(entry) .. "\n")
        f:close()
    end

    -- Update cache live
    if config.cache_logs then
        if not cache_loaded then
            load_logs(true)
        end

        table.insert(logs_cache, entry)

        if #logs_cache > config.max_cached_logs then
            table.remove(logs_cache, 1)
        end
    end
end

-- Particle visualization
local function show_region_particles(name)
    if not config.particle_enabled then return end
    local p1 = region_pos[name] and region_pos[name].pos1
    local p2 = region_pos[name] and region_pos[name].pos2
    if not p1 or not p2 then return end

    local minp = vector.new(
        math.min(p1.x, p2.x),
        math.min(p1.y, p2.y),
        math.min(p1.z, p2.z)
    )
    local maxp = vector.new(
        math.max(p1.x, p2.x),
        math.max(p1.y, p2.y),
        math.max(p1.z, p2.z)
    )

    for x = minp.x, maxp.x do
        for y = minp.y, maxp.y do
            for z = minp.z, maxp.z do
                if x == minp.x or x == maxp.x or
                   y == minp.y or y == maxp.y or
                   z == minp.z or z == maxp.z then
                    minetest.add_particle({
                        pos = {x = x + 0.5, y = y + 0.5, z = z + 0.5},
                        velocity = {x = 0, y = 0, z = 0},
                        acceleration = {x = 0, y = 0, z = 0},
                        expirationtime = config.particle_duration,
                        size = config.particle_size,
                        texture = "default_obsidian_glass.png^[colorize:" .. config.particle_color,
                        glow = config.particle_glow
                    })
                end
            end
        end
    end
end

-- Helpers
local function get_selected_pos(name, idx)
    return region_pos[name] and region_pos[name]["pos" .. idx]
end

-- Event hooks
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

-- Region commands
minetest.register_chatcommand("bw_set1", {
    description = "Set first corner",
    privs = {[config.admin_priv] = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        region_pos[name] = region_pos[name] or {}
        region_pos[name].pos1 = vector.round(player:get_pos())
        if region_pos[name].pos2 then show_region_particles(name) end
        return true, "First corner set."
    end
})

minetest.register_chatcommand("bw_set2", {
    description = "Set second corner",
    privs = {[config.admin_priv] = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        region_pos[name] = region_pos[name] or {}
        region_pos[name].pos2 = vector.round(player:get_pos())
        if region_pos[name].pos1 then show_region_particles(name) end
        return true, "Second corner set."
    end
})

-- /bw_check <player>
minetest.register_chatcommand("bw_check", {
    params = "<player>",
    description = "Show last 50 edits by player",
    privs = {[config.admin_priv] = true},
    func = function(_, param)
        if param == "" then return false, "Usage: /bw_check <player>" end
        local logs = load_logs()
        local out = {}

        for i = #logs, 1, -1 do
            local r = logs[i]
            if r.player == param then
                table.insert(out,
                    os.date("%Y-%m-%d %H:%M:%S", r.time) ..
                    " | " .. r.action ..
                    " | " .. r.nodename ..
                    " at (" .. r.pos.x .. "," .. r.pos.y .. "," .. r.pos.z .. ")"
                )
                if #out >= 50 then break end
            end
        end

        if #out == 0 then
            return true, "No edits found for " .. param
        end

        return true, table.concat(out, "\n")
    end
})

-- /bw_area
minetest.register_chatcommand("bw_area", {
    description = "Show edits inside selected region",
    privs = {[config.admin_priv] = true},
    func = function(name)
        local p1, p2 = get_selected_pos(name, 1), get_selected_pos(name, 2)
        if not p1 or not p2 then
            return false, "Use /bw_set1 and /bw_set2 first."
        end

        local minp = vector.min(p1, p2)
        local maxp = vector.max(p1, p2)

        local logs = load_logs()
        local out = {}

        for i = #logs, 1, -1 do
            local r = logs[i]
            local p = r.pos
            if p.x >= minp.x and p.x <= maxp.x and
               p.y >= minp.y and p.y <= maxp.y and
               p.z >= minp.z and p.z <= maxp.z then
                table.insert(out,
                    os.date("%Y-%m-%d %H:%M:%S", r.time) ..
                    " | " .. r.player .. " " .. r.action ..
                    " " .. r.nodename ..
                    " at (" .. p.x .. "," .. p.y .. "," .. p.z .. ")"
                )
                if #out >= config.max_undo_area then break end
            end
        end

        return true, #out > 0 and table.concat(out, "\n") or "No edits found."
    end
})

-- /bw_undo
minetest.register_chatcommand("bw_undo", {
    params = "player <name> [count] | area",
    description = "Undo block changes",
    privs = {[config.admin_priv] = true},
    func = function(name, param)
        local args = {}
        for w in param:gmatch("%S+") do table.insert(args, w) end
        if #args == 0 then return false, "Invalid usage." end

        local logs = load_logs()
        local changes = {}

        if args[1] == "player" then
            local pname = args[2]
            local count = tonumber(args[3]) or config.max_undo_player
            if not pname then return false, "Player name required." end

            for i = #logs, 1, -1 do
                if logs[i].player == pname then
                    table.insert(changes, logs[i])
                    if #changes >= count then break end
                end
            end

        elseif args[1] == "area" then
            local p1, p2 = get_selected_pos(name, 1), get_selected_pos(name, 2)
            if not p1 or not p2 then return false, "Set region first." end
            local minp = vector.min(p1, p2)
            local maxp = vector.max(p1, p2)

            for i = #logs, 1, -1 do
                local p = logs[i].pos
                if p.x >= minp.x and p.x <= maxp.x and
                   p.y >= minp.y and p.y <= maxp.y and
                   p.z >= minp.z and p.z <= maxp.z then
                    table.insert(changes, logs[i])
                    if #changes >= config.max_undo_area then break end
                end
            end
        else
            return false, "Invalid usage."
        end

        for _, r in ipairs(changes) do
            if r.action == "placed" then
                minetest.set_node(r.pos, {name = "air"})
            elseif r.action == "dug" then
                minetest.set_node(r.pos, {name = r.nodename})
            end
        end

        return true, "Undid " .. #changes .. " actions."
    end
})

minetest.log("action", "[blockwatcher] Loaded successfully.")
