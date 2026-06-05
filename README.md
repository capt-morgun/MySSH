# MySSH — SSH Manager for macOS

A macOS app for managing SSH connections. Select any IP or hostname anywhere on your screen — in a browser, log, or terminal — press a hotkey, and connect instantly. Import your infrastructure from `~/.ssh/config` or Ansible inventory in one click.

<img src="screenshots/main.png" width="600">

---

## Features

- **One-click connect** — open any SSH session in your preferred terminal with a single click
- **Server list** — organize connections by groups with aliases, hostnames, users, ports, and SSH keys
- **EasyConnect** — select any IP or hostname in any app, press a hotkey, and instantly open an SSH connection
- **Multiple terminals** — supports Terminal.app, iTerm2, Warp, and Alacritty; opens in a new tab if the terminal is already running
- **Import** — import hosts from `~/.ssh/config` or Ansible inventory files
- **Appearance** — customize fonts and colors to your taste
- **iCloud sync** — your server list is stored in iCloud Drive and available across your Macs

---

## Settings

### General
<img src="screenshots/settings-general.png" width="400">

### Appearance
<img src="screenshots/settings-appearance.png" width="400">

### EasyConnect
<img src="screenshots/settings-easyconnect.png" width="400">

---

## Installation

1. Download the latest `MySSH.dmg` from [Releases](../../releases)
2. Open the DMG, drag **MySSH** to **Applications**
3. Launch MySSH — it appears in the menu bar

> **EasyConnect** requires Accessibility permission. You will be prompted on first use — grant access in **System Settings → Privacy & Security → Accessibility**.

---

## EasyConnect

EasyConnect lets you select an IP address or hostname anywhere — in a browser, terminal, text editor — and connect to it instantly via hotkey.

1. Open **Settings → EasyConnect**
2. Enable EasyConnect and set a hotkey (default: `⌘⇧E`)
3. Grant Accessibility access when prompted
4. Select any IP or hostname in any app and press your hotkey

---

## Import

**From `~/.ssh/config`:** Settings → General → Import from ~/.ssh/config

**From Ansible inventory:** toolbar import button → Import from Ansible hosts...

```
[web_servers]
web1 ansible_host=192.168.1.10 ansible_user=ubuntu
web2 ansible_host=192.168.1.11
```

---

## Requirements

- macOS 14 or later
- Accessibility permission (for EasyConnect only)

---

## License

MIT

---

[Русская версия](README.ru.md)
