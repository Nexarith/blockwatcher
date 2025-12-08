# BlockWatcher – TODO List
**Author:** Cashia         
**Version:** 1.0  

Tracking remaining tasks, improvements, and future upgrades for the mod.

---

## ✔ Core Features Implemented
- [x] Block dig/place logging saved into daily files  
- [x] Region selection using `/bw_set1` and `/bw_set2`  
- [x] Particle visualization for region boundaries  
- [x] Player-specific checks with `/bw_check <name>`  
- [x] Region-specific checks with `/bw_area`  
- [x] Undo system for both players and regions  
- [x] Fully standalone; no dependencies  

---

## 🔧 Must-Do Enhancements
### Logging
- [ ] Add rotation cleanup (auto-delete logs older than X days)
- [ ] Add optional JSON log output for external tools

### Undo System
- [ ] Add a **preview mode** before undo applies changes  
- [ ] Add an **undo confirmation prompt**  
- [ ] Add rollback protection to prevent infinite loops (undoing your own undo)

### Region Tools
- [ ] Add option to **clear** region selection (`/bw_clear`)  
- [ ] Add region **save/load** commands (named regions)  
- [ ] Let players use a tool (stick or wand) for setting pos1/pos2

---

## 🎨 Particle Visualization
- [ ] Add config setting for particle duration  
- [ ] Add different colors for pos1 and pos2  
- [ ] Add toggle: `/bw_preview` to permanently show region edges until turned off  

---

## ⚙️ Config & Optimization
- [ ] Add a setting to limit log size per day  
- [ ] Add a config file:  
  - enable/disable particles  
  - change max undo count  
  - toggle logging for admins  
- [ ] Improve load_logs() performance using a cached index  

---

## 🛡 Privileges & Security
- [ ] Add `blockwatcher_view` privilege (read-only access)  
- [ ] Add rate-limit protection for undo and area scans  
- [ ] Prevent undo from placing protected nodes

---

## 🖥 UI Upgrades (Optional)
- [ ] Create a formspec-based UI for browsing logs  
- [ ] Make a paginated log viewer inside Minetest  
- [ ] Add clickable buttons for undo / region preview  

---

## 🧪 Testing
- [ ] Test behavior under heavy load (1000+ logs/day)  
- [ ] Test very large regions (100×100×100)  
- [ ] Test node metadata survival when undoing  
- [ ] Test undoing liquids, falling nodes, and special blocks  

---

## 📦 Future Features
- [ ] Export logs to `/bw_export` command  
- [ ] Discord webhook integration for real-time alerts  
- [ ] Add "audit mode" where admins see edits live  
- [ ] Add `/bw_trace <player>` to track them in real time  

---

## 📝 Documentation
- [ ] Add usage examples with screenshots  
- [ ] Add FAQ section to README  
- [ ] Add developer documentation for log format  

---

## 🐛 Known Issues
- [ ] Undoing a very large area can lag the server  
- [ ] Particle preview may not render on some clients  
- [ ] Some nodes (like furnaces) may lose metadata on undo  
- [ ] Logs grow large over time — indexing system needed
