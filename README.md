# Matchstick

A tiny macOS menu bar app that keeps your Mac awake.

Click the match to light it, and your Mac stays awake until you click it again. Right-click for a timer. During a timed session the match burns down as the time runs out.

## Install

Matchstick needs macOS 13 or newer. It is built for Apple silicon and Intel Macs, and tested on Apple silicon.

1. Download the `.dmg` file from the [latest release](https://github.com/freonoma/matchstick/releases/latest).
2. Open it and drag **Matchstick** onto **Applications**.
3. Open Matchstick from Applications. Look for the match in the menu bar, near the clock. There is no Dock icon.

The download is signed with an Apple Developer ID and notarized by Apple.

To update, download the newer `.dmg`, quit Matchstick from its menu and replace the app in Applications. Your settings and stats stay as they are.

## How it works

- **Left click** turns it on or off.
- **Right click** (or Control-click) opens the menu: keep awake for 30 minutes, 1 hour, 2 hours, a time you choose, or until you turn it off.
- **Let the screen turn off** keeps the Mac awake but lets the display sleep.
- The menu also shows how long Matchstick has kept your Mac awake today and this week.
- **Launch at login** starts it with your Mac. It always starts off.

Matchstick only stops your Mac from falling asleep on its own. Closing the lid or choosing Sleep from the Apple menu still works.

It holds standard macOS power assertions, the same mechanism as `caffeinate`. You can see them with `pmset -g assertions`. They belong to the app, so macOS drops them if Matchstick quits or crashes.

## Build from source

You need Xcode 16 or newer (or its command line tools). There are no other dependencies.

```sh
make run
```

This builds `build/Matchstick.app` and opens it. Look for the match in the menu bar. There is no Dock icon.

To install it:

```sh
make install
```

This copies the app to `/Applications`. Open it from there, especially if you want to use Launch at login.

Other targets:

| Command | What it does |
| --- | --- |
| `make app` | Builds `build/Matchstick.app` without opening it |
| `make debug` | Runs a debug build, which adds a 1 minute timer for testing |
| `make dmg` | Builds a disk image for Apple silicon and Intel (needs the full Xcode) |
| `make icon` | Redraws the app icon, using the same code as the menu bar icon |
| `make clean` | Removes the build folders |

A build you make this way is signed ad hoc and not notarized, which is fine for a copy you build yourself.

## License

[MIT](LICENSE)
