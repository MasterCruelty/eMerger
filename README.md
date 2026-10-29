# eMerger

[![CI](https://github.com/MasterCruelty/eMerger/actions/workflows/ci.yml/badge.svg)](https://github.com/MasterCruelty/eMerger/actions/workflows/ci.yml)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=sqale_rating)](https://sonarcloud.io/dashboard?id=MasterCruelty_eMerger)
[![Quality Gate Pass](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=alert_status)](https://sonarcloud.io/dashboard?id=MasterCruelty_eMerger)
[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=ncloc)](https://sonarcloud.io/dashboard?id=MasterCruelty_eMerger)

<p align="center">
    <img src="./src/logo/big_name.png" alt="eMerger logo" width="256">
</p>

One command, `up`, refreshes, upgrades and cleans every package manager on your Linux, macOS or Windows machine.

`up` finds the managers you have (`apt`, `dnf`, `pacman`, `brew`, `winget`, `flatpak`, `snap` and more), asks for `sudo` or a UAC prompt once if one of them needs it, runs each in turn and prints one summary. It runs on bash on Linux and macOS and on PowerShell on Windows. Nothing else is installed.

Every configuration and environment variable, the JSON fields and the plugin API are in [the documentation](doc/documentation.pdf) and the man page [man/up.1](man/up.1), which `install.sh` installs (`man up`).

## Quick start

1. Clone the repository: `git clone https://github.com/MasterCruelty/eMerger && cd eMerger`.
2. Run `./install.sh` (Linux, macOS) or `.\install.ps1` (Windows PowerShell).
3. Open a new terminal.
4. Run `up -n` to see what would run. Nothing changes.
5. Run `up` to update.

```text
$ up
  ◆ Debian GNU/Linux 13 · x86_64 · 2026-10-16 10:12 · eMerger v3.0.0

  🌀 apt  ~40s ──────────────────────────────────────── ▰▱ 1/2
    ✔ update ····················   6.8s
    ⠉ full-upgrade  .:::.   0:14  Unpacking libssl3 ...

  📦 flatpak ────────────────────────────────────────── ▰▰ 2/2
    ✔ update ····················  12.4s  5 refreshed

  ╭─ eMerger summary ──────────────────────────╮
  │ managers  ✔ apt  ✔ flatpak                 │
  │ time      0m42s                            │
  │ freed     812.0MB                          │
  │ status    ✔ all good                       │
  ╰────────────────────────────────────────────╯
```

Do not run `sudo up`: under `sudo`, user-level packages (`pip --user`, Homebrew, `npm -g`) land in root's home. `up` asks for `sudo` itself.

## What you need

| platform | required | optional |
|---|---|---|
| Linux | bash 4.4 or later, coreutils, git, sudo | `curl` (`-w`, `--doctor`), `flock`, `timeout`, `pkill` (stops `--parallel` managers on Ctrl-C), `notify-send`, `fwupdmgr`, `snapper` or `timeshift` or `btrfs-progs`, `reflector` or `netselect-apt` |
| macOS | bash 4.4 or later first in `PATH` (`/bin/bash` 3.2 is too old: `brew install bash`), Xcode Command Line Tools | Homebrew, `mas` |
| Windows | PowerShell 5.1 or 7, Git for Windows | `winget`, `scoop`, `choco`, the `PSWindowsUpdate` and `BurntToast` modules |

`up` installs none of these. It uses what it finds.

## Install

`./install.sh`:

- adds `alias up='bash "/path/to/eMerger/src/emerger.sh"'` to your bash, zsh and fish startup files (`~/.zshrc` first on macOS);
- installs completions for bash, zsh and fish, and the man page in `~/.local/share/man/man1/` (`man up`);
- creates `~/.config/emerger/` with `config.sh`, `ignore.list`, `hooks/` and `profiles.d/`.

A checkout path containing `'`, `"`, `$`, a backquote, `%`, `\` or a newline is refused: move the checkout first.

`.\install.ps1` needs no administrator rights:

- if the `CurrentUser` execution policy is `Restricted` or `Undefined`, it asks before setting `RemoteSigned`;
- it adds an `up` function to `$PROFILE.CurrentUserAllHosts`;
- it creates `%APPDATA%\emerger\` with `config.ps1`, `hooks\` and `profiles.d\`.

Without the install script, point an alias at the entry point: `alias up='bash /path/to/eMerger/src/emerger.sh'`, or in PowerShell `function up { & 'C:\path\to\eMerger\src\emerger.ps1' @args }`.

## Use

```sh
up                         # update everything
up -n -v                   # preview, with each manager's output
up --security -y           # unattended, security updates only
up --dev --firmware        # also dev toolchains and firmware (Linux)
up --only apt,flatpak      # these managers only
up --except snap           # every manager but snap
up --download-only -y      # download now, install on a later run
up --changed               # what the last run added, removed, upgraded
up --history               # the last runs
up --doctor                # check the environment
up -au                     # install a weekly unattended run
```

`up -au` runs `up -y -q -nl -ni` every Sunday at 10:00: a systemd user timer or cron on Linux, cron on macOS, Task Scheduler on Windows (a manager that needs admin raises a UAC prompt at that time). On Linux, a user timer needs a login session: run `loginctl enable-linger $USER` once to let it fire without one.

## Flags

`up --help` prints the same list. A flag that takes a value accepts `--flag VALUE` or `--flag=VALUE`. `--` ends the options. Short flags from the set `h V n v q y w` bundle: `-nv` is `-n -v`.

On Windows, a flag marked "Unix" prints a warning. The run goes on without it, except `--changed`, `--changelog` and `--rollback`, which exit 0 without updating.

| flag | effect | platforms |
|---|---|---|
| `-h`, `--help` | Show the help | all |
| `-V`, `--version` | Show the version | all |
| `--doctor` | Check the environment; exit non-zero on a warning | all |
| `-n`, `--dry-run` | Print the commands, change nothing | all |
| `-v`, `--verbose` | Stream each manager's output | all |
| `-q`, `--quiet` | One quieter level per use | all |
| `-qq` | Summary line only | all |
| `-qqq` | Nothing, exit code only | all |
| `-y`, `--yes` | Answer yes to every prompt | all |
| `--json` | One JSON summary on stdout | all |
| `--security` | Security updates only; managers without them are skipped | all |
| `--accept-licenses` | Let `softwareupdate`, `winget`, `choco` and Windows Update accept licence agreements; without it they only list updates | macOS, Windows |
| `--firmware` | Include `fwupdmgr` and the Raspberry Pi bootloader | Unix |
| `--no-firmware` | Skip firmware, even when the config sets `--firmware` | Unix |
| `--dev` | Include `rustup`, `cargo`, `npm`, `pnpm`, `pip`, `gem` | all |
| `--parallel` | Run user-space managers at the same time | Unix |
| `--profile NAME` | Load a profile before the flags | all |
| `--list-profiles` | List the profiles | all |
| `--only LIST` | Run only these managers (comma-separated) | all |
| `--except LIST` | Skip these managers; adds to the config's list | all |
| `--snapshot` | Take a snapper, timeshift or btrfs snapshot first, or exit 1 | Unix |
| `--rollback` | Revert to the latest eMerger snapshot | Unix |
| `--refresh-mirrors` | Re-rank the mirrors first | Unix |
| `--resume` | Skip the managers the last run finished | Unix |
| `--reboot` | Reboot now if the system needs it | all |
| `--reboot-exit` | Exit 4 instead of 0 when a reboot is pending | all |
| `--download-only` | Download without installing (apt, dnf, pacman, zypper, softwareupdate); skip every other manager | Unix |
| `-nl`, `--no-logo` | Hide the logo | all |
| `-ni`, `--no-info` | Hide the system line | all |
| `-w`, `--weather` | Show a weather line from wttr.in | all |
| `--ascii` | ASCII glyphs only | all |
| `-nc`, `--keep-cache` | Skip user cache cleaning (Windows: `%TEMP%`) and, on Linux, the warning about space still held by deleted files that a program keeps open | all |
| `-nt`, `--keep-trash` | Skip trash cleaning (Windows: Recycle Bin) | all |
| `--deep-clean` | Also clean the journal, old kernels, leftover configs, snap revisions, crash dumps, npm and Go caches and unused docker and podman data, asking for each | Unix |
| `--changed` | Show the last run's package changes | Unix |
| `--changelog PKG` | Show the upstream changelog of `PKG` | Unix |
| `--history` | Show the last runs | all |
| `--metrics FILE` | Export the last run as a Prometheus textfile | all |
| `-err`, `--errors` | Show logged errors | all |
| `-up`, `--self-update` | Update eMerger with `git pull --ff-only` | all |
| `-au`, `--auto-update` | Install the weekly run | all |
| `-rc`, `--rebuild-cache` | Clear the manager detection cache (Windows keeps none) | all |

## Configure

`~/.config/emerger/config.sh` (Windows: `%APPDATA%\emerger\config.ps1`) runs before the flags, so it sets your defaults. The flags win.

```sh
# ~/.config/emerger/config.sh
ARG_DEV=1                   # as --dev on every run
ARG_EXCEPT="snap"           # as --except snap
DISK_MIN_FREE_MB=2048       # ask before updating with less free space
QUIET_HOURS="23:00-07:00"   # a run with -y inside this window does nothing
```

```powershell
# %APPDATA%\emerger\config.ps1
$script:ArgsGlobal.Dev = $true
$script:MANAGER_TIMEOUT = 3600
```

Everything you can customize lives in `~/.config/emerger/` (Windows: `%APPDATA%\emerger\`, with `.ps1` files):

| put this | in | and you get |
|---|---|---|
| your fixed settings | `config.sh` | defaults for every run, such as "always skip snap" |
| a named set of settings | `profiles.d/NAME.sh` | `up --profile NAME` applies it; `work`, `home`, `server` and `safe` ship ready to use |
| your own scripts | `hooks/pre.d/`, `hooks/post.d/` | they run before or after the update, in name order (a backup first, a notification after) |
| a package manager `up` does not know | `managers.d/NAME.sh` (Unix) | `up` updates it like the others; [share/plugins/example.sh](share/plugins/example.sh) is a template |
| packages to leave alone | `ignore.list` (Linux) | pacman never upgrades them |

`up` loads a config file, profile, hook or plugin only when you own it and no other user can write to it.

Every variable, its default and the plugin API: [the documentation](doc/documentation.pdf), section Configuration.

## Files

| file | Linux and macOS | Windows |
|---|---|---|
| config | `~/.config/emerger/config.sh` | `%APPDATA%\emerger\config.ps1` |
| profiles | `~/.config/emerger/profiles.d/`, shipped `share/profiles/` | `%APPDATA%\emerger\profiles.d\`, shipped `share\profiles\` |
| hooks | `~/.config/emerger/hooks/pre.d/`, `hooks/post.d/` | `%APPDATA%\emerger\hooks\pre.d\`, `hooks\post.d\` |
| plugins | `~/.config/emerger/managers.d/` | none |
| ignore list | `~/.config/emerger/ignore.list` | none |
| detection cache | `~/.cache/emerger/detected` | none |
| log | `~/.local/state/emerger/emerger.log` | `%LOCALAPPDATA%\emerger\state\emerger.log` |
| run history | `~/.local/state/emerger/history.jsonl` | `%LOCALAPPDATA%\emerger\state\history.jsonl` |
| package lists | `~/.local/state/emerger/pkgs.before`, `pkgs.after`, `pkgs.diff` | none |
| resume cursor | `~/.local/state/emerger/resume` | none |
| run lock | `~/.local/state/emerger/emerger.lock` | `%LOCALAPPDATA%\emerger\state\run.lock`, `elevated.lock` |
| parallel output | `~/.local/state/emerger/parallel-*.log` | none |

`XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `XDG_STATE_HOME` move the Unix directories.

## Exit codes

| code | meaning |
|---|---|
| 0 | success |
| 1 | runtime failure (sudo, lock, disk, interrupted), or aborted (a declined safety prompt, no snapshot taken with `--snapshot`) |
| 2 | bad argument |
| 3 | one or more managers failed |
| 4 | reboot pending, only with `--reboot-exit` |

## Security

- `up` changes only what you ask for. Cleaning the cache, the Trash and `--deep-clean` ask before deleting anything.
- On its own, `up` goes online only for `--weather`, `--self-update`, `--firmware`, `--refresh-mirrors` and one connectivity check in `--doctor`. All other traffic comes from your package managers.
- `up` runs with `sudo`, so keep the eMerger folder writable by you alone. If other users can write to it, `up` refuses to start.
- Your config, profiles, plugins and hooks follow the same rule: `up` skips any that another user could change.

## Update and remove

- **Update:** run `up --self-update`. It never overwrites your own changes.
- **Remove:** run `./uninstall.sh` (Windows: `.\uninstall.ps1`). It removes everything the install script added, then asks whether to delete your settings, history and cache too (no by default). Then delete the eMerger folder.

## Problems

**"Another eMerger run is in progress"**: another `up` is still running. Wait for it to finish. Do not delete the lock file.

**A manager failed (exit code 3)**: run `up --errors` to see why, and `up --doctor` to check your system. Usually the manager needs a repair first (for apt: `sudo dpkg --configure -a`), then run `up` again.

**It stops at "User cache" or "Trash"**: it is asking yes or no. After 60 seconds it answers no. Use `-y` to answer yes.

**Emoji show up as boxes**: install a color-emoji font, or run `up --ascii`.

**macOS says "cannot read the Trash"**: give your terminal Full Disk Access in System Settings, Privacy & Security.

**Windows does not recognize `up`**: open a new PowerShell window.

**Windows says "running scripts is disabled"**: run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

More answers are in [the documentation](doc/documentation.pdf), section Troubleshooting.

## Development

- **Tests:** `bats tests/`. Some tests need `pwsh`, `zsh`, `fish` or `shellcheck`, and are skipped when the tool is missing.
- **Lint:** `shopt -s globstar; shellcheck -S error install.sh uninstall.sh src/emerger.sh src/lib/**/*.sh share/plugins/*.sh share/profiles/*.sh completions/up.bash` (the same check CI runs).
- **Documentation:** edit [doc/documentation.tex](doc/documentation.tex), then run `pdflatex documentation.tex` twice inside `doc/` (the second run fills in the table of contents and the section references).
- **Code:** `src/emerger.sh` and [src/lib/](src/lib/) for Linux and macOS, `src/emerger.ps1` and [src/pslib/](src/pslib/) for Windows. Both halves must behave the same.
- **Adding a package manager:** see [the documentation](doc/documentation.pdf), section Development.
- **Third-party material:** [reference/third-party.md](reference/third-party.md).
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT, see [LICENSE](LICENSE).
