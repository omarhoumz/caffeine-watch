# caffeine-watch

Menu bar indicator for macOS sleep prevention. Shows whether `caffeinate` (or any other process) is keeping the Mac awake, and who.

- Icon: steaming mug = `caffeinate` running · full mug = another app preventing sleep · empty mug = nothing.
- Popover: for each holder, the command line, pid, parent (tmux session name when inside tmux), uptime, and what it prevents (display / idle system / system sleep / disk idle). Other apps are listed in a collapsible section.
- Actions: Kill (caffeinate only, with a confirm), Turn display off now (`pmset displaysleepnow`), Launch at login, Quit.
- Polls `pmset -g assertions`, `ps`, and `tmux list-panes` every 5 s. powerd's "prevent sleep while display is on", WindowServer's UserIsActive and BackgroundTask are ignored as baseline noise.

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

## Build and run

```sh
./build.sh && open build/CaffeineWatch.app
```

## CLI

The same binary prints the popover contents in the terminal. Exit code is 0 while caffeinate is running, 1 otherwise.

```sh
ln -sf "$PWD/build/CaffeineWatch.app/Contents/MacOS/CaffeineWatch" ~/.local/bin/caffeine-watch
caffeine-watch status
```

## Install and launch at login

```sh
./build.sh && cp -R build/CaffeineWatch.app ~/Applications/ && open ~/Applications/CaffeineWatch.app
```

Then tick **Launch at login** in the popover. It uses `SMAppService`, which may refuse an ad-hoc-signed app; if the toggle springs back off, add it manually:

```sh
osascript -e 'tell application "System Events" to make login item at end with properties {path:(POSIX path of (path to home folder)) & "Applications/CaffeineWatch.app", hidden:false}'
```

or System Settings → General → Login Items → `+`.
