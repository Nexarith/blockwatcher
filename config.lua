-- blockwatcher/config.lua
-- Configuration template for BlockWatcher mod

BlockWatcherConfig = {
    -- Logging
    log_folder = minetest.get_worldpath() .. "/blockloader",
    max_daily_log_size = 1024*1024*5, -- 5 MB per day before rotating (optional)

    -- Particles
    particle_enabled = true,
    particle_duration = 3,          -- seconds
    particle_size = 4,
    particle_color = "#0000FF:80",  -- default: semi-transparent blue
    particle_glow = 10,

    -- Undo
    max_undo_player = 50,          -- max actions to undo per player
    max_undo_area = 100,           -- max actions to undo per region
    undo_preview = false,          -- show changes before applying
    preserve_metadata = true,      -- attempt to preserve node metadata on undo

    -- Privileges
    admin_priv = "blockwatcher_admin",
    view_priv = "blockwatcher_view", -- optional: read-only access

    -- Performance
    cache_logs = true,             -- keep logs in memory for faster access
    max_cached_logs = 10000,       -- number of log entries to cache
}
