<img src="assets/icon.png" width="140" height="140">

# Browser-Cleaner

Interactive browser cleaner for Linux: it detects what you have installed, lets you choose what to delete, and never touches your user data — profiles, bookmarks, passwords or extensions.

[Español](README.es.md)

![Bash 4+](https://img.shields.io/badge/bash-%3E%3D4.0-4EAA25?logo=gnubash&logoColor=white) ![Linux Mint 22.3 Cinnamon](https://img.shields.io/badge/Linux%20Mint-22.3%20Cinnamon-87CF3E?logo=linuxmint&logoColor=white) ![GPLv3 License](https://img.shields.io/badge/license-GPLv3-blue)

---

## The problem it solves

Over time, every browser accumulates cache, history, cookies, sessions and temporary files that only take up space and provide nothing useful. Cleaning them by hand means opening each browser's settings separately — and if you use several, repeating the process in each one. Generic "system cleaning" tools, on the other hand, do not always make it clear exactly what they touch, creating a real risk of deleting bookmarks or saved sessions.

Browser-Cleaner detects which browsers you have installed, lets you choose which ones and what to clean, and tells you how much space you are going to recover before deleting anything.

<img width="655" height="435" alt="browser-cleaner-menu" src="https://github.com/user-attachments/assets/9039ec58-c20b-47d6-ba8d-99fdc039e010" />

## What it does exactly

- Automatically detects supported browser profiles in native, Flatpak or Snap layouts and how many profiles each one has.
- Six cleaning types to choose from: quick, complete, cache only, cookies only, history only or deep (see [Cleaning types](#cleaning-types)).
- Preview and explicit confirmation before any irreversible deletion.
- Automatically backs up critical files before modifying them.
- Checks that the browser is closed before cleaning its profiles, to avoid corrupting anything while it is still writing.
- If `sqlite3` or `jq` are missing — they are used to clean history, form data and permissions precisely — it offers to install them with `apt` automatically; if you decline or installation fails, that part is simply skipped without aborting the rest.
- It is not intended to run as root: it cleans your own `$HOME`, and warns you if you launch it with `sudo` by mistake.
- Logs each session (date, what was cleaned, how much space was freed) to `~/.cache/browser-cleaner/browser-cleaner.log`.
- Clear terminal interface with a progress spinner and summary tables showing recovered space by category and browser.

## Advantages

Most cleaners treat the browser like just another folder: they delete by age or size, without distinguishing what belongs to you from what is disposable. Browser-Cleaner follows a fixed rule rather than heuristics: it preserves everything that identifies you as a user, and deletes only what the browser can regenerate on its own or what is simply browsing residue.

| Always preserved | Deleted (depending on your choice) |
|---|---|
| Profiles and configuration | Cache and thumbnails |
| Bookmarks | Browsing history |
| Saved passwords | Cookies |
| Extensions | Origin-scoped web storage, form data and sessions |
| Themes | Favicons |
| Certificates | Logs and crash dumps |
| Search engines | Telemetry and temporary files |
| Sync settings | Obsolete lock files and orphan WAL/SHM |

Chromium storage cleanup is deliberately limited to origin-scoped stores such as IndexedDB and legacy WebSQL. Shared LevelDB-backed stores such as Local Storage and Service Worker data are left untouched because they can also contain extension state.

That rule is reinforced by three additional safety layers:

- **Preview before deletion** — irreversible cleanings first calculate how much space would be freed without touching any file, and continue only if you explicitly confirm.
- **Automatic backup** — before touching `places.sqlite`, `Web Data` or `Preferences`, it saves a `.bak` copy in case something goes wrong.
- **Never as root** — it cleans your own `$HOME`, never the system, and warns you if you launch it as root.

## Cleaning types

| Type | What it includes |
|---|---|
| Quick cleaning | Cache, thumbnails and crash reports |
| Cache only | Cache (and component/extension cache in Chromium browsers) |
| Cookies only | Cookies |
| History only | Browsing history |
| Complete cleaning | Quick + history, cookies, sessions and form data |
| Deep cleaning | Complete + website permissions and security state (HSTS/NEL) on Firefox/Chromium; same as Complete on Falkon/Epiphany |

History-only, cookies-only, complete, and deep cleaning types are irreversible: before applying them, a preview shows how much space would be freed, and you must explicitly confirm to continue.

## Supported browsers

| Engine | Browsers |
|---|---|
| Firefox | Firefox, LibreWolf, Tor Browser, Waterfox, Floorp, Zen Browser |
| Chromium | Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge |
| QtWebEngine | Falkon |
| WebKitGTK | GNOME Web (Epiphany) |

Each browser is detected from its native, Flatpak or Snap profile layout — Mint does not ship with Snap by default, but supported Snap profiles are detected if present. If you have several profiles in the same browser, Browser-Cleaner cleans all of them.

## Installation

```bash
git clone https://github.com/filonux/Browser-Cleaner.git
cd Browser-Cleaner/script
chmod +x browser-cleaner.sh
./browser-cleaner.sh
```

## Commands

The default mode (no arguments) is interactive: it detects your browsers, you choose which ones to clean and what type of cleaning to apply through numbered menus.

| Command | What it does |
|---|---|
| `./browser-cleaner.sh` | Opens the interactive menu |
| `./browser-cleaner.sh --help` | Shows the help and exits |
| `./browser-cleaner.sh --version` | Shows the installed version and exits |

## Use it with Scriptya

If you prefer not to depend on the terminal to launch it, [**Scriptya**](https://github.com/filonux/Scriptya) — another Filonux tool — turns Browser-Cleaner (or any other script) into a standalone app: with its own icon, integrated into the Cinnamon applications menu and/or Desktop, and with a single menu from which you can launch, update or uninstall it.

```bash
git clone https://github.com/filonux/Scriptya.git
cd Scriptya/script
chmod +x scriptya.sh
./scriptya.sh --icons
```

The assistant lets you select `browser-cleaner.sh` and assign it an icon — you can use the one included in this repository: `assets/icon.png`.

## Compatibility

Tested on Linux Mint 22.3 Cinnamon. The script only uses Bash, standard Linux userland utilities and each browser's standard configuration paths (`~/.mozilla`, `~/.config/...`, `~/.var/app/...` for Flatpak), so it should work the same on any Ubuntu/Debian-based distro and, in general, on any distro with Bash 4+ — although it is currently only verified on Mint/Cinnamon.

The only Debian/Ubuntu-specific part is the optional dependency installer, which uses `apt`. On distros with another package manager, automatic installation is not available, but if `sqlite3` and `jq` are already installed — or you install them manually — the rest works exactly the same. If they are not present, the categories that need them are simply skipped without errors.

| Tool | What it is for | If missing |
|---|---|---|
| `sqlite3` | Cleaning history, form data and permissions without risking bookmarks or search engines | Offered for installation via `apt`; if declined, that category is skipped |
| `jq` | Cleaning website permissions without touching the rest of the configuration | Same as `sqlite3` |

## Language

Browser-Cleaner includes English and Spanish.

The interface detects the system message locale at startup. If the detected locale is Spanish (starts with `es`, including variants such as `es_ES.UTF-8`), the interface starts in Spanish; otherwise it defaults to English. The precedence is `LC_ALL`, then `LC_MESSAGES`, then the first preference in `LANGUAGE`, and finally `LANG`.

The language can be switched at any time from the main menu with a single `L` key: `es → en` or `en → es`.

For testing or forcing a language without changing the system locale, you can also set `BROWSER_CLEANER_LANG`:

```bash
BROWSER_CLEANER_LANG=en ./script/browser-cleaner.sh
BROWSER_CLEANER_LANG=es ./script/browser-cleaner.sh
```

Source-code comments are kept concise and written in English; user-facing interface text remains available in English and Spanish.

## Tests

A regression suite covering locale detection, English/Spanish UI, the `L` language toggle, menu tokens, help output, irreversible-operation preview/cancellation, output layout, and representative Firefox cleaning behavior is included in `tests/test_browser_cleaner.sh`.

```bash
./tests/test_browser_cleaner.sh
```

## Contributing

Issues and pull requests are welcome — there are templates in `.github/` for reporting bugs or proposing features. The complete guide is in [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

GPLv3. See the [LICENSE.txt](LICENSE.txt) file.

---

Made by [Filonux](https://github.com/filonux).
