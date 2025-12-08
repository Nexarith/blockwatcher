# BlockWatcher TODO

**Author:** Shasha  
**Version:** 1.0  

---

## Core Features
- [x] Log all block digs  
- [x] Log all block placements  
- [x] Store logs in SQLite database  
- [x] `/bw_check <player>` command  
- [x] `/bw_area` command (WorldEdit required)  
- [x] `/bw_undo player <name> [count]` command  
- [x] `/bw_undo area` command (WorldEdit required)  
- [x] Admin privilege `blockwatcher_admin` implemented  

---

## Improvements / Optimizations
- [ ] Optimize SQLite queries for large worlds  
- [ ] Add undo progress feedback for large rollbacks  
- [ ] Limit memory usage during bulk queries  
- [ ] Add configurable log retention / auto-purge  

---

## User Experience
- [ ] Make `/bw_check` available to players to view their own edits safely  
- [ ] Add colored output for console readability  
- [ ] Add optional notifications for players when undo affects them  

---

## Security / Safety
- [ ] Ensure undo commands cannot break protected regions  
- [ ] Add dry-run option to preview undo before applying  
- [ ] Add rate-limiting for undo commands  

---

## Future Features
- [ ] Discord alerts for griefing events  
- [ ] Web-based dashboard to visualize edits  
- [ ] Rollback by time, date, or custom filters  
- [ ] Backup logs automatically before large undo operations  

---

## Miscellaneous
- [ ] Write unit tests for logging and undo functionality  
- [ ] Add example configuration in `world.mt`  
- [ ] Document mod setup for multi-world servers
