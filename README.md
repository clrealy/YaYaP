# YaYaP — Yet Another "Yet Another" Program

Because "Yet Another Program" was already taken. 🐧

A small, dependency-light **Linux toolbox** written in pure Bash. One command,
a bunch of handy subcommands, works on basically any distro.

```
$ yayap
 __   __    __   __     ____
 \ \ / /_ _ \ \ / /_ _ |  _ \
  \ V / _` | \ V / _` || |_) |
   | | (_| |  | | (_| ||  __/
   |_|\__,_|  |_|\__,_||_|
  Yet Another "Yet Another" Program  v0.1.0
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

## Commands

| Command    | What it does |
|------------|--------------|
| `sysinfo`  | OS, kernel, uptime, CPU, memory, disk, battery at a glance |
| `disk`     | Filesystem usage + biggest directories under a path |
| `bigfiles` | Largest files under a path (`-n N`, `-m MIN_SIZE`) |
| `clean`    | Report reclaimable junk (caches, trash); `--force` deletes |
| `pkg`      | One syntax for apt / dnf / yum / pacman / zypper / apk / xbps |
| `ports`    | Listening TCP/UDP ports and their processes |
| `killport` | Kill whatever is listening on a port |
| `myip`     | Local interface addresses + public IP |
| `extract`  | Extract tar/zip/7z/rar/gz/bz2/xz/zst/deb/rpm |
| `backup`   | Timestamped `.tar.gz` backups (`-o OUTDIR`) |
| `passgen`  | Random passwords (`-l LEN`, `-c COUNT`, `-s` simple) |
| `serve`    | HTTP server for a directory (`-p PORT`) |
| `weather`  | Terminal weather via wttr.in |
| `yap`      | A cow-ish yak dispensing wisdom |

`yayap help <command>` or `yayap <command> -h` shows details.
Global flags: `-y/--yes` (auto-confirm prompts), `--no-color` (or `NO_COLOR=1`),
`-V/--version`.

### Examples

```sh
yayap pkg install htop        # same command on Debian, Fedora, Arch, Alpine...
yayap pkg update
yayap bigfiles ~ -n 20
yayap clean                   # dry run
yayap clean --force
yayap extract stuff.tar.zst -d out/
yayap backup ~/notes ~/.config/nvim
yayap passgen -l 32 -c 5
yayap killport 3000
```

## Adding your own command

Drop a file in `lib/commands/<name>.sh`:

```bash
# about: Say hi
cmd_hello() { info "hello, ${1:-world}"; }
cmd_hello_help() { echo "Usage: yayap hello [NAME]"; }   # optional
```

That's it — it shows up in `yayap help` automatically. Helpers like
`info`, `ok`, `warn`, `die`, `kv`, `has`, `need`, `as_root`, `confirm`, and
`human_size` come from `lib/core.sh`.

## Tests

```sh
tests/run.sh
```

## License

MIT
