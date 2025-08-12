# ArkTV

ArkTV is a simple, terminal-based IPTV player for Linux devices, built with bash and powered by [mpv](https://mpv.io/).  
It lets you browse and stream internet TV channels using an intuitive menu interface with joystick support, ideal for retro handhelds and embedded devices.

---

## Features

- Channel selection menu via `dialog`
- Plays live streams with `mpv` in fullscreen mode
- Supports joystick/gamepad input through `gptokeyb`
- Auto installs missing dependencies (`mpv`, `dialog`, `jq`, `curl`)
- Fetches channel lists dynamically from a JSON file hosted on GitHub


---

## Installation

1. Download or copy the `ArkTV.sh` script.

2. Paste the script into your device's **tools** or **ports** folder (where you keep executable scripts).

3. Make the script executable:

   ```bash
   chmod +x ArkTV.sh
