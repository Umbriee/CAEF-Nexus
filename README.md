# Disco of War
#### "*Discords of War Terminal*"
"*A modular Discord bot handler for servers, built on the Discordia API*"

[![Discordia](https://img.shields.io/badge/Discordia-v3.0-blue)](https://github.com/SinisterRectus/Discordia)
[![Lua](https://img.shields.io/badge/Lua-5.4-yellow)](https://www.lua.org/)

---

## 📌 Overview
Disco of War is a **Discord Bot**(.. Or application?) designed specifically for a Discord Server. It provides a **plug-and-play modular system** for managing, automation, and other such that I decide to add.

Built on the **Discordia API**, DoW offers:
✅ **Role-based reaction systems** (quick role selection)
✅ **Modular architecture** (easy to extend with new features)

---

## 🛠️ Features
### 🔹 Core Modules
| Module | Description |
|--------|-------------|
| **Role Reaction System** | Simplified role selection for general discord. |

### 🔹 Additional Features
- **Plug-and-play modules** (load on startup, share data seamlessly)
- **Modular architecture** (easy to add new features and commands with easy examples of organization)

---

## 📂 Project Structure
```
DoW/main/
├── modules/          # Modular components
│   ├── module/       # module name, unique and lowerish case
│   └─── shared.lua   # loads this file for info. Can include others per example 'admin' module.
├── libs/             # Core libraries
└── war.lua           # Entry point
```

---

## 🤝 Contributing
Contributions are welcome! Open an issue or submit a pull request.

---

### 🔗 Links
- [Discordia API](https://github.com/SinisterRectus/Discordia) (Core framework)
---