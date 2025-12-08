# blockwatcher-

**Author:** Cashia
**Version:** 1.0  
**Minetest Version:** 5.0+  
**Dependencies:** WorldEdit (required for `/bw_area`)  

---

## Overview

**BlockWatcher** is a lightweight but powerful Minetest mod that logs **all block placements and digs** on your server.  
It provides forensic-level tools to track player activity and undo griefing, similar to CoreProtect for Minecraft.

Key features include:

- Real-time logging of all block digs and placements  
- Player-specific history lookup: `/bw_check <player>`  
- Region-specific history using WorldEdit positions: `/bw_area`  
- Undo/rollback functionality: `/bw_undo player <name> [count]` or `/bw_undo area`  
- SQLite database storage for fast, searchable logs  

---

## Installation

1. Place the `blockwatcher` folder in your `mods/` directory.  
2. Enable it in your `world.mt`:

   ```
   load_mod_blockwatcher = true
   ```

3. Make sure WorldEdit is installed if you want to use `/bw_area`.  
4. Start your server. You should see:

```
[blockwatcher] Loaded successfully.
```

---

## Commands

### `/bw_check <player>`

Shows the last 50 block edits by a specific player.

Example:

```
/bw_check Shasha
```

### `/bw_area`

Shows the last 100 block edits in a WorldEdit-defined region (//set1 and //set2).

Example:

```
/set1
/set2
/bw_area
```

### `/bw_undo player <name> [count]`

Undoes the last X actions by a player (default 50).

Example:

```
/bw_undo player Gera 20
```

### `/bw_undo area`

Undoes the last 100 actions in a WorldEdit-selected region.

Example:

```
/bw_undo area
```

---

## Logs

All events are saved in:

```
worlds/<your_world_name>/blockwatch.db
```

Stored in SQLite format for fast searches and retrieval.

---

## Notes

- `/bw_area` and `/bw_undo area` require WorldEdit to define regions.  
- Undo commands are safe but always check the affected region before mass rollbacks.  
- The mod works even without WorldEdit; only region-based commands are disabled.  

---

## Future Features

- Auto-purge old logs  
- Discord alerts for griefing  
- Web-based dashboard for log visualization  
- Rollback by time or custom filters  

---

Enjoy tracking your players like a true server detective! 🔍
