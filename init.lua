-- blockwatcher/init.lua
-- Logs every block dig/place on the server
-- Author: Cashia ©2025

local sqlite = require("lsqlite3")

-- Path to SQLite database
local db_path = minetest.get_worldpath() .. "/blockwatch.db"
local db = sqlite.open(db_path)

-- Create table if not exists
db:exec([[
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    time INTEGER,
    player TEXT,
    action TEXT,
    nodename TEXT,
    x INTEGER,
    y INTEGER,
    z INTEGER
);
]])

-- Function to log events
local function log_event(playername, action, pos, node)
    local stmt = db:prepare([[
        INSERT INTO logs (time, player, action, nodename, x, y, z)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    ]])
    stmt:bind_values(
        os.time(),
        playername,
        action,
        node.name,
        pos.x, pos.y, pos.z
    )
    stmt:step()
    stmt:finalize()
end

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

-- /bw_check <player> command
minetest.register_chatcommand("bw_check", {
    params = "<player>",
    description = "Show block edits made by a specific player",
    privs = {server=true},
    func = function(name, param)
        if param == "" then
            return false, "Usage: /bw_check <player>"
        end

        local player = param
        local q = db:prepare([[
            SELECT time, action, nodename, x, y, z 
            FROM logs
            WHERE player = ?
            ORDER BY id DESC
            LIMIT 50;
        ]])
        q:bind_values(player)

        local result = {}
        for row in q:nrows() do
            table.insert(result,
                os.date("%Y-%m-%d %H:%M:%S", row.time) ..
                " | " .. row.action .. " | " .. row.nodename ..
                " at (" .. row.x .. "," .. row.y .. "," .. row.z .. ")"
            )
        end

        q:finalize()

        if #result == 0 then
            return true, "No edits found for player " .. player
        end

        return true, table.concat(result, "\n")
    end,
})

-- Helper function to get WorldEdit positions
local function get_pos(name, pos)
    local we = rawget(_G, "worldedit")
    if we and we.pos and we.pos[name] then
        return we.pos[name][pos] and vector.new(we.pos[name][pos]) or nil
    end
    return nil
end

-- /bw_area command
minetest.register_chatcommand("bw_area", {
    description = "Show edits inside a selected region (use //set1 and //set2 from WorldEdit)",
    privs = {server=true},
    func = function(name)
        local p1 = get_pos(name, 1)
        local p2 = get_pos(name, 2)

        if not p1 or not p2 then
            return false, "Set positions with //set1 and //set2 first!"
        end

        local minp = {
            x = math.min(p1.x, p2.x),
            y = math.min(p1.y, p2.y),
            z = math.min(p1.z, p2.z)
        }
        local maxp = {
            x = math.max(p1.x, p2.x),
            y = math.max(p1.y, p2.y),
            z = math.max(p1.z, p2.z)
        }

        local q = db:prepare([[
            SELECT time, player, action, nodename, x, y, z 
            FROM logs
            WHERE x BETWEEN ? AND ?
            AND y BETWEEN ? AND ?
            AND z BETWEEN ? AND ?
            ORDER BY id DESC
            LIMIT 100;
        ]])
        q:bind_values(minp.x, maxp.x, minp.y, maxp.y, minp.z, maxp.z)

        local result = {}
        for row in q:nrows() do
            table.insert(result,
                os.date("%Y-%m-%d %H:%M:%S", row.time) ..
                " | " .. row.player .. " " .. row.action ..
                " " .. row.nodename ..
                " at (" .. row.x .. "," .. row.y .. "," .. row.z .. ")"
            )
        end

        q:finalize()

        if #result == 0 then
            return true, "No edits found in this region."
        end

        return true, table.concat(result, "\n")
    end,
})
-- /bw_undo command
-- Usage examples:
-- /bw_undo player <name> [count]  -> undo last X actions of a player
-- /bw_undo area                   -> undo last actions in selected region (WorldEdit //set1 & //set2)

minetest.register_chatcommand("bw_undo", {
    params = "[player <name> [count]] | [area]",
    description = "Undo block changes by player or in area",
    privs = {server=true},
    func = function(name, param)
        local args = {}
        for word in param:gmatch("%S+") do table.insert(args, word) end

        if #args == 0 then
            return false, "Usage: /bw_undo player <name> [count] OR /bw_undo area"
        end

        -- Undo by player
        if args[1] == "player" then
            local player_name = args[2]
            local count = tonumber(args[3]) or 50

            if not player_name then return false, "Specify player name!" end

            local q = db:prepare([[
                SELECT x, y, z, action, nodename
                FROM logs
                WHERE player = ?
                ORDER BY id DESC
                LIMIT ?;
            ]])
            q:bind_values(player_name, count)

            local changes = {}
            for row in q:nrows() do
                table.insert(changes, row)
            end
            q:finalize()

            for _, row in ipairs(changes) do
                local pos = {x=row.x, y=row.y, z=row.z}
                if row.action == "placed" then
                    -- undo placement -> remove node
                    minetest.set_node(pos, {name="air"})
                elseif row.action == "dug" then
                    -- undo dig -> restore node
                    minetest.set_node(pos, {name=row.nodename})
                end
            end

            return true, "Undid " .. #changes .. " actions for player " .. player_name

        -- Undo in area
        elseif args[1] == "area" then
            local p1 = get_pos(name, 1)
            local p2 = get_pos(name, 2)

            if not p1 or not p2 then
                return false, "Set positions with //set1 and //set2 first!"
            end

            local minp = {
                x = math.min(p1.x, p2.x),
                y = math.min(p1.y, p2.y),
                z = math.min(p1.z, p2.z)
            }
            local maxp = {
                x = math.max(p1.x, p2.x),
                y = math.max(p1.y, p2.y),
                z = math.max(p1.z, p2.z)
            }

            local q = db:prepare([[
                SELECT x, y, z, action, nodename
                FROM logs
                WHERE x BETWEEN ? AND ?
                AND y BETWEEN ? AND ?
                AND z BETWEEN ? AND ?
                ORDER BY id DESC
                LIMIT 100;
            ]])
            q:bind_values(minp.x, maxp.x, minp.y, maxp.y, minp.z, maxp.z)

            local changes = {}
            for row in q:nrows() do
                table.insert(changes, row)
            end
            q:finalize()

            for _, row in ipairs(changes) do
                local pos = {x=row.x, y=row.y, z=row.z}
                if row.action == "placed" then
                    minetest.set_node(pos, {name="air"})
                elseif row.action == "dug" then
                    minetest.set_node(pos, {name=row.nodename})
                end
            end

            return true, "Undid " .. #changes .. " actions in selected area"

        else
            return false, "Invalid parameters. Usage: /bw_undo player <name> [count] OR /bw_undo area"
        end
    end,
})

minetest.log("action", "[blockwatcher] Loaded successfully.")
