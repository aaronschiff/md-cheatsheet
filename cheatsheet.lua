-- Markdown cheatsheet popup.
--
-- ctrl+alt+M toggles a floating window showing cheatsheet.md rendered to HTML
-- by pandoc. Esc, re-pressing the hotkey, or clicking outside the window
-- dismisses it. Rendered HTML is cached; pandoc only re-runs when the .md
-- file's modification time changes, so repeat toggles are instant. Load-time
-- warm-ups (a pandoc render, plus a ghost webview that pre-pays WebKit's
-- process spawn and the one-time accessibility-subsystem init) make the
-- first toggle instant too.

local M = {}

local home = os.getenv("HOME")
local mdPath = home .. "/Workshop/md-cheatsheet/cheatsheet.md"
local pandocPath = "/opt/homebrew/bin/pandoc"

local webview = nil -- hs.webview while the popup is open
local rendering = false -- a pandoc render is in flight
local showWhenRendered = false -- show the popup once the in-flight render lands
local cachedHtml = nil
local cachedMtime = nil
local previousApp = nil -- app to return focus to when the popup closes
local warmupTimer = nil -- module-level so the timer can't be garbage-collected

local css = [[
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
    font-size: 14px;
    line-height: 1.55;
    margin: 0 auto;
    padding: 4px 26px 22px;
    max-width: 780px;
    background: #f7f7f8;
    color: #24292f;
  }
  h1 { font-size: 19px; margin: 12px 0 8px; }
  h2 { font-size: 15.5px; margin: 20px 0 6px; padding-bottom: 3px; border-bottom: 1px solid #d8d8dd; }
  h3 { font-size: 14px; margin: 14px 0 4px; }
  p, ul, ol { margin: 6px 0; }
  li { margin: 2px 0; }
  code, pre { font-family: ui-monospace, Menlo, monospace; font-size: 12.5px; }
  code { background: #e9e9ec; padding: 2px 5px; border-radius: 5px; }
  pre { background: #e9e9ec; padding: 10px 14px; border-radius: 8px; overflow-x: auto; }
  pre code { background: none; padding: 0; }
  blockquote { margin: 8px 0; padding: 2px 14px; border-left: 3px solid #c8c8cf; color: #555; }
  table { border-collapse: collapse; margin: 8px 0; }
  th, td { padding: 4px 14px 4px 0; border-bottom: 1px solid #d8d8dd; text-align: left; }
  a { color: #0969da; text-decoration: none; }
  hr { border: none; border-top: 1px solid #d8d8dd; margin: 16px 0; }
  @media (prefers-color-scheme: dark) {
    body { background: #232326; color: #e8e8ea; }
    h2 { border-bottom-color: #45454c; }
    code { background: #3a3a41; }
    pre { background: #303036; }
    pre code { background: none; }
    blockquote { border-left-color: #55555d; color: #b0b0b6; }
    th, td { border-bottom-color: #45454c; }
    a { color: #5ea0f8; }
    hr { border-top-color: #45454c; }
  }
]]

local function page(body)
  return '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
    .. css
    .. '</style></head><body>'
    .. body
    .. "</body></html>"
end

-- Return focus to the app that was frontmost before the popup took it, but
-- only if Hammerspoon still has focus. On click-outside the clicked app takes
-- focus by itself, and we must not fight that.
local function restoreFocus()
  local front = hs.application.frontmostApplication()
  if previousApp and front and front:bundleID() == hs.processInfo.bundleID then
    previousApp:activate()
  end
  previousApp = nil
end

local function showWindow()
  local frame = hs.screen.mainScreen():frame()
  local w = 600
  local h = math.floor(frame.h * 0.72)
  local rect = hs.geometry.rect(
    frame.x + math.floor((frame.w - w) / 2),
    frame.y + math.floor((frame.h - h) / 3), -- slightly above centre
    w,
    h
  )

  webview = hs.webview.new(rect)
  -- The webview window refuses key status unless told otherwise
  -- (HSWebViewWindow.canBecomeKeyWindow returns allowTextEntry, default NO),
  -- and without key status Esc and focusChange dismissal can't work.
  webview:allowTextEntry(true)
  webview:windowStyle({ "titled", "closable", "utility", "resizable" })
  webview:windowTitle("Markdown Cheatsheet - ESC to close")
  webview:level(hs.drawing.windowLevels.floating)
  webview:closeOnEscape(true)
  webview:deleteOnClose(true) -- Esc/close button must destroy the webview, not just hide it
  webview:windowCallback(function(action, wv, state)
    if wv ~= webview then
      return -- already handled: the toggle-dismiss path nils the ref before deleting
    end
    if action == "focusChange" and not state then
      -- clicked outside the popup: dismiss
      webview = nil
      wv:delete()
      restoreFocus()
    elseif action == "closing" then
      webview = nil
      restoreFocus()
    end
  end)
  webview:html(cachedHtml)
  webview:show()
  webview:bringToFront(true)

  -- Take keyboard focus: without it the window is never key, so Esc
  -- (closeOnEscape) goes to some other app and focusChange never fires.
  previousApp = hs.application.frontmostApplication()
  local win = webview:hswindow()
  if win then
    win:focus()
  else
    hs.application.get(hs.processInfo.bundleID):activate(true)
  end
end

-- Render cheatsheet.md with pandoc into the HTML cache. If showWhenRendered
-- is set (someone pressed the hotkey while a render was in flight), show the
-- popup when this render lands.
local function render(mtime)
  rendering = true
  hs.task.new(pandocPath, function(code, out, err)
    rendering = false
    if code == 0 then
      cachedHtml = page(out)
      cachedMtime = mtime
    else
      cachedHtml = page(
        "<h1>Cheatsheet render failed</h1><pre>" .. hs.http.escapeHtml(err) .. "</pre>"
      )
      cachedMtime = nil
    end
    if showWhenRendered then
      showWhenRendered = false
      if not webview then
        showWindow()
      end
    end
  end, { "-f", "markdown+smart", "-t", "html5", mdPath }):start()
end

local function toggle()
  if webview then
    local wv = webview
    webview = nil -- nil first, so the delete's own callbacks don't double-dismiss
    wv:delete()
    restoreFocus()
    return
  end

  if rendering then
    -- A render is already in flight (e.g. the warm-up render); show the
    -- popup as soon as it lands instead of ignoring the keypress.
    showWhenRendered = true
    return
  end

  local attr = hs.fs.attributes(mdPath)
  local mtime = attr and attr.modification or 0
  if cachedHtml and cachedMtime == mtime then
    showWindow()
    return
  end

  showWhenRendered = true
  render(mtime)
end

function M.start()
  hs.hotkey.bind({ "ctrl", "alt" }, "M", toggle)

  -- Warm the HTML cache so the first toggle is as instant as later ones.
  local attr = hs.fs.attributes(mdPath)
  render(attr and attr.modification or 0)

  -- Warm the WebKit pipeline: the first WKWebView in a process has to spawn
  -- WebKit's content/GPU helper processes. A 1x1 invisible window forces the
  -- spawn at load, and the hswindow() call pre-pays the one-time
  -- accessibility-subsystem init (over a second) so the first toggle doesn't.
  local ghost = hs.webview.new(hs.geometry.rect(0, 0, 1, 1))
  ghost:alpha(0)
  ghost:html("<html><body></body></html>")
  ghost:show()
  ghost:hswindow()
  warmupTimer = hs.timer.doAfter(1, function()
    ghost:delete()
    warmupTimer = nil
  end)
end

-- exposed so the popup can also be toggled programmatically
-- (e.g. from an Alfred workflow or the Hammerspoon console)
M.toggle = toggle

return M
