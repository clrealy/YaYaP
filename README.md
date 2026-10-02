<p align="center"><img src="share/banner.svg" alt="YaYaP: Yet Another &quot;Yet Another&quot; Program" width="640"></p>

# YaYaP — Yet Another "Yet Another" Program

Because "Yet Another Program" was already taken. Meet the mascot: a parrot,
because it's yet another "yet another" and parrots repeat themselves. 🦜

A **YaST-style Linux control center** written in Bash. Like YaST it comes three
ways: a **desktop app** (`yayap gui`), a **terminal UI** (`yayap`), and plain
**commands** (`yayap services restart sshd`). Categories are Software, System,
Hardware, Network, Security and Users, and Misc. Works on basically any distro:
Debian, Fedora, Arch, openSUSE, Alpine and friends.

```
┌───────────────────┤  YaYaP Control Center  ├───────────────────┐
│ Yet Another "Yet Another" Program — pick a category            │
│                                                                │
│                Software           1 module                     │
│                System             6 modules                    │
│                Hardware           3 modules                    │
│                Network            5 modules                    │
│                Security and Users 3 modules                    │
│                Misc               3 modules                    │
│                                                                │
│             <Ok>                         <Quit>                │
└────────────────────────────────────────────────────────────────┘
```

## Install

With [GURT](https://github.com/clrealy/GURT) 🦆 (works on any distro):

```sh
gurt install yayap
```

Don't have gurt yet?

```sh
curl -fsSL https://raw.githubusercontent.com/clrealy/GURT/main/install.sh | sh
gurt install yayap
```

Or by hand:

```sh
git clone https://github.com/clrealy/YaYaP && cd YaYaP
./install.sh                     # installs to ~/.local (no root needed)
PREFIX=/usr/local sudo ./install.sh   # or system-wide
./install.sh --uninstall
DESTDIR=/tmp/pkg PREFIX=/usr/local ./install.sh   # staged install for packagers
```

Or just run it in place: `./bin/yayap`.

## The GUI 🖥️

```sh
yayap gui               # opens the Control Center as a desktop app
yayap gui --no-window   # just print the URL (e.g. to open it yourself)
```

- YaST-style layout: categories on the left, module tiles on the right, then
  each module's actions as cards with input fields and a live output console
  (with a Stop button for things like `serve` or `logs -f`)
- **sudo password**, "are you sure?" and new-password prompts pop up as
  dialogs in the app
- Search box (press `/`), light and dark mode, works on narrow windows too
- Opens in a real app window using GTK-WebKit, Qt-WebEngine or pywebview if
  you have one, otherwise Chromium/Chrome/Brave in app mode, otherwise your
  browser. It needs nothing but `python3`
- Locked down: listens on `127.0.0.1` only, on a random port, with a secret
  token per launch. It only runs YaYaP's own module actions, never a shell.
  It quits by itself a little while after you close the window
- Shows up in your app menu as **YaYaP Control Center** (the terminal version
  is there too)

## The terminal Control Center

Like YaST, YaYaP is organised as **categories → modules → actions**:

```sh
yayap                 # on a terminal: opens the Control Center
yayap center          # same thing, explicitly
yayap center --list   # print every module and action as a tree
```

- Uses **whiptail** or **dialog** for the ncurses look when installed, or falls
  back to a plain numbered menu, so it runs anywhere. Force one with
  `YAYAP_UI=whiptail|dialog|plain`
- Actions that need input (a service name, a port, a user…) ask for it
- Every action is just a normal command underneath, and the center shows
  you which one it runs, so you learn the CLI as you click around

## Modules

| Category | Module | What it does |
|---|---|---|
| Software | `pkg` | Install / remove / search / online update, one syntax for apt, dnf, yum, pacman, zypper, apk, xbps |
| System | `services` | Services Manager: list, start, stop, restart, enable, disable, logs (systemd + OpenRC) |
| System | `datetime` | Clock, time zone, network time (NTP) |
| System | `logs` | System log viewer: recent, errors only, this boot, follow, per unit |
| System | `clean` | Report reclaimable junk (caches, trash); `--force` deletes |
| System | `backup` | Timestamped `.tar.gz` backups (`-o OUTDIR`) |
| System | `bigfiles` | Largest files under a path (`-n N`, `-m MIN_SIZE`) |
| Hardware | `hardware` | CPU, memory, disks, PCI and USB devices |
| Hardware | `sysinfo` | OS, kernel, uptime, CPU, memory, disk, battery at a glance |
| Hardware | `disk` | Filesystem usage + biggest directories |
| Network | `hostname` | Show or change the hostname |
| Network | `ports` | Listening TCP/UDP ports and their processes |
| Network | `killport` | Kill whatever is listening on a port |
| Network | `myip` | Local interface addresses + public IP |
| Network | `serve` | HTTP server for a directory (`-p PORT`) |
| Security and Users | `users` | User and Group Management: list, add, delete, passwords, groups |
| Security and Users | `firewall` | Status, open/close ports, on/off (ufw or firewalld) |
| Security and Users | `passgen` | Random passwords (`-l LEN`, `-c COUNT`, `-s` simple) |
| Misc | `ouroboros` | The snake eats itself: YaYaP backs itself up, hatches from the copy, N times, and checks it's still byte-for-byte itself 🐍 |
| Misc | `extract` | Extract tar/zip/7z/rar/gz/bz2/xz/zst/deb/rpm |
| Misc | `weather` | Terminal weather via wttr.in |
| Misc | `yap` | A cow-ish yak dispensing wisdom |

`yayap help <module>` or `yayap <module> -h` shows details.
Global flags: `-y/--yes` (auto-confirm prompts), `--no-color` (or `NO_COLOR=1`),
`-V/--version`. Anything that changes the system uses `sudo`/`doas` only when
it has to.

### Examples

```sh
yayap pkg install htop            # same command on Debian, Fedora, Arch, Alpine...
yayap pkg update                  # "online update"
yayap services restart sshd
yayap services enable docker
yayap users add alex
yayap users addgroup alex docker
yayap firewall allow 8080/tcp
yayap datetime set-tz Europe/Berlin
yayap logs -e -b                  # errors from this boot
yayap hardware usb
yayap clean --force
yayap extract stuff.tar.zst -d out/
```

## The ouroboros 🐍

"Yet Another 'Yet Another'" already eats its own tail, so YaYaP does too:

```sh
yayap ouroboros            # 3 generations
yayap ouroboros -n 10
yayap ouroboros --fingerprint
```

YaYaP packs itself up with its own `backup` module, unpacks the copy with its
own `extract` module, and hands over to the copy, which does it all again. The
last generation compares its fingerprint (sha256 of `bin/` + `lib/`) with the
first one's. If they match, the snake caught its tail, which also proves the
install can rebuild itself from its own backups.

## Website

The site lives in [`site/`](site). `tools/build-site.sh` builds it into
`_site/` with live data from the code (the module list, the version, and a real
`yayap ouroboros` run), and `.github/workflows/pages.yml` publishes it to
GitHub Pages from the default branch.

## Adding your own command

Drop a file in `lib/commands/<name>.sh`:

```bash
# about: Say hi
# category: Misc
# icon: 👋
cmd_hello() { info "hello, ${1:-world}"; }
cmd_hello_help() { echo "Usage: yayap hello [NAME]"; }   # optional

# optional: menu entries for the Control Center, "Label|args".
# {Some_prompt} asks the user for a value; {Things...} splits it into several args.
cmd_hello_actions() {
    cat <<'A'
Say hi to the world|
Say hi to someone|{Name}
A
}
```

That's it — it shows up in `yayap help`, the terminal Control Center and the
GUI automatically. If an action asks "are you sure?", use `confirm`; for
passwords use `ask_secret`, and for root use `as_root`. Those three
automatically become dialogs in the GUI. Helpers like
`info`, `ok`, `warn`, `die`, `kv`, `has`, `need`, `as_root`, `confirm`, and
`human_size` come from `lib/core.sh`.

## Tests

```sh
tests/run.sh          # everything (includes tests/gui_test.py when python3 is around)
```

## License

MIT
