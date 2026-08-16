# Markdown cheatsheet popup

A system-wide markdown cheatsheet popup for macOS. Press **⌃⌥M** anywhere to
instantly show a floating window with a rendered markdown cheatsheet; press
**Esc**, ⌃⌥M again, or click outside to dismiss. 

## Installation

Requires macOS.

1. Install [Homebrew](https://brew.sh) if you don't already have it.
2. Install Hammerspoon and pandoc:
   ```sh
   brew install --cask hammerspoon
   brew install pandoc
   ```
3. Grant Hammerspoon Accessibility permission: **System Settings → Privacy &
   Security → Accessibility** → enable Hammerspoon. (Required for the hotkey
   and for the popup to take keyboard focus.)
4. Clone this repo to `~/Workshop/md-cheatsheet` (or elsewhere, if you also
   update the path in step 5 and `mdPath` in `cheatsheet.lua`):
   ```sh
   git clone <this-repo-url> ~/Workshop/md-cheatsheet
   ```
5. Point Hammerspoon at the module. If you don't already have a
   `~/.hammerspoon/init.lua`, create one containing:
   ```lua
   -- Load the cheatsheet popup from its repo, so the repo stays the source of
   -- truth and this file is just a pointer.
   package.path = os.getenv("HOME") .. "/Workshop/md-cheatsheet/?.lua;" .. package.path

   local cheatsheet = require("cheatsheet")
   cheatsheet.start()
   ```
   If you already have an `init.lua` for other Hammerspoon config, append
   these lines to it instead of replacing the file.
6. Reload Hammerspoon's config (menu-bar icon → **Reload Config**).
7. Press **⌃⌥M** to open the cheatsheet; **Esc**, ⌃⌥M again, or clicking
   outside closes it.

**Apple Silicon vs. Intel:** `cheatsheet.lua` invokes pandoc by absolute path
(`hs.task` doesn't reliably see your shell `PATH`), defaulting to
`/opt/homebrew/bin/pandoc` (Apple Silicon Homebrew). On an Intel Mac,
Homebrew installs to `/usr/local`, so run `which pandoc` and update
`pandocPath` in `cheatsheet.lua` if it differs.

Optional: enable "Launch Hammerspoon at login" in Hammerspoon's menu-bar
preferences so the hotkey is available after every restart.

## How it works

- **Hammerspoon** provides the hotkey, window, and rendering host. 
- `cheatsheet.lua` is the whole implementation. On hotkey it renders
  `cheatsheet.md` → HTML via **pandoc** (`hs.task`, absolute path
  `/opt/homebrew/bin/pandoc` because Hammerspoon's PATH is unreliable), wraps
  it in an HTML template with embedded light/dark CSS, and shows it in a
  floating `hs.webview` (titled/closable/utility/resizable style, titled
  "Markdown Cheatsheet - ESC to close", fixed 600px width and
  screen-relative height).
- **Caching:** rendered HTML is cached with the source file's mtime; pandoc
  only re-runs when the file changes, so repeat toggles are instant.
- **First-open warm-ups:** at load, a pandoc render pre-fills the cache, and a
  1x1 invisible "ghost" webview (deleted after 1 s) pre-pays the one-time
  WebKit helper-process spawn and accessibility-subsystem init — the first
  `hswindow()` call in a process alone blocks 1–2 s. This took first-open from
  ~3 s to ~90 ms.
- **Dismissal:** the window takes keyboard focus on open (required — Esc via
  `closeOnEscape` and click-outside via `focusChange` only work on the key
  window) and focus returns to the previous app on dismiss, except on
  click-outside where the clicked app keeps focus naturally. The window is
  destroyed (not hidden) on every dismiss and recreated on open; recreation is
  cheap because of the warm-ups and HTML cache.
- `cheatsheet.toggle` is exposed on the module so the popup can be driven
  programmatically (e.g. a future Alfred keyword via `hs -c`).

## Hammerspoon webview gotchas 

- `hs.webview:level()` takes an **integer** from `hs.drawing.windowLevels`;
  a string like `"floating"` throws and silently kills the calling callback
  (the error only shows in the Hammerspoon console).
- The webview window **never becomes key** unless `allowTextEntry(true)` is
  set — `HSWebViewWindow.canBecomeKeyWindow` returns that ivar, default NO.
  No key status means no Esc handling and no focusChange events at all.
- `deleteOnClose` defaults to **false** for `hs.webview.new` — Esc/close-button
  then only hides the window and leaks the webview object.

## Files

- `cheatsheet.md` — the content; edit freely (currently a markdown syntax
  reference, checked against markdownguide.org's cheat sheet — every row is
  verified to render correctly with the exact pandoc invocation
  `cheatsheet.lua` uses, `pandoc -f markdown+smart -t html5`).
- `cheatsheet.lua` — the Hammerspoon module (all logic).
- `~/.hammerspoon/init.lua` — two-line pointer (`package.path` + `require`).

## Dependencies & caveats

- Hammerspoon must be running with Accessibility permission.
- "Launch Hammerspoon at login" is a manual GUI setting.