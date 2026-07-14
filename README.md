# 🕶️ m3_illegaltablet — Crime Contracts System for ox_core

**A single tablet that turns the whole criminal underworld into a clean, contract‑driven progression system.**
Players pull out an illegal tablet, browse rotating jobs, run them solo or with a crew, level up two separate XP paths and climb a live leaderboard — all fully server‑authoritative and built natively for **ox_core**.

---

## ✨ Highlights

- 🎯 **20+ unique contracts** across 3 categories — Boosting, Burglaries and Robberies
- 📱 **Custom NUI tablet** — search, filter, contract offers, profile, live leaderboard
- 👥 **Full crew system** — invite by ID, configurable XP splits, kick, up to 4 players
- 📈 **Dual progression** — *Boosting XP* & *Burglary XP* unlock higher‑tier jobs
- 🔧 **Custom minigames** — lockpicking, hacking device, a heat/speed drill minigame & ATM hack
- 🔄 **Smart contract rotation** — cooldowns, per‑interval caps, recent‑job weighting, police‑count gating
- 🚓 **Dispatch ready** — cd / ps / qs / rcore / sonoran + a generic bridge
- 🧩 **Bridge‑based** — notify, dispatch and police layers are swappable without touching core code
- 🔒 **Server‑authoritative** — rewards, XP and validation all live on the server

---

## 🚗 Contracts

### Boosting *(vehicle theft — tiers D → S)*
Locate the target vehicle, lockpick it, and on higher tiers disable the tracker with a laptop hack before delivering it to a buyer. Five tiers (D/C/B/A/S) scale reward, difficulty and required Boosting XP. Includes spawn zones, multiple drop‑off points and optional tuning.

### Burglaries
Break into houses and warehouses with a lockpick, search the interior for the client's item, then hand it over to a fence NPC — keep the rest of the loot. Small house → House → Luxury house → Warehouse, gated behind Burglary XP.

### Robberies
| Job | What it is |
|-----|------------|
| 🏦 **Fleeca** | Bank vault hack → grab the cash carts |
| 💥 **Bobcat** | Armed weapon vault — clear guards, C4 the door, loot crates |
| 🚚 **Gruppe 6 Truck** | Chase & stop a moving cash truck, blow the rear doors |
| 💎 **Vangelico Jewelry** | Drill the entrance, smash the display cases |
| 🧪 **Humane Labs** | Chemical heist — hack in, loot crates, extract the research sample |
| 🏧 **ATM** | Solo hack/drill run across marked machines |
| 🛒 **Supermarket** | Intimidate the cashier for the bag |

---

## 👥 Crew System

- Invite any online player by their **4‑digit tablet ID**
- Up to **4 players** per crew (configurable)
- **XP share editor** — the leader decides how the reward XP is split (must total 100%)
- XP‑requirement checks so members can't join jobs they haven't unlocked
- Kick members, live crew UI updates, automatic cleanup on disconnect
- Crew‑wide rewards & notifications — every member is paid and notified when a job completes

---

## 📈 Progression

Two independent XP tracks, each with its own leaderboard tab and profile stat:

- **Boosting XP** → unlocks higher vehicle tiers (D → S)
- **Burglary XP** → unlocks tougher burglaries & robberies

Fully configurable tiers, unlock thresholds and reward ranges per contract.

---

## 🖥️ The Tablet

- Clean, responsive NUI interface
- Rotating **contract offers** with a configurable rotation timer
- **Search & filter** by contract type
- **Profile** page with a persistent 4‑digit player ID and rename option
- **Live leaderboard** (Top 10 — Boosting & Burglary)
- Custom in‑game **drill** and **lockpick** minigames with their own art

---

## 🔧 Requirements

| Dependency | Notes |
|-----------|-------|
| [ox_core](https://github.com/overextended/ox_core) | Framework |
| [ox_lib](https://github.com/overextended/ox_lib) | Required |
| [ox_inventory](https://github.com/overextended/ox_inventory) | Items & rewards |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |

> Built and tested on **lua54**. Runs entirely on the overextended stack — no ESX/QB layer required.

---

## 📦 Installation

1. Drop `m3_illegaltablet` into your `resources` folder.
2. Import the database schema:
   ```
   mysql> source sql/m3_illegaltablet.sql
   ```
3. Add the required **items** to `ox_inventory/data/items.lua`:
   ```lua
   ['illegal_tablet']  = { label = 'Tablet',            weight = 1000 },
   ['lockpick']        = { label = 'Lockpick',          weight = 100  },
   ['hacking_device']  = { label = 'Hacking Device',    weight = 200  },
   ['laptop_blue']     = { label = 'Hacking Laptop',    weight = 800  },
   ['thermite']        = { label = 'Thermite',          weight = 200  },
   ['jewelry']         = { label = 'Jewelry',           weight = 300  },
   ['moneybag']        = { label = 'Money Bag',         weight = 500  },
   ['weapon_cache']    = { label = 'Weapon Cache',      weight = 800  },
   ['house_loot']      = { label = 'Stolen Goods',      weight = 300  },
   ['container_goods'] = { label = 'Container Goods',   weight = 500  },
   ['warehouse_goods'] = { label = 'Warehouse Goods',   weight = 600  },
   ['contract']        = { label = 'Contract',          weight = 50   },
   ```
   *(Add `c4` and any weapon/tool items your config references.)*
4. Add to your `server.cfg`:
   ```
   ensure ox_lib
   ensure ox_core
   ensure ox_inventory
   ensure m3_illegaltablet
   ```

---

## ⚙️ Configuration

Everything lives in `config.lua`, fully commented‑free and grouped:

- **Open method** — item (`illegal_tablet`) and/or keybind (default `Z`)
- **Contract distribution** — rotation interval, offer count, per‑contract cooldowns, max per interval, recent weighting, minimum police online
- **XP tiers & unlocks** — Boosting tiers (D–S) and Burglary unlock thresholds
- **Every contract** — vehicles, spawn zones, drop‑offs, rewards, XP, required items, time limits
- **Bridges** — `Config.Notify`, `Config.Dispatch`, `Config.PoliceGroups`
- **Items, anims & minigame tuning**

```lua
Config.Dispatch      = 'cd_dispatch'   -- cd / ps / qs / rcore / sonoran / default
Config.Notify        = 'ox_lib'
Config.PoliceGroups  = { 'police', 'lspd', 'bcso', 'sasp' }
```

---

## 🔌 Bridges

Notify, dispatch and police checks are isolated in `bridge/`. Switch systems with one config line, or drop in your own file — the core never needs editing.

- **Dispatch:** cd_dispatch, ps-dispatch, qs-dispatch, rcore_dispatch, sonoran_cad, default
- **Notify:** ox_lib (extendable)
- **Police:** ox_core groups

---

## 🗄️ Database

A single table (`m3_tablet`) stores the player's tablet ID, name, **Boosting XP**, **Burglary XP**, active filters and current offers. Nothing else touched.

---

## 🧠 Notes

- Guards spawn as **client‑local peds** with server‑synced death state to prevent MLO clone fall‑through and desync.
- All rewards, XP and unlock checks are validated **server‑side**.
- Fully localizable via `locales/*.lua`.

---

## 💬 Support

Found a bug or want a feature? Reply below or reach out on Discord.

| | |
|---|---|
| **Framework** | ox_core |
| **Code is** | Not obfuscated / configurable |
| **Requirements** | ox_lib, ox_core, ox_inventory, oxmysql |
| **Support** | Yes |
