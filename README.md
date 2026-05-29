# CAEF Nexus
*A modular Discord bot handler for Foxhole, built on the Discordia API*

[![Discordia](https://img.shields.io/badge/Discordia-v3.0-blue)](https://github.com/SinisterRectus/Discordia)
[![Lua](https://img.shields.io/badge/Lua-5.4-yellow)](https://www.lua.org/)
[![Foxhole](https://img.shields.io/badge/Foxhole-Active-red)](https://www.foxholegame.com/)

---

## 📌 Overview
CAEF Nexus is a **Discord bot framework** designed specifically for **Foxhole** communities. It provides a **plug-and-play modular system** for managing in-game logistics, tracking resources, and facilitating communication between players.

Built on the **Discordia API**, CAEF Nexus offers:
✅ **Real-time Foxhole API integration** (detailed info provided on war status)
✅ **Resource tracking** (fuel, supplies, stockpiles)
✅ **Role-based reaction systems** (quick role selection)
✅ **Customizable goal tracking** (regiment progress, rare collection)
✅ **Modular architecture** (easy to extend with new features)

---

## 🛠️ Features
### 🔹 Core Modules
| Module | Description |
|--------|-------------|
| **Supply Tracker** | Monitors Maintenance Supplies and generator fuel levels, giving an estimate to when they drop. |
| **Stockpile Manager** | Tracks stockpile reserves and predicts time till they expire. |
| **Role Reaction System** | Simplified role selection for general discord. |
| **Goal Summaries** | Tracks regiment progress (e.g., track collectively how many rares mined). |
| **Foxhole API Integration** | Fetches real-time war data provided. |

### 🔹 Additional Features
- **Plug-and-play modules** (load on startup, share data seamlessly)
- **Customizable alerts** (notifications for when stockpiles are about to expire)
- **Modular architecture** (easy to add new features and commands with easy examples of organization)

---

## 🚀 Getting Started
### Prerequisites
- **Lua 5.2**
- **Discordia v3.0+** (included)

### Installation
1. Clone the repository:
   ```sh
   git clone https://github.com/Umbriee/CAEF-Nexus
   cd CAEF-Nexus
   ```
2. Install dependencies (if any):
   ```sh
   luarocks install discordia
   ```
3. Configure `config.lua` with your Discord bot token and Foxhole API key.
4. Run the bot:
   ```sh
   lua main.lua
   ```

---

## 📂 Project Structure
```
CAEF-Nexus/main/
├── modules/          # Modular components
│   ├── module/       # module name, unique and lowerish case
│   └─── shared.lua   # loads this file for info. Can include others per example 'upkeep' module.
├── libs/             # Core libraries
└── war.lua           # Entry point
```

---

## 🤝 Contributing
Contributions are welcome! Open an issue or submit a pull request.

---

### 🔗 Links
- [Discordia API](https://github.com/SinisterRectus/Discordia) (Core framework)
- [Foxhole Game](https://www.foxholegame.com/) (Game this bot supports)

---

This version improves readability, adds structure, and makes it more appealing to potential contributors or users.