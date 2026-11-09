# ⚡ Roblox AI Copilot

[![Roblox Studio](https://img.shields.io/badge/Roblox_Studio-Plugin-00A2FF?style=for-the-badge&logo=roblox&logoColor=white)](https://create.roblox.com/marketplace)
[![Luau](https://img.shields.io/badge/Language-Luau_Strict-00599C?style=for-the-badge)](https://luau-lang.org/)
[![Rojo](https://img.shields.io/badge/Built_with-Rojo_7.7-E03C11?style=for-the-badge)](https://rojo.space/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

> **The next-generation AI Copilot built natively for Roblox Studio.**  
> Generate production-ready Luau scripts, build 3D procedural scenes from text, and audit code for exploits & memory leaks — all inside Roblox Studio with 1-click `Ctrl+Z` support.

---

## 🌟 Why Roblox AI Copilot?

Building games on Roblox is fast, but writing boilerplate Luau code, setting up DataStores with retry logic, and building repetitive blockout maps can take hours. **Roblox AI Copilot** brings state-of-the-art AI directly into your Studio workflow with zero bloat.

### 🚀 Key Features

| Feature | Description |
|---|---|
| **⚡ Prompt-to-Luau** | Write natural prompts (Thai/English) like *"DataStore currency system with anti-exploit"* or *"Double jump with trail VFX"*. Generates `--!strict` Luau and inserts into `ServerScriptService` or `StarterPlayerScripts` with 1 click! |
| **🏗️ Text-to-World Builder** | Describe a 3D scene (e.g. *"Gladiator arena with 8 marble pillars, central spawn, and torch neon lights"*). Copilot procedurally generates Parts, Materials, Colors, and Welds into `Workspace` instantly. |
| **🛡️ Exploit & Security Auditor** | Select any script in Explorer and click **Audit**: Scans for client-trust vulnerabilities on `RemoteEvent.OnServerEvent`, missing `pcall` on DataStores, and deprecated 30Hz `wait()` calls. |
| **🎨 Native Dockable Studio UI** | Clean, responsive dock widget that automatically adapts to Studio **Dark Theme** and **Light Theme**. |
| **🤖 Multi-Engine Support** | Connect to **Google Gemini** (Free tier supported), **Groq** (Ultra-fast Llama-3.3-70B), **DeepSeek**, or offline **Local Ollama** (100% private, runs on your PC). |

---

## 📦 Quick Installation (30 Seconds)

### Option 1: Standalone Plugin File (`.rbxm`) - Easiest!
1. Download **`roblox-ai-copilot.rbxm`** from the [Latest Release](https://github.com/pacjung64-cmyk/roblox-ai-copilot/releases).
2. Open **Roblox Studio**.
3. In Windows Explorer, copy `roblox-ai-copilot.rbxm` to your Studio plugins directory:
   ```text
   %localappdata%\Roblox\Plugins
   ```
   *(Or simply drag and drop `roblox-ai-copilot.rbxm` into any open place in Roblox Studio and click **Save as Local Plugin**).*
4. Look for the **"Roblox AI Copilot"** button in your Studio toolbar ribbon!

---

### Option 2: Build from Source with Rojo
```bash
# 1. Clone repository
git clone https://github.com/pacjung64-cmyk/roblox-ai-copilot.git
cd roblox-ai-copilot

# 2. Build .rbxm plugin
rojo build -o roblox-ai-copilot.rbxm

# 3. Or install directly into local Studio plugins folder
rojo build --plugin roblox-ai-copilot.rbxm
```

---

## ⚙️ Setting Up Your AI Provider

Roblox AI Copilot talks directly to your chosen AI engine through Roblox Studio's `HttpService`:

1. In Roblox Studio, make sure HTTP requests are enabled:  
   **Home** → **Game Settings** → **Security** → Turn on **Allow HTTP Requests**.
2. Open the Copilot widget and click the **⚙️ Config** tab:
   - **Google Gemini**: Get a free API key at [Google AI Studio](https://aistudio.google.com/) and paste it.
   - **Groq**: Ultra-fast inference with Llama 3.3. Get a free API key at [console.groq.com](https://console.groq.com/).
   - **Local Ollama**: Run models locally (e.g. `ollama run qwen2.5-coder:7b`). Zero internet required!
3. Click **💾 Save Settings** (credentials are saved safely in your local Studio plugin storage).

---

## 🛠️ Architecture & Project Structure

```text
roblox-ai-copilot/
├── src/
│   ├── init.server.luau        # Main plugin entry point (Toolbar & Ribbon)
│   ├── Core/
│   │   ├── Types.luau          # Strict Luau type definitions
│   │   ├── SettingsManager.luau# Persistent plugin settings storage
│   │   ├── PromptTemplates.luau# Expert system prompts & strict rules
│   │   └── AIClient.luau       # Multi-provider HTTP client (Gemini/Groq/Ollama)
│   ├── Features/
│   │   ├── ScriptGenerator.luau# Luau generator & Studio insertion engine
│   │   ├── SceneBuilder.luau   # 3D procedural Workspace builder
│   │   └── SecurityAuditor.luau# Exploit & vulnerability scanner
│   └── UI/
│       └── PluginWidget.luau   # Theme-reactive Studio dockable widget
├── tests/
│   └── test_security_auditor.js# Regression unit tests
├── default.project.json        # Rojo 7.7 build definition
└── roblox-ai-copilot.rbxm      # Compiled standalone plugin binary
```

---

## 🛡️ Security & Exploit Prevention

Roblox AI Copilot follows strict defense-in-depth principles:
- **Never trusts client input**: Generated server scripts validate parameters, cooldowns, and distances.
- **DataStore fault tolerance**: Generates automatic `pcall` wrappers and retry logic.
- **ChangeHistoryService integration**: Every script inserted or scene built creates an undo waypoint (`Ctrl+Z`).

---

## 📄 License

MIT License. Free for indie developers, studios, and content creators. Contributions and pull requests are welcome!
