# Nguyen's AI — Gemini Edition (Windows Computer Control)

A fast local Windows automation assistant powered by the **Google Gemini API** (`gemini-3.5-flash`).
Automates real mouse movement and keyboard input with continuous screen vision analysis.

---

## Quick Start (Two Ways to Run)

### Method 1: Command Prompt / CLI (Recommended & Fastest)
1. Double-click `run.bat`.
2. Paste your Google Gemini API Key when prompted (encrypted safely via Windows DPAPI).
3. Type your task (e.g. `Open Notepad and type hello world` or `Mở trình duyệt và tìm thời tiết`).
4. (Optional) Provide a path to a reference image if desired.
5. Press **ENTER** — the real mouse cursor glides smoothly to elements and executes the task!

### Method 2: Web Control Panel
1. Double-click `web.bat`.
2. Your browser opens automatically at `http://127.0.0.1:8765/`.
3. Configure your Gemini API key in Settings.
4. Type prompt, attach reference images, and click **Authorize Once**.

---

## Emergency Stop Shortcuts
- **Ctrl + Fn + E** (or **Ctrl + E**): Instant hardware abort in under 30ms.
- **Fail-safe screen corner**: Slam the physical mouse into the top-left corner (0, 0).
- **Stop script**: Double-click `stop.bat`.
- **In CLI**: Press **Ctrl + C**.

---

## Key Features
- **Strict Bilingual Engine (English & Accented Vietnamese)**:
  * When asked in Vietnamese, replies with full diacritics and correct grammar (Tiếng Việt có dấu đầy đủ).
  * When asked in English, replies in natural English.
- **Persistent Memory Engine (`data/memory.json`)**:
  * Automatically saves rules containing "nhớ" or "remember" into permanent memory.
  * Reinforces output for all actions containing "làm" or "do/execute".
- **Simplified 1-Click Launch (`run.bat`)**: Single streamlined launcher for Command Prompt (redundant `cli.bat` removed).
- **Laser-Accurate Mouse Grounding**: Compensates for Windows DPI scaling (125%, 150%, 200%) and enforces strict coordinate validation between thinking and actions.
- **Continuous 10 FPS Loop**: Low-latency screen capture and purposeful mouse gliding (Cubic Ease-out).
- **Emergency Abort (`Ctrl + Fn + E`)**: Hardware interrupt within 30ms.

---

## Package Files Included
- `run.bat`: 1-click launcher for Command Prompt mode.
- `web.bat`: 1-click launcher for the browser web interface.
- `stop.bat`: Emergency stop trigger.
- `NguyeensCLI.ps1`: Interactive Windows console automation loop with memory viewer.
- `NguyeensAI.ps1`: Embedded Windows web server, REST API (`/api/memory`), and DPAPI key management.
- `worker.ps1`: Continuous screen capture, memory persistence, bilingual reasoning, and mouse/keyboard engine.
- `web/index.html`: Local web interface with memory manager and image upload support.
- `data/memory.json`: Persistent user memory storage.
- `data/settings.json`: Configuration store.
- `HUONG_DAN_SU_DUNG.txt`: Vietnamese instruction guide.
- `README.md` / `USER_GUIDE.txt`: English instruction guide.
