# ArkTV - IPTV for ArkOS
![](https://github.com/AeolusUX/ArkTV/blob/main/ArkTV.png)

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

## License

ArkTV is licensed under the MIT License.

This project uses [mpv](https://mpv.io/), which is licensed under GPLv2 or later by default  
(or LGPLv2.1 or later if built with `-Dgpl=false`). Please see [mpv's license details](https://mpv.io/) for more information.
