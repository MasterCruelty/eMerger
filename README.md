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

---

## Table of contents

1. [Platforms at a glance](#platforms-at-a-glance)
2. [Quickstart](#quickstart)
3. [Requirements](#requirements)
4. [Installation](#installation)
   - [Linux](#install-linux)
   - [macOS](#install-macos)
   - [Windows](#install-windows)
5. [Uninstallation](#uninstallation)
6. [Update / self-update](#update--self-update)
7. [User manual](#user-manual)
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
8. [Configuration](#configuration)
   - [config file](#config-file)
   - [Profiles](#profiles)
   - [Hooks](#hooks)
   - [Ignore list (Linux)](#ignore-list-linux)
   - [Quiet hours](#quiet-hours)
   - [Manager plugins](#manager-plugins)
9. [Integration](#integration)
   - [JSON output](#json-output)
   - [Prometheus metrics](#prometheus-metrics)
   - [Reboot exit code](#reboot-exit-code)
   - [Download-only / offline](#download-only--offline)
   - [Manager filtering](#manager-filtering)
   - [Rollback](#rollback)
   - [Short flag bundling](#short-flag-bundling)
10. [Auto-update (unattended)](#auto-update-unattended)
11. [Files & paths](#files--paths)
12. [Supported package managers](#supported-package-managers)
13. [Exit codes](#exit-codes)
14. [Troubleshooting](#troubleshooting)
15. [Development](#development)
16. [License](#license)

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
| Config dir | `~/.config/emerger/` | `~/.config/emerger/` | `%APPDATA%\emerger\` |
| State dir | `~/.local/state/emerger/` | `~/.local/state/emerger/` | `%LOCALAPPDATA%\emerger\state\` |

Feature parity is kept for the core flow (detect → upgrade → clean → summary).
Platform-specific features are documented below.

---

## Quickstart

**Linux / macOS**
```sh
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
./setup.sh
# open a new shell (or: source ~/.bashrc)
up --help
up -n
up
```

**Windows** (PowerShell)
```powershell
git clone https://github.com/MasterCruelty/eMerger
cd eMerger
.\setup.ps1
# open a new PowerShell window (or: . $PROFILE)
up --help
up -n
up
```

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
wipe.

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

What happens:

1. Show logo + OS info + timestamp (skippable with `-nl`/`-ni`).
2. Warn on low battery.
3. Warn on low disk space (`/` on Unix, `C:` on Windows).
4. Cache sudo credentials (Unix) or relaunch elevated (Windows) if any
   detected manager needs it.
5. Snapshot installed packages (for diff).
6. Run `pre.d` hooks.
7. For each detected manager, run refresh → upgrade → clean.
8. Optionally clean user cache / `%TEMP%` and trash / recycle bin.
9. Run `post.d` hooks.
10. Compute diff.
11. Print boxed summary + reboot advisory.
12. Emit desktop notification (if session has a display / BurntToast is
    installed on Windows).

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
order. Short bundling (`-nv` for `-n -v`) is **not** supported; keep them
space-separated.

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
`--report FILE`) must keep their argument adjacent; everything else is
position-free. CLI flags always win over config file and profile defaults,
so you can override a profile on the fly:

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

### Quiet levels

- default - full UI
- `-q` - hide muted/info lines
- `-qq` - only step titles + one-line summary
- `-qqq` - exit code only

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

Updates `rustup`, `cargo install-update -a`, `npm update -g`, `pnpm -g update`,
`pip` (user), `gem update`.

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

Exits non-zero if issues are found.

---

## Configuration

### config file

**Linux / macOS** - `~/.config/emerger/config.sh` (sourced before arg parsing):

```sh
ARG_DEV=1                 # always include dev toolchains
ARG_WEATHER=1             # always show weather
DISK_MIN_FREE_MB=2048     # require >= 2 GB on /
QUIET_HOURS="23:00-07:00" # skip scheduled runs inside this window
RETRY_MAX=3               # transient-error retries
```

**Windows** - `%APPDATA%\emerger\config.ps1` (dot-sourced before arg parsing):

```powershell
$script:ArgsGlobal.Dev      = $true
$script:ArgsGlobal.Security = $true
$script:ArgsGlobal.NoTrash  = $true
```

### Profiles

Profiles are config snippets scoped to a name.

```sh
up --profile work
up --list-profiles
```

Shipped defaults in `share/profiles/`:

| Profile | Meant for |
|---|---|
| `work` | laptop al lavoro - security, unattended, no cache/trash |
| `home` | PC fisso - tutto, dev toolchains, parallel |
| `server` | headless - `-qq`, security, no prompts |
| `safe` | pre-presentation - security only, no big downloads |

Each platform looks for its own extension:

- Unix → `share/profiles/<name>.sh`
- Windows → `share/profiles/<name>.ps1`

User profiles go in `~/.config/emerger/profiles.d/` (Unix) or
`%APPDATA%\emerger\profiles.d\` (Windows) and shadow the shipped ones.

### Hooks

Drop executable scripts in `hooks/pre.d/` (before updates) or
`hooks/post.d/` (after). They run alphabetically. A failing hook emits a
warning but never aborts the run.

- Unix: `*.sh`, run under bash.
- Windows: `*.ps1`, dot-sourced under PowerShell.

Example:

```sh
# ~/.config/emerger/hooks/pre.d/10-backup-dotfiles.sh
#!/usr/bin/env bash
rsync -a ~/.config/ ~/backups/dotfiles/
```

```powershell
# %APPDATA%\emerger\hooks\post.d\10-log-to-gist.ps1
Get-Content (Join-Path $env:LOCALAPPDATA 'emerger\state\emerger.log') -Tail 20 |
    Set-Clipboard
```

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
immediately. Interactive runs always proceed. Linux/macOS.

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
    run_cmd "mytool update" mytool update || return 1
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
`EMERGER_CACHE_TTL=<seconds>` in `config.sh` (0 disables caching).

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

The same schema is what `history.jsonl` stores one per line.

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
simple table-driven dispatchers.

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
├── completions/            # bash/zsh/fish completions
├── tests/                  # bats tests
├── man/up.1                # man page
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
