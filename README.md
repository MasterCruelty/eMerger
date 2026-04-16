# eMerger

[![CI](https://github.com/MasterCruelty/eMerger/actions/workflows/ci.yml/badge.svg)](https://github.com/MasterCruelty/eMerger/actions/workflows/ci.yml)
[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=TheMergers_eMerger&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=TheMergers_eMerger)
[![Maintainability](https://sonarcloud.io/api/project_badges/measure?project=TheMergers_eMerger&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=TheMergers_eMerger)

<p align="center">
    <img src="./src/logo/big_name.png" alt="eMerger logo">
</p>

**One command - `up` - refreshes, upgrades and cleans your whole system.**
Works on **Linux**, **macOS** and **Windows**. Auto-detects every package
manager you have, runs them in the right order, gives you one clean summary
at the end. No YAML, no daemons.

> New to package managers? Read the [Why eMerger?](#why-emerger) section
> first. In a hurry? Jump to [Quickstart](#quickstart).

---

## Table of contents

1. [Why eMerger?](#why-emerger)
2. [Platforms at a glance](#platforms-at-a-glance)
3. [Quickstart](#quickstart)
4. [What `up` actually does](#what-up-actually-does)
5. [Requirements](#requirements)
6. [Installation](#installation)
   - [Linux](#install-linux)
   - [macOS](#install-macos)
   - [Windows](#install-windows)
7. [Uninstallation](#uninstallation)
8. [Update / self-update](#update--self-update)
9. [User manual](#user-manual)
   - [Running](#running)
   - [Flags, quick reference](#flags-quick-reference)
   - [Combining flags](#combining-flags)
   - [Interactive mode](#interactive-mode)
   - [Dry-run & verbose](#dry-run--verbose)
   - [Quiet levels](#quiet-levels)
   - [Security-only updates](#security-only-updates)
   - [Dev toolchains](#dev-toolchains)
   - [Firmware (Linux)](#firmware-linux)
   - [Parallel mode](#parallel-mode)
   - [Snapshots (Linux)](#snapshots-linux)
   - [Mirrors refresh (Linux)](#mirrors-refresh-linux)
   - [Reboot handling](#reboot-handling)
   - [Resume after interruption](#resume-after-interruption)
   - [Package diff & changelog](#package-diff--changelog)
   - [Reports](#reports)
   - [History & errors](#history--errors)
   - [Doctor](#doctor)
10. [Configuration](#configuration)
    - [config file](#config-file)
    - [All config variables](#all-config-variables)
    - [Profiles](#profiles)
    - [Hooks](#hooks)
    - [Ignore list (Linux)](#ignore-list-linux)
    - [Quiet hours](#quiet-hours)
    - [Manager plugins](#manager-plugins)
11. [Integration](#integration)
    - [JSON output](#json-output)
    - [Prometheus metrics](#prometheus-metrics)
    - [Reboot exit code](#reboot-exit-code)
    - [Download-only / offline](#download-only--offline)
    - [Manager filtering](#manager-filtering)
    - [Rollback](#rollback)
    - [Short flag bundling](#short-flag-bundling)
12. [Auto-update (unattended)](#auto-update-unattended)
13. [Cookbook / Recipes](#cookbook--recipes)
14. [Safety & security](#safety--security)
15. [Files & paths](#files--paths)
16. [Supported package managers](#supported-package-managers)
17. [Exit codes](#exit-codes)
18. [Troubleshooting](#troubleshooting)
19. [FAQ](#faq)
20. [Glossary](#glossary)
21. [Development](#development)
22. [License](#license)

📄 **For a printable, all-in-one reference see
[doc/documentation.pdf](./doc/documentation.pdf).**

---

## Why eMerger?

A modern machine gets its software from many different places at once:
the distro's own package manager (`apt`, `dnf`, `pacman`, `zypper`,
`softwareupdate`, `winget`...), an app-store layer (`flatpak`, `snap`,
`brew --cask`, `choco`, `scoop`), a user-level store (`brew`, `mas`),
language ecosystems (`npm`, `pip`, `cargo`, `gem`, `pnpm`...) and, on
Linux, firmware via `fwupdmgr`. Each has its own syntax, its own cache,
its own notion of "security update" and its own definition of "clean".

Keeping all of them up to date by hand is tedious and error-prone.
Writing a personal wrapper that works on three operating systems is a
weekend project most people never finish.

**eMerger is that wrapper, generalised.** Type `up` and it will:

1. detect every package manager installed on the host
2. ask for `sudo` (or trigger UAC) only if something actually needs it
3. take an optional snapshot so you can audit the run afterwards
4. run refresh / upgrade / clean, in the right order, with retries
5. wipe user caches and the trash, optionally
6. print one summary with per-manager result, disk freed, run duration
   and a reboot advisory
7. export the same summary as JSON, Markdown or a Prometheus file

It does this with no daemon, no YAML, no Python/Ruby runtime. Just Bash
on Unix, PowerShell on Windows.

**What eMerger is NOT:**

- Not a package manager itself. It drives the ones you already have.
- Not a configuration management system. No desired state, no manifest.
  If you want that, use Ansible, Salt or NixOS.
- Not a service. It can install a weekly timer, but it does not run in
  the background.

---

## Platforms at a glance

| | Linux | macOS | Windows |
|---|---|---|---|
| Entry point | `src/emerger.sh` | `src/emerger.sh` | `src/emerger.ps1` |
| Shell | bash 3.2+ | bash 3.2+ (system default) | PowerShell 5.1+ |
| Setup | `./setup.sh` | `./setup.sh` | `.\setup.ps1` |
| Uninstall | `./uninstall.sh` | `./uninstall.sh` | `.\uninstall.ps1` |
| Auto-update | systemd user timer / cron | launchd-compat cron | Task Scheduler |
| Elevation | `sudo` | `sudo` | UAC relaunch |
| TUI menu | yes (`-i`) | yes (`-i`) | no |
| Parallel mode | yes | yes | no (always serial) |
| Snapshots | snapper/timeshift/btrfs | no | no (System Restore is manual) |
| Config dir | `~/.config/emerger/` | `~/.config/emerger/` | `%APPDATA%\emerger\` |
| State dir | `~/.local/state/emerger/` | `~/.local/state/emerger/` | `%LOCALAPPDATA%\emerger\state\` |

Feature parity is kept for the core flow (detect → upgrade → clean → summary).
Platform-specific features are documented below and clearly labelled.

---

## Quickstart

No commitment. Nothing gets upgraded until you say so.

**Linux / macOS**
```sh
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
./setup.sh
# open a new shell (or: source ~/.bashrc)
up --help
up -n            # preview: shows what would run
up               # real run
```

**Windows** (PowerShell)
```powershell
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
.\setup.ps1
# open a new PowerShell window (or: . $PROFILE)
up --help
up -n            # preview
up               # real run
```

### What you'll see on the first real run

On a Debian/Ubuntu desktop with Flatpak installed, expect something like:

```text
 _____    __  __
|  ___|  |  \/  |  eMerger v2.0.0
| |__    | |\/| |  one command for the whole system
|____|   |_|  |_|
Ubuntu 24.04  o  x86_64  o  2026-04-16 10:12
eMerger v2.0.0  o  github.com/MasterCruelty/eMerger
[1/3] apt        OK     (38 upgraded, 0 removed, 0 new)
[2/3] flatpak    OK     (5 refreshed)
[3/3] fwupd      SKIP   (--firmware not set)
+---------------------------------------------+
|  eMerger - summary                          |
|  duration  42s                              |
|  freed     15 MiB                           |
|  reboot    not required                     |
|  errors    0                                |
+---------------------------------------------+
```

> **Do not run `sudo up`.** eMerger will ask for `sudo` itself, only for
> the managers that need it. Running `sudo up` would install user-level
> packages (e.g. `pip --user`, Homebrew, `npm -g`) into root's home.

---

## What `up` actually does

Each full run performs, in order:

1. Load `config.sh` (or `config.ps1`) and any `--profile`.
2. Parse CLI flags. CLI always wins over config and profile defaults.
3. Acquire a global exclusive lock (`/tmp/emerger.lock` on Unix).
4. Print logo, OS info line and timestamp (skippable with `-nl`/`-ni`).
5. Warn on low battery and on low free disk space.
6. Cache `sudo` credentials (Unix) or relaunch elevated (Windows) if any
   detected manager needs it.
7. Snapshot installed packages (for the post-run diff).
8. Run `pre.d` hooks.
9. For each detected manager: **refresh → upgrade → clean**.
10. Optionally clean user cache / `%TEMP%` and trash / Recycle Bin.
11. Run `post.d` hooks.
12. Compute the installed-packages diff.
13. Print boxed summary + reboot advisory.
14. Emit desktop notification if the session has a display (or if
    BurntToast is installed on Windows).
15. Exit 0 on success, 3 if any manager failed, 4 if a reboot is pending
    and `--reboot-exit` was passed.

---

## Requirements

**Linux**
- bash ≥ 3.2, coreutils, git, sudo.
- Optional: `gum`/`whiptail`, `notify-send`, `curl`, `flock`, `reflector`,
  `netselect-apt`, `snapper`/`timeshift`/`btrfs-progs`, `fwupdmgr`.

**macOS**
- bash ≥ 3.2 (the system `/bin/bash` works out of the box; no Homebrew bash needed).
- Xcode Command Line Tools (for git).
- Optional: Homebrew, `mas` (`brew install mas`).

**Windows**
- PowerShell 5.1 (built-in on Win10+) or 7+.
- Git for Windows (for `up --self-update`).
- Optional: `winget`, `scoop`, `choco`, `PSWindowsUpdate`
  (`Install-Module PSWindowsUpdate -Scope CurrentUser`), `BurntToast`
  (`Install-Module BurntToast`) for toast notifications.

eMerger never installs these for you - it only uses what's there.

---

## Installation

### Install (Linux)

```sh
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
./setup.sh
```

`setup.sh` does exactly this:

1. Adds `alias up='bash /path/to/eMerger/src/emerger.sh'` to your shell rc
   (bash, zsh, fish - whichever you use).
2. Makes `src/emerger.sh` executable.
3. Installs shell completions under:
   - `~/.local/share/bash-completion/completions/up`
   - `~/.zsh/completions/_up`
   - `~/.config/fish/completions/up.fish`
4. Creates `~/.config/emerger/{config.sh,ignore.list,hooks/,profiles.d/}`.

After install, **open a new shell** (or `source ~/.bashrc`).

### Install (macOS)

Identical script, same flow:

```sh
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
./setup.sh
```

macOS specifics handled automatically:
- The alias is written to `~/.zshrc` first (zsh is the default shell since Catalina).
- If Homebrew is installed, completions go to
  `$(brew --prefix)/etc/bash_completion.d/` and
  `$(brew --prefix)/share/zsh/site-functions/`.
- `softwareupdate` (native macOS updater) is auto-detected alongside `brew`,
  `brew --cask`, and `mas`.

### Install (Windows)

```powershell
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
.\setup.ps1
```

`setup.ps1` does:

1. Sets `ExecutionPolicy` to `RemoteSigned` for `CurrentUser` if it was
   `Restricted` or `Undefined`. No admin needed for this.
2. Adds a `function up { & "…\emerger.ps1" @args }` block to your
   `$PROFILE.CurrentUserAllHosts` (so `up` works from any host: cmd-hosted
   PS, ISE, Terminal…).
3. Scaffolds `%APPDATA%\emerger\{config.ps1,hooks\,profiles.d\}`.

After install, **open a new PowerShell window** (or `. $PROFILE`).

> **Important**: `setup.ps1` does **not** require admin. Package manager
> runs that need admin will trigger a UAC prompt via automatic elevation.

### Manual install

All three platforms: just point an alias/function at the entry point.

```sh
# bash/zsh/fish - macOS or Linux
alias up='bash /absolute/path/to/eMerger/src/emerger.sh'
```

```powershell
# PowerShell - Windows
function up { & "C:\path\to\eMerger\src\emerger.ps1" @args }
```

---

## Uninstallation

```sh
# Linux / macOS
./uninstall.sh
```

```powershell
# Windows
.\uninstall.ps1
```

Removes the shell alias / `up` function, any cronjob, systemd user timer or
scheduled task. **Keeps** your config and state directories so you don't
lose history or hooks. Delete those paths manually if you want a clean
wipe:

```sh
rm -rf ~/.config/emerger ~/.cache/emerger ~/.local/state/emerger
```

The repo itself is not removed - `rm -rf` or `Remove-Item` the directory
when you're done.

---

## Update / self-update

Three equivalent ways:

```sh
up -up          # flag form
```
or
```sh
up --self-update
```
or
```sh
./update.sh     # Linux / macOS
.\update.ps1    # Windows
```

This does a `git pull --ff-only` inside the repo and shows the commit range.
Refuses non-fast-forward pulls so local changes never silently vanish.

For automatic updates of eMerger itself, put it in `post.d` hook (see
[Hooks](#hooks)).

---

## User manual

### Running

```sh
up              # Linux / macOS
```
```powershell
up              # Windows
```

Full list of flags: `up --help`.

### Flags, quick reference

Authoritative list: `up --help`. Highlights:

| Flag | Meaning | Platforms |
|---|---|---|
| `-n`, `--dry-run` | Preview, don't run | all |
| `-v`, `--verbose` | Stream output live | all |
| `-q` / `-qq` / `-qqq` | Quieter | all |
| `-y`, `--yes` | Assume yes | all |
| `-i`, `--interactive` | Menu UI | Linux/macOS |
| `--security` | Security-only | all (where supported) |
| `--dev` | Include dev toolchains | all |
| `--firmware` | `fwupdmgr` | Linux |
| `--parallel` | Run user-space concurrently | Linux/macOS |
| `--profile NAME` | Load a profile | all |
| `--snapshot` | snapper/timeshift/btrfs | Linux |
| `--refresh-mirrors` | re-rank mirrors | Linux |
| `--resume` | Skip completed managers | Linux/macOS |
| `--reboot` | Reboot if required | all |
| `--changed` | Package diff | Linux/macOS |
| `--changelog PKG` | Upstream changelog | Linux/macOS |
| `--report FILE` | Export Markdown | Linux/macOS |
| `--doctor` | Health check | all |
| `--history` | Recent runs | all |
| `--errors` / `-err` | Log tail | all |
| `--no-emoji` | ASCII only | all |
| `--json` | Machine-readable summary | all |
| `--reboot-exit` | Exit 4 if reboot is required | all |
| `--rollback` | Revert last snapshot | Linux |
| `--download-only` / `--offline` | Prefetch, don't install | Linux/macOS (apt/dnf/pacman/zypper) |
| `--only LIST` | Keep only these managers | all |
| `--except LIST` | Skip these managers | all |
| `--metrics FILE` | Prometheus textfile export | all |
| `-up` | Self-update | all |
| `-au` | Install auto-update | all |

### Combining flags

Flags are independent tokens - mix and match as many as you need, in any
order. Short bundling `-nv` → `-n -v` is supported for the letters
`{h V n v q y i w}`. Compound short flags (`-nl`, `-ni`, `-qq`, `-up`,
`-err`, ...) and long flags pass through unchanged.

```sh
up -n -v                       # dry-run + live stream (preview a full run)
up -y -q --security            # unattended security-only, minimal output
up --dev --parallel -v         # dev toolchains + user-space concurrency, verbose
up --snapshot --reboot -y      # snapshot first, reboot at the end if needed
up --profile server --resume   # resume an interrupted headless run
up -n --dev --firmware         # preview a full dev + firmware run, no side effects
up -qq -y -nl -ni --security   # exactly what the scheduled timer does
up --refresh-mirrors -y -v     # re-rank mirrors then upgrade, watch it live
up --changed --report out.md   # show diff and export it in one shot
```

```powershell
up -y -q --security            # Windows, unattended security-only
up --dev -v                    # Windows, include dev toolchains, verbose
up -n --security               # Windows, preview a security-only run
```

Flags that take a value (`--profile NAME`, `--changelog PKG`,
`--report FILE`, `--metrics FILE`, `--only LIST`, `--except LIST`) must
keep their argument adjacent; everything else is position-free. CLI flags
always win over config file and profile defaults, so you can override a
profile on the fly:

```sh
up --profile work --dev        # work profile, but force dev toolchains this run
```

### Interactive mode

```sh
up -i
```

Menu via `gum` (pretty), `whiptail` (classic), or plain read-loop.
Windows does not ship a TUI - use flags directly or a profile.

### Dry-run & verbose

```sh
up -n             # see what would happen (safe, no sudo)
up -v             # stream pkg-manager output live
up -n -v          # both
```

Example of `-n` output:

```text
$ up -n
[dry] sudo apt update
[dry] sudo apt upgrade -y
[dry] sudo apt autoremove -y
[dry] sudo apt clean
[dry] flatpak update -y
[dry] flatpak uninstall --unused -y
```

### Quiet levels

- **default** - full UI with box and spinner
- `-q` - hide muted/info lines
- `-qq` - only step titles + one-line summary (great for systemd logs)
- `-qqq` - no output at all; exit code is the only signal

### Security-only updates

```sh
up --security -y
```

- Linux: `apt` (via `unattended-upgrade`), `dnf` (`--security`),
  `zypper` (`patch --category security`).
- macOS: `softwareupdate --install --recommended`.
- Windows: `PSWindowsUpdate` respects KB severity if the module supports it.

Other managers ignore the flag.

### Dev toolchains

Opt-in (every platform):

```sh
up --dev
```

Updates:

| Tool | Command |
|---|---|
| `rustup` | `rustup self update && rustup update stable` |
| `cargo` | `cargo install-update -a` |
| `npm` | `npm update -g` |
| `pnpm` | `pnpm -g update` |
| `pip` | user-site upgrades |
| `gem` | `gem update` |

These never run under `sudo`. Missing toolchains are silently skipped.

### Firmware (Linux)

```sh
up --firmware
```

Runs `fwupdmgr refresh && fwupdmgr update -y --no-reboot-check`. Windows
firmware is handled by vendor tools (Dell Command Update, Lenovo Vantage)
and is out of scope. macOS firmware is handled by `softwareupdate`.

### Parallel mode

```sh
up --parallel
```

User-space managers that don't touch `/` run concurrently (`flatpak`,
`snap`, `brew`, `mas`, dev tools). System managers stay serial. Windows
side is currently always serial.

### Snapshots (Linux)

```sh
up --snapshot
```

Tries in order: `snapper`, `timeshift`, `btrfs subvolume snapshot`. Windows
users: enable **System Restore** manually; eMerger doesn't trigger it.

### Mirrors refresh (Linux)

```sh
up --refresh-mirrors
```

- Arch: `reflector --latest 20 --sort rate`.
- Debian/Ubuntu: `netselect-apt`.
- Fedora: handled by `fastestmirror` plugin automatically; no-op here.

### Reboot handling

After a run, eMerger checks for reboot flags:

- Linux: `/var/run/reboot-required`, `needs-restarting -r`.
- Windows: registry keys (`CBS RebootPending`, `WindowsUpdate\RebootRequired`,
  `PendingFileRenameOperations`).

To reboot on demand:

```sh
up --reboot     # reboots if required, no-op otherwise
```

### Resume after interruption

If you kill a run mid-way:

```sh
up --resume
```

skips every manager that successfully completed in the last interrupted run.
State lives in `~/.local/state/emerger/resume`. Linux/macOS only.

### Package diff & changelog

Every run records installed packages before/after. View it:

```sh
up --changed
```

Example output:

```text
$ up --changed
~ firefox          123.0.1   ->  124.0
~ libc6            2.39-0    ->  2.39-1
+ flatpak-xdg-utils 1.0.6
- old-package      2.1
```

Legend: `+` added, `-` removed, `~` upgraded. Linux/macOS.

Read a single package's upstream changelog:

```sh
up --changelog firefox
```

Dispatches to `apt changelog`, `dnf changelog`/`updateinfo`, `pacman -Qi`,
or `brew log`.

### Reports

```sh
up --report report.md
```

Markdown export of the last run: JSON summary, managers, reboot advisory,
full package diff as a table.

### History & errors

```sh
up --history    # last 10 runs
up --errors     # tail of ERROR lines from the log
```

### Doctor

```sh
up --doctor
```

Audits:
- shell / PowerShell version
- sudo cache / admin status
- disk space
- network reachability
- state dir writability
- per-manager native health (`dpkg --audit`, `pacman -Dk`, `brew doctor`, …)
- pending reboot flag
- (Windows) ExecutionPolicy

Exits non-zero if issues are found. **Always attach `up --doctor` output
when reporting a bug.**

---

## Configuration

### config file

**Linux / macOS** - `~/.config/emerger/config.sh` (sourced before arg parsing):

```sh
# Defaults
ARG_DEV=1                 # always include dev toolchains
ARG_WEATHER=1             # always show weather
ARG_PARALLEL=1            # user-space managers in parallel

# Thresholds
DISK_MIN_FREE_MB=2048     # require >= 2 GB on /
RETRY_MAX=3               # transient-error retries

# Scheduling
QUIET_HOURS="23:00-07:00" # skip scheduled runs inside this window
```

**Windows** - `%APPDATA%\emerger\config.ps1` (dot-sourced before arg parsing):

```powershell
$script:ArgsGlobal.Dev      = $true
$script:ArgsGlobal.Security = $true
$script:ArgsGlobal.NoTrash  = $true
```

### All config variables

| Variable | Default | Meaning |
|---|---|---|
| `ARG_DEV` | 0 | include dev toolchains by default |
| `ARG_FIRMWARE` | 0 | include `fwupdmgr` by default |
| `ARG_NO_FIRMWARE` | 0 | force-skip firmware |
| `ARG_SECURITY` | 0 | security-only by default |
| `ARG_YES` | 0 | assume yes by default |
| `ARG_PARALLEL` | 0 | parallel user-space by default |
| `ARG_WEATHER` | 0 | show weather widget |
| `ARG_NO_EMOJI` | 0 | force ASCII glyphs |
| `ARG_NO_CACHE` | 0 | skip user cache cleaning |
| `ARG_NO_TRASH` | 0 | skip trash cleaning |
| `ARG_NO_LOGO` | 0 | hide logo |
| `ARG_NO_INFO` | 0 | hide system info line |
| `QUIET_LEVEL` | 0 | 0=full UI, 1=`-q`, 2=`-qq`, 3=`-qqq` |
| `DISK_MIN_FREE_MB` | 1024 | abort/warn below this many MiB |
| `BATTERY_MIN_PCT` | 20 | warn below this battery percent |
| `RETRY_MAX` | 2 | transient-error retries |
| `RETRY_DELAY` | 3 | seconds between retries |
| `QUIET_HOURS` | (unset) | `"HH:MM-HH:MM"` - skip scheduled runs inside window |
| `EMERGER_CACHE_TTL` | 86400 | detection cache TTL in seconds, 0 disables |

> CLI flags always win. `ARG_SECURITY=1` in `config.sh` plus `up --dev` on
> the CLI will run security updates **and** dev toolchains.

### Profiles

Profiles are config snippets scoped to a name.

```sh
up --profile work
up --list-profiles
```

Shipped defaults in `share/profiles/`:

| Profile | Meant for |
|---|---|
| `work` | laptop at work - security, unattended, no cache/trash |
| `home` | desktop at home - everything, dev toolchains, parallel |
| `server` | headless - `-qq`, security, no prompts |
| `safe` | pre-presentation - security only, no big downloads |

Each platform looks for its own extension:

- Unix → `share/profiles/<name>.sh`
- Windows → `share/profiles/<name>.ps1`

User profiles go in `~/.config/emerger/profiles.d/` (Unix) or
`%APPDATA%\emerger\profiles.d\` (Windows) and shadow the shipped ones.

Example custom profile (`~/.config/emerger/profiles.d/train.sh`):

```sh
# description: on a train, prefetch only, keep the fans quiet
ARG_DOWNLOAD_ONLY=1
ARG_YES=1
ARG_QUIET=1
QUIET_LEVEL=2
ARG_NO_TRASH=1
ARG_NO_CACHE=1
```

Then `up --profile train` does a silent prefetch.

### Hooks

Drop executable scripts in `hooks/pre.d/` (before updates) or
`hooks/post.d/` (after). They run alphabetically. A failing hook emits a
warning but never aborts the run.

- Unix: `*.sh`, run under bash.
- Windows: `*.ps1`, dot-sourced under PowerShell.

**Example 1 - backup dotfiles before every run:**

```sh
# ~/.config/emerger/hooks/pre.d/10-backup-dotfiles.sh
#!/usr/bin/env bash
set -e
rsync -a --delete ~/.config/ ~/backups/dotfiles/
```

**Example 2 - Slack notification after every run:**

```sh
# ~/.config/emerger/hooks/post.d/99-slack.sh
#!/usr/bin/env bash
state=~/.local/state/emerger
payload=$(tail -1 "$state/history.jsonl")
curl -sS -X POST -H 'Content-Type: application/json' \
    -d "{\"text\":\"eMerger: $payload\"}" "$SLACK_WEBHOOK_URL"
```

**Example 3 - copy last log to clipboard (Windows):**

```powershell
# %APPDATA%\emerger\hooks\post.d\10-log-to-clipboard.ps1
$log = Join-Path $env:LOCALAPPDATA 'emerger\state\emerger.log'
Get-Content $log -Tail 40 | Set-Clipboard
```

**Example 4 - export Prometheus metrics automatically:**

```sh
# ~/.config/emerger/hooks/post.d/90-prom.sh
#!/usr/bin/env bash
up --metrics /var/lib/node_exporter/textfile_collector/emerger.prom
```

> Hooks run with the privileges that invoked `up`. If you need root-owned
> side effects, write them in `post.d` and guard with `sudo -n` or a
> targeted sudoers entry.

### Ignore list (Linux)

`~/.config/emerger/ignore.list` - one package per line, `#` comments ok.
Honored natively by **pacman** (`--ignore=`). For others it is
**advisory** - you still need to hold them via:

- apt: `sudo apt-mark hold <pkg>`
- dnf: `sudo dnf versionlock add <pkg>`
- zypper: `sudo zypper al <pkg>`

### Quiet hours

Set `QUIET_HOURS="HH:MM-HH:MM"` in `config.sh`. When a scheduled run starts
inside that window **and** `-y` is set (i.e. from the timer), eMerger exits
immediately. Interactive runs always proceed. Windows across midnight is
supported (e.g. `"23:00-07:00"`). Linux/macOS.

### Manager plugins

Drop a bash script in `~/.config/emerger/managers.d/<name>.sh` to add support
for a package manager without touching the repo. A minimal plugin:

```sh
PM_PLUGIN_SLUG=mytool

pm_mytool_detect() { command -v mytool >/dev/null 2>&1; }
pm_mytool_needs_sudo() { return 1; }     # optional, default: no sudo
pm_mytool_parallel()   { return 0; }     # optional, default: serial
pm_mytool_dev()        { return 1; }     # optional, default: not gated by --dev
pm_mytool_icon()       { printf '🔌'; }  # optional

pm_mytool_run() {
    run_cmd "mytool refresh" mytool refresh || return 1
    run_cmd "mytool upgrade" mytool upgrade -y || return 1
}
```

A complete, copy-pasteable template lives in
[`share/plugins/example.sh`](share/plugins/example.sh).

Plugins are registered at the same level as native managers: they honour
`--only`, `--except`, `--parallel`, `--dev`, the detection cache, hooks and
the summary. They are invoked from inside `pkg_run`, so `run_cmd` automatically
gives them `--dry-run`, retry, logging and live-log handling for free.

The detection cache is keyed by manager slug and lives at
`~/.cache/emerger/detected`. TTL defaults to 1 day; override via
`EMERGER_CACHE_TTL=<seconds>` in `config.sh` (0 disables caching). After
installing or removing a package manager, run `up -rc` to clear the cache.

Linux/macOS only. Windows plugins are not yet supported.

---

## Integration

### JSON output

```sh
up --json
```

Emits a single-line JSON object on stdout. The logo, info line and summary
box are all suppressed, so the output is safe to pipe into `jq` or consume
from a CI job:

```json
{"ts":"2026-04-14T07:24:31Z","duration":42,"freed_kb":15360,
 "errors":0,"reboot":0,
 "managers":[{"name":"apt","result":"ok"},{"name":"flatpak","result":"ok"}]}
```

Every run also appends one such line to
`~/.local/state/emerger/history.jsonl` (one JSON per line). Fields:

| Field | Meaning |
|---|---|
| `ts` | ISO 8601 UTC timestamp of the run start |
| `duration` | total wall-clock seconds |
| `freed_kb` | cache and trash bytes freed, in KiB |
| `errors` | number of managers that returned non-zero |
| `reboot` | 1 if a reboot is required, else 0 |
| `managers` | array of `{name, result}` entries |

### Prometheus metrics

```sh
up --metrics /var/lib/node_exporter/textfile_collector/emerger.prom
```

Reads the most recent entry from `history.jsonl` and renders a Prometheus
textfile-collector snapshot. Exported gauges:

- `emerger_last_run_timestamp_seconds`
- `emerger_last_run_duration_seconds`
- `emerger_last_run_freed_bytes`
- `emerger_last_run_errors`
- `emerger_reboot_required`
- `emerger_manager_ok{manager="..."}` (one per manager from the last run)

Does not trigger a run - invoke it from a `post.d` hook or from your timer
after `up` completes.

### Reboot exit code

By default eMerger always exits 0 on success even when a reboot is pending
(the summary box prints `REBOOT RECOMMENDED`). Pass `--reboot-exit` to turn
that into exit code **4** instead, so an orchestrator can react:

```sh
up -y --reboot-exit
rc=$?
case $rc in
    0) ;;                                   # done, no reboot needed
    3) notify-send "eMerger: some managers failed" ;;
    4) systemctl reboot ;;                  # clean, reboot required
esac
```

### Download-only / offline

```sh
up --download-only -y       # or --offline
```

Refreshes indexes and **downloads** the pending upgrade set but does not
install it. Supported natively on `pacman` (`-Syuw`), `apt`/`apt-get`
(`--download-only`), `dnf` (`--downloadonly`) and `zypper`
(`update --download-only`). Other managers ignore the flag.

Typical use cases:

- laptop on a slow/metered connection at a café: prefetch while online,
  install later at the office
- servers in a maintenance window: prestage packages, then flip to
  install-only when the change ticket opens
- pre-flight for `--snapshot`: confirm the whole update set is downloaded
  before taking a snapshot

### Manager filtering

```sh
up --only apt,flatpak        # only these managers (comma-separated)
up --except snap,fwupd       # everything that would run, minus these
```

The filters are applied after detection and after `--dev`/`--firmware`
gating, so:

- `--only X` with `X` not detected is a no-op (nothing runs).
- `--except` wins over `--only` when both mention the same name.

Compose with profiles (`up --profile work --only apt`) to restrict a
profile on the fly.

### Rollback

```sh
up --rollback
```

Reverts to the most recent eMerger-created snapshot. Dispatches to:

- **snapper**: native `snapper -c root rollback <num>`. Grep-finds the last
  snapshot whose description starts with `eMerger pre-update`. A reboot is
  required to apply the rollback (snapper semantics, not ours).
- **timeshift**: hands off to `timeshift --restore` (interactive by design;
  we don't pass `--yes` - rollback is too destructive for that).
- **raw btrfs**: refuses to swap subvolumes automatically, prints the path
  of the latest snapshot under `/.snapshots/emerger/` so you can do it
  manually.

Combine with `--snapshot` for a safe update cycle:

```sh
up --snapshot -y || up --rollback
```

### Short flag bundling

Single-letter short flags can be bundled:

```sh
up -nv          # == up -n -v
up -ynv         # == up -y -n -v
up -qv          # == up -q -v
```

Only flags whose letters are all in the set `{h V n v q y i w}` bundle.
Compound short flags (`-nl`, `-ni`, `-nc`, `-nt`, `-qq`, `-qqq`, `-up`,
`-au`, `-err`, `-rc`) and long flags (`--foo`) pass through unchanged.

---

## Auto-update (unattended)

```sh
up -au          # Linux / macOS
```
```powershell
up -au          # Windows
```

- **Linux**: systemd user timer (preferred) at
  `~/.config/systemd/user/emerger.{service,timer}`; cron fallback.
- **macOS**: cron fallback (`crontab -l`), or use `launchd` manually.
- **Windows**: `Register-ScheduledTask -TaskName eMerger`. Weekly, Sunday
  10:00, ±1h randomized delay.

The scheduled run always uses `-y -q -nl -ni`.

Manage:

```sh
# Linux
systemctl --user status emerger.timer
systemctl --user disable emerger.timer

# Windows
Get-ScheduledTask eMerger
Unregister-ScheduledTask eMerger
```

To avoid night-time runs, pair with `QUIET_HOURS` in `config.sh`.

> On Linux, systemd **user** timers do not fire unless a login session is
> open for the user. Run `loginctl enable-linger $USER` once (as root) to
> make them fire in the background.

---

## Cookbook / Recipes

Concrete, copy-pasteable snippets for common situations.

### Daily driver (desktop)

```sh
up -v
```

Simple. Live output, everything updated, cache and trash wiped at the
end. Add `--firmware` once a month on Linux.

### Unattended server

One-off setup:

```sh
cat > ~/.config/emerger/config.sh <<'EOF'
ARG_SECURITY=1
ARG_YES=1
ARG_NO_CACHE=1
ARG_NO_TRASH=1
QUIET_HOURS="08:00-18:00"
EOF
up -au
```

Pair with a Prometheus hook for dashboards:

```sh
cat > ~/.config/emerger/hooks/post.d/90-prom.sh <<'EOF'
#!/usr/bin/env bash
up --metrics /var/lib/node_exporter/textfile_collector/emerger.prom
EOF
chmod +x ~/.config/emerger/hooks/post.d/90-prom.sh
```

### Developer workstation

```sh
up --dev --firmware --parallel -v
# or, as a profile:
up --profile home
```

### Pre-demo machine

The day before a presentation: security patches, no big downloads, no
reboot.

```sh
up --profile safe
```

### Metered / mobile connection

Prefetch when on good Wi-Fi:

```sh
up --download-only -y
```

Install later, even without network (the cache is already warm):

```sh
up -y
```

### CI runner / container image

```sh
up --only apt -y -qq --reboot-exit
rc=$?
if [[ $rc -eq 4 ]]; then echo "reboot required"; exit 0; fi
exit $rc
```

### Maintenance window with rollback guard

Snapshot, update, rollback on failure, reboot on success:

```sh
set -e
up --snapshot -y || { up --rollback; exit 1; }
up -y --reboot-exit
rc=$?
if [[ $rc -eq 4 ]]; then systemctl reboot; fi
```

### macOS with Homebrew only

```sh
up --only brew,mas -v
```

### Windows without Chocolatey

```powershell
up --except choco -v
```

### Audit a single package

```sh
up -n | grep -i firefox         # what would happen to it
up --changelog firefox          # what changed upstream
```

### Pin a package (Linux)

Add to `~/.config/emerger/ignore.list`:

```text
nvidia-driver-535
```

Then tell `apt` explicitly:

```sh
sudo apt-mark hold nvidia-driver-535
```

(pacman respects the file natively.)

---

## Safety & security

- eMerger is a client-side tool. No network listener, no daemon, no
  persistent background process.
- It reads and writes only three locations: `~/.config/emerger/`,
  `~/.cache/emerger/`, `~/.local/state/emerger/`, plus the global lock at
  `/tmp/emerger.lock` on Unix.
- `sudo` credentials are cached by `sudo` itself, not by eMerger. When
  the run ends, the cached credentials expire on the usual `sudo`
  schedule (5 minutes by default).
- On Windows, UAC elevation happens **only** when a detected manager
  actually needs admin. The elevation is logged.
- Hooks and plugins run as the invoking user. They can do anything the
  user can do - only install hooks from sources you trust.
- The only network calls eMerger itself makes are (a) the optional
  weather widget via `wttr.in`, (b) `git pull` during `--self-update`,
  (c) `fwupdmgr refresh` when `--firmware` is active. Everything else is
  delegated to the package manager you asked for.
- **No telemetry.** `history.jsonl` stays on your machine unless a hook
  you wrote ships it elsewhere.

---

## Files & paths

### Linux / macOS

| Path | Purpose |
|---|---|
| `~/.config/emerger/config.sh` | User defaults |
| `~/.config/emerger/profiles.d/` | User profiles |
| `~/.config/emerger/hooks/pre.d/`, `post.d/` | Hooks |
| `~/.config/emerger/ignore.list` | Ignore list (pacman native) |
| `~/.config/emerger/managers.d/*.sh` | User-defined manager plugins |
| `~/.cache/emerger/detected` | Detection cache (TTL: `EMERGER_CACHE_TTL`, default 86400s) |
| `~/.local/state/emerger/emerger.log` | Log (rotated at 2000 lines) |
| `~/.local/state/emerger/history.jsonl` | One JSON per run |
| `~/.local/state/emerger/pkgs.before` | Pre-run package snapshot |
| `~/.local/state/emerger/pkgs.after` | Post-run package snapshot |
| `~/.local/state/emerger/pkgs.diff` | Last-run package diff |
| `~/.local/state/emerger/resume` | Resume cursor |
| `/tmp/emerger.lock` | Global lock (`flock`) |

### Windows

| Path | Purpose |
|---|---|
| `%APPDATA%\emerger\config.ps1` | User defaults |
| `%APPDATA%\emerger\profiles.d\` | User profiles |
| `%APPDATA%\emerger\hooks\pre.d\`, `post.d\` | Hooks |
| `%LOCALAPPDATA%\emerger\cache\` | Detection cache |
| `%LOCALAPPDATA%\emerger\state\emerger.log` | Log |
| `%LOCALAPPDATA%\emerger\state\history.jsonl` | Run history |

---

## Supported package managers

**Linux - system (need sudo):**
`pacman`, `apt`/`apt-get`, `dnf`, `yum`, `zypper`, `xbps`, `apk`, `eopkg`,
`emerge`, `nixos-rebuild`, `fwupdmgr`, `snap`.

**Linux - AUR (no sudo):** `yay`, `paru`.

**Linux - user-space:** `flatpak`, `nix-env`.

**macOS:** `softwareupdate` (native), `brew`, `brew --cask`, `mas`.

**Windows:** `winget`, `scoop`, `choco`, `PSWindowsUpdate`, `wsl --update`.

**Dev toolchains** (all platforms, opt-in with `--dev`): `rustup`,
`cargo install-update`, `npm`, `pnpm`, `pip` (user), `gem`.

Want another one? Add a case branch to
[`src/lib/packages.sh`](src/lib/packages.sh) (Unix) or
[`src/pslib/Packages.ps1`](src/pslib/Packages.ps1) (Windows) - they're
simple table-driven dispatchers. Or drop a [plugin](#manager-plugins).

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | runtime failure (sudo, lock, disk, interrupted) |
| 2 | argument parsing error |
| 3 | one or more package managers returned non-zero |
| 4 | reboot required (only emitted with `--reboot-exit`) |

Useful for CI / cron wrappers:

```sh
up -y -q || case $? in
    3) notify-send "eMerger: some managers failed" ;;
    *) logger -t eMerger "fatal $?" ;;
esac
```

```powershell
up -y -q
if ($LASTEXITCODE -eq 3) { Write-Warning "Some managers failed" }
```

---

## Troubleshooting

**"Another eMerger run is in progress"** - stale `flock` on
`/tmp/emerger.lock`. Check `ps` for stragglers then remove it.

**Emoji renders as boxes** - `--no-emoji`, or set `LANG` / Windows Terminal
font to a Unicode-capable one.

**Spinner disappears on terminal resize** - harmless; the live-log width
recomputes every 120ms.

**`up --self-update` aborts with "non fast-forward"** - you have local
commits on top of `main`. Rebase or reset manually; eMerger refuses to
clobber them.

**`notify-send` (Linux) doesn't appear** - no `DISPLAY` /
`WAYLAND_DISPLAY` in the environment (typical for cron). Use systemd user
timer instead; it inherits the session.

**A manager fails with exit code 3** - run `up --errors` to tail the log,
then `up --doctor` to inspect the environment. Most failures come from a
manager's own health state (for example `dpkg` interrupted); run the
native repair command (`sudo dpkg --configure -a`, `sudo pacman -Dk`)
before retrying.

**Nothing happens on scheduled runs** - check
`systemctl --user status emerger.timer` or the Windows Task Scheduler
entry. On Linux, user timers don't fire without an open session unless
you run `loginctl enable-linger $USER`.

**(Windows) "up : The term 'up' is not recognized"** - your PowerShell
profile didn't load. Run `. $PROFILE` or open a new window. If still
missing, re-run `.\setup.ps1`.

**(Windows) "cannot be loaded because running scripts is disabled"** -
`ExecutionPolicy` is `Restricted`. Run as user:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**(Windows) Elevation fails silently** - you canceled the UAC prompt. The
script logs `relaunching elevated` then exits; the elevated window does
the actual work.

**Pacman keeps asking about ignored packages** - `ignore.list` is passed
as `--ignore=`; pacman still prints the warning line. Upstream behavior.

**"command not found: gum" or "whiptail"** - the interactive menu (`-i`)
falls back to a plain read loop when neither is installed. Install
[gum](https://github.com/charmbracelet/gum) for a nicer UI or ignore the
warning.

---

## FAQ

**Is eMerger safe for production servers?**
Yes, but use it in security-only, unattended mode: `up --profile server`.
Pair with `--reboot-exit` so your orchestrator decides when to reboot.

**Does `up` install packages I don't already have?**
No. `up` only invokes managers that are already installed and only asks
them to upgrade what is already installed. No new software is added
unless a package upgrade pulls in a new dependency.

**Does `up` reboot my machine?**
Only with `--reboot`. Without it, the summary prints a reboot advisory
and the run exits normally.

**Can I use `up` without `sudo`?**
Yes, in user-only mode: `up --only flatpak,brew,npm,pip,cargo` (adjust to
what you have). User-level managers never need elevation.

**Can I use `up` inside a Docker image build?**
Yes. Use `up --only apt -y -qq` (or the relevant manager) and ignore the
reboot advisory. Avoid `--firmware`, `--snapshot` and interactive flags.

**What happens if two `up` runs start at the same time?**
The second one aborts with exit code 1 ("Another eMerger run is in
progress"). The lock is a plain `flock` on `/tmp/emerger.lock`.

**How do I completely remove eMerger?**
Run the uninstaller, then:
```sh
rm -rf ~/.config/emerger ~/.cache/emerger ~/.local/state/emerger
rm -rf /path/to/eMerger     # the repo itself
```

**Where is my data?**
All local, all in the paths listed in [Files & paths](#files--paths).
Nothing leaves your machine unless a hook you wrote ships it.

**Can I contribute a new package manager?**
Absolutely - see [Development](#development). Most contributions are a
20-line dispatch branch plus a test case.

**Why is the terminal flashing during `--parallel -v`?**
Each user-space manager streams its own output concurrently. Drop `-v`
or narrow the parallel set with `--only` if you want a calm terminal.

---

## Glossary

- **Dry-run**: a simulation. The tool prints the commands it would run
  without actually running them.
- **Hook**: a user script that runs before (`pre.d`) or after (`post.d`)
  the update flow.
- **Manager (package manager)**: software like `apt`, `pacman`, `brew`,
  `winget` that installs, upgrades and removes programs on your machine.
- **Parallel mode**: concurrent execution of user-space managers.
- **Plugin**: a user-provided manager definition. Registers a new
  manager without modifying the repository.
- **Profile**: a named bundle of default flags, loaded via
  `--profile NAME`.
- **Resume cursor**: a file that records which managers completed
  successfully, consumed by `--resume`.
- **Snapshot**: a read-only filesystem checkpoint taken before the
  upgrade. Linux only (snapper/timeshift/btrfs).
- **TUI**: Terminal User Interface. The interactive menu (`-i`) on Unix.
- **UAC**: User Account Control, the Windows elevation prompt. eMerger
  relaunches itself elevated when needed.

---

## Development

### Repo layout

```text
eMerger/
├── src/
│   ├── emerger.sh          # Unix entry (Linux + macOS)
│   ├── emerger.ps1         # Windows entry
│   ├── lib/                # bash libs
│   ├── pslib/              # PowerShell libs
│   └── logo/
├── share/profiles/         # shipped profiles (*.sh + *.ps1)
├── share/plugins/          # example plugins
├── completions/            # bash/zsh/fish completions
├── tests/                  # bats tests
├── man/up.1                # man page
├── doc/                    # printable documentation
├── setup.sh     setup.ps1
├── uninstall.sh uninstall.ps1
├── update.sh    update.ps1
├── VERSION
└── .github/workflows/ci.yml
```

### Unix lib modules (`src/lib/`)

| File | Role |
|---|---|
| `ui.sh` | Colors, glyphs, spinner, box, live-log monitor |
| `log.sh` | Structured logging (rotated) |
| `sys.sh` | OS/shell/battery/disk detection |
| `run.sh` | Command runner (dry-run, retry, progress) |
| `args.sh` | Argument parser |
| `packages.sh` | Per-manager dispatcher |
| `clean.sh` | Cache and trash cleaners |
| `hooks.sh` | User hook runner |
| `update.sh` | Self-update + cron/timer setup |
| `notify.sh` | Desktop notifications |
| `summary.sh` | Final banner, history persistence |
| `tui.sh` | Interactive menu |
| `lock.sh` | Global `flock` |
| `retry.sh` | Retry on transient failures |
| `reboot.sh` | Reboot-required detection |
| `diff.sh` | Package snapshots + diff |
| `disk.sh` | Disk-space precheck |
| `snapshot.sh` | snapper/timeshift/btrfs |
| `mirrors.sh` | Mirror rank/refresh |
| `resume.sh` | Resume cursor |
| `doctor.sh` | `--doctor` |
| `changelog.sh` | `--changelog PKG` |
| `report.sh` | Markdown export |
| `wizard.sh` | First-run wizard |
| `profiles.sh` | Profile loader |
| `progress.sh` | Output summary + highlight |
| `estimate.sh` | Step ETA from history |
| `ignore.sh` | Ignore list loader |
| `plugins.sh` | User plugin loader |
| `metrics.sh` | Prometheus textfile export |

### PowerShell lib modules (`src/pslib/`)

| File | Role |
|---|---|
| `UI.ps1` | Colors, glyphs, box, step |
| `Log.ps1` | Structured logging |
| `Sys.ps1` | OS, admin, battery, disk, UAC elevation |
| `Args.ps1` | Arg parser (shift + regex) |
| `Packages.ps1` | Manager dispatcher + `Run-Cmd` |
| `Clean.ps1` | `%TEMP%` and Recycle Bin |
| `Hooks.ps1` | `hooks\{pre,post}.d\*.ps1` |
| `Update.ps1` | `git pull` self-update + Task Scheduler |
| `Notify.ps1` | BurntToast (optional) |
| `Summary.ps1` | Final box, history, reboot detection |
| `Doctor.ps1` | `--doctor` |
| `Profiles.ps1` | Profile loader |
| `Help.txt` | Help text |

### Running tests

```sh
sudo apt-get install bats shellcheck
bats tests/
shellcheck -S error src/emerger.sh src/lib/*.sh setup.sh uninstall.sh update.sh
```

Both run on push via `.github/workflows/ci.yml`.

### Adding a package manager

**Unix** - edit [`src/lib/packages.sh`](src/lib/packages.sh):
1. Add its name to `PKG_MANAGERS`.
2. Add a branch in `_pkg_detect_raw`.
3. Add a branch in `pkg_run` with `run_cmd` calls.
4. If it doesn't need sudo, exclude it from `pkg_needs_sudo`.
5. Optional: emoji in `pkg_icon`, output parser in `progress.sh`.

**Windows** - edit [`src/pslib/Packages.ps1`](src/pslib/Packages.ps1):
1. Add its name to `$script:PKG_MANAGERS` (or `PKG_DEV`).
2. Add a `Pkg-Detect` case.
3. Add a `Pkg-Run` case with `Run-Cmd` calls.
4. If it needs admin, add it to `Pkg-Need-Admin`.

### Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Open issues and PRs against
`dev`. Include `up --doctor` output and the relevant chunk of the log when
reporting bugs.

---

## License

See [LICENSE](./LICENSE).

## Credits

Weather line via [wttr.in](https://github.com/chubin/wttr.in).
