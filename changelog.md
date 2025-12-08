# BlockWatcher Changelog

All notable changes to BlockWatcher mod.

---

## [1.0] – 2025-12-08
**Initial Release**
- Fully standalone logging of all block digs and placements
- Daily log files stored in `worlds/<world_name>/blockloader/`
- Region selection commands: `/bw_set1` and `/bw_set2`
- Particle visualization for selected region boundaries
- Player-specific log review: `/bw_check <player>`
- Region-specific log review: `/bw_area`
- Undo system:
  - `/bw_undo player <name> [count]`
  - `/bw_undo area`
- Admin privilege: `blockwatcher_admin`
- No dependencies; works out-of-the-box

---

## Planned / Future
- Undo preview mode
- Named region save/load
- Configurable particle color, duration, and toggle
- Log rotation and JSON export
- Formspec-based UI for log browsing
- Real-time audit mode / Discord webhook alerts
- Rate-limiting and protection for undo commands
