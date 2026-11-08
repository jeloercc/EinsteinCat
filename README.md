# EinsteinCat 🐈‍⬛

<p align="center"><img src="Resources/cat_page0.png" width="112" alt="EinsteinCat"></p>

A cat that runs in the macOS menu bar: the more CPU is used, the faster it runs.
It also shows an animated kitten in the Touch Bar's Control Strip.

Based on [Menubar RunCat](https://github.com/Kyome22/menubar_runcat) by Takuto Nakamura
(Apache-2.0), using the same animation frames.

## Features

- **Menu bar:** the cat runs faster as CPU usage goes up. CPU is sampled every 5 seconds.
- **Cat menu:**
  - *Show CPU Usage* shows the CPU % next to the cat.
  - *About* opens the About panel.
  - *Quit* closes the app.
- **Touch Bar:** an animated kitten in the Control Strip (the right side of the Touch Bar).
  This uses **private macOS APIs** (see below).
- Doesn't show up in the Dock or in Cmd-Tab (`LSUIElement`).

## Requirements

- macOS 15 (Sequoia) on an Intel Mac (`x86_64`).
- Apple's Command Line Tools, which include `swiftc`. **Xcode is not needed.**
- A Touch Bar, only for the Touch Bar part. The menu bar part works without one.

## Build and run

```sh
./build.sh                    # creates build/EinsteinCat.app
open build/EinsteinCat.app    # launches it like a regular app
```

To see the app's log messages (handy for debugging), run it from the terminal instead:

```sh
build/EinsteinCat.app/Contents/MacOS/EinsteinCat
```

### What `build.sh` does

It does by hand what Xcode would normally do:

1. Deletes `build/EinsteinCat.app` if it exists, then creates `Contents/MacOS` and `Contents/Resources`.
2. Compiles with `swiftc -swift-version 5`, since the original code is Swift 5.
   - `-import-objc-header Sources/TouchBarPrivate.h` gives Swift the private API declarations.
3. Copies `Info.plist` and the cat PNGs into the bundle.
4. Checks the plist with `plutil -lint`.
5. Signs the app ad-hoc with `codesign --sign -` (no certificate).

## Project layout

```
EinsteinCat/
├── Sources/
│   ├── main.swift            app entry point (original)
│   ├── AppDelegate.swift     menu bar item and animation (original, modified)
│   ├── CPU.swift             CPU usage via host_statistics (original)
│   ├── TouchBar.swift        kitten in the Control Strip (new)
│   └── TouchBarPrivate.h     private Touch Bar API declarations (new)
├── Resources/                cat_page0.png … cat_page4.png (the 5 animation frames)
├── Info.plist
├── build.sh
├── CLAUDE.md                 project context and plan
└── LICENSE                   Apache-2.0
```

## The Touch Bar and private APIs

macOS has no public way for an app to put an item in the Control Strip. EinsteinCat uses
the same approach as [MTMR](https://github.com/Toxblh/MTMR):

| API | Kind | How it's used |
|---|---|---|
| `+[NSTouchBarItem addSystemTrayItem:]` / `removeSystemTrayItem:` | Private AppKit methods | Declared in `TouchBarPrivate.h` |
| `DFRElementSetControlStripPresenceForIdentifier` | Private C function in `DFRFoundation` | Loaded at launch with `dlopen`/`dlsym` |

`DFRFoundation` can't be linked at build time: since macOS 11 its binary isn't on disk,
it lives in the dyld shared cache. That's why it's loaded at runtime. If it can't be found,
the app logs a warning and the menu bar cat keeps working.

Because these APIs are private, **Apple can change or remove them** in any macOS release.

### Notes

- **MTMR and EinsteinCat can't run at the same time.** While MTMR shows its bar, it covers the Control Strip.
- The Control Strip is always on the right. macOS decides where the kitten goes.
- The Touch Bar animation is capped at 30 frames per second to avoid wasting CPU.

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Tools and resources | ✅ |
| 1 | `Info.plist` + `build.sh`: the cat runs in the menu bar | ✅ |
| 2 | Animated kitten in the Touch Bar's Control Strip | In progress |
| 3 | Tapping the kitten makes the cat run across the Touch Bar | Planned |
| 4 | Install to `/Applications` and launch at login | Planned |

## Known issues

- **It doesn't pause when the Mac sleeps.** This comes from the original: `setNotifications()` exists but is never called.
- During testing, the Touch Bar kitten **didn't always show up right away**. The cause is still unknown.
- In a quick measurement the app used 5–8 % of one core. How much of that is the Touch Bar hasn't been checked yet.
- The menu still says "Menubar RunCat" and the app has no icon of its own.
- Tapping the Touch Bar kitten only writes a log message for now. The real action is phase 3.

## Credits and license

- Original code and images: **Takuto Nakamura**, [Menubar RunCat](https://github.com/Kyome22/menubar_runcat),
  licensed under [Apache-2.0](LICENSE). Original files keep their copyright headers, and modified files say so in their header.
- The private Touch Bar API usage is based on [MTMR](https://github.com/Toxblh/MTMR) by Anton Palgunov.
- EinsteinCat is released under the same Apache-2.0 license.
