_G["log"] = dofile(hs.spoons.resourcePath("lib/log.lua")) "Visor.spoon"
local mtUtils = dofile(hs.spoons.resourcePath("lib/mt.lua"))
local inspect = hs.inspect

log.lineinfo = false
log.usecolor = false
log.datefmt = false
_G["log"] = log.hs_install()
log.setLogLevel(hs.logger.defaultLogLevel)

local filter_logger = dofile(hs.spoons.resourcePath("lib/log.lua")) "VisorWindowFilter"
filter_logger.lineinfo = false
filter_logger.usecolor = false
filter_logger.datefmt = false
filter_logger.level = 'debug'

---A Hammerspoon Spoon for providing a visor or "quake"/"guake"/"yakuake" style
---drop-down terminal for Kitty, similar to iTerm2's Hotkey Window profile.
---@class Visor
local M = {
  name = "Visor",
  version = "1.0",
  author = "Doug Stephen <dljs.jr@dougstephenjr.com>",
  license = "MIT - https://opensource.org/licenses/MIT"
}

local defaultOpts = {
  opacity = 1.0,
  height = 0.4
}

defaultOpts.__index = defaultOpts

local supportedDisplayValues = {
  primary = true,
  active = true
}

---@enum Visor.DisplayOptions
M.DisplayOptions = {
  PrimaryDisplay = "primary",
  ActiveDisplay = "active"
}
M.DisplayOptions = mtUtils.makeReadOnlyTable(M.DisplayOptions) --[[@as Visor.DisplayOptions]]

local function _get_display(self)
  if self.display == M.DisplayOptions.PrimaryDisplay then
    return hs.screen.primaryScreen()
  end
  return hs.screen.mainScreen()
end

---@alias action `toggleTerminal`
---@alias modifiers string[]
---@alias key string
---@alias keybind {[1]: modifiers, [2]: key, message: string?}

-------------------- BEGIN Hammerspoon API Impl ------------------------------

---Hammerspoon Init lifecycle function.
---Initializes defaults for fields.
---@return Visor
function M:init()
  log.v("Init from Visor.spoon!")
  self.display = M.DisplayOptions.ActiveDisplay
  return self
end

---Hammerspoon API; set up hotkeys for the spoon's actions.
---
---Supported Actions
---  - `toggleTerminal`: Show or hide the drop-down terminal
---@param mapping table<action, keybind>
---@return Visor self returns self on method call
function M:bindHotKeys(mapping)
  log.v("Binding hotkey mapping" .. inspect(mapping))
  local spec = {
    toggleTerminal = hs.fnutils.partial(self.toggleTerminal, self),
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

---Start the `Visor` Spoon.
---Should be called *after* binding hotkeys and configuring the spoon to know which
---terminal application to manage, either by using the generic `configure` calls
---**or** one of the App-specific calls.
---
---@see Visor.bindHotKeys
---@see Visor.configure
---@see Visor.configureForKitty
---@return Visor? self returns self on method call
function M:start()
  log.v("Start called")
  if self.terminal == nil then
    log.e("Start called without a configured terminal")
    return nil
  end
  if type(self.terminal.init) == "function" then
    self.terminal:init()
  end
  local appName = string.match(self.terminal.macApp, "(.+)%.app")
  self.windowFilter = hs.window.filter.new({ [appName] = { allowTitles = self.terminal.windowIdentifier } })
  self.windowFilter.log = filter_logger.hs_install()
  self.windowFilter.log.setLogLevel(log.getLogLevel())
  self.windowFilter = self.windowFilter:subscribe(
    {
      [hs.window.filter.windowUnfocused] = function(window, app_name, event)
        log.v("Window unfocused callback")
        if window then
          self.terminal:hideVisorWindow(window)
        end
      end
    }
  )
  log.v("Initialized window filter " .. inspect(self.windowFilter, { depth = 1 }))
  local _termApp, visorWindow = self.terminal:getTerminalAppAndVisor()
  if visorWindow then
    log.v("Visor window already existed at Spoon start")
  end
  return self
end

-------------------- END Hammerspoon API Impl --------------------------------

-------------------- BEGIN Visor API Impl ------------------------------------

---Configure which diplay the terminal window will become visible on when the
---toggle action is called and it causes the window to become visible.
---@see Visor.DisplayOptions
---@param showOnDisplayOption Visor.DisplayOptions whether to show on the configured primary display, or the display containing the currently focused window.
function M:showOnDisplayBehavior(showOnDisplayOption)
  if not supportedDisplayValues[showOnDisplayOption] then
    log.w("Display Behavior " .. inspect(showOnDisplayOption) .. " isn't supported")
    return
  end
  self.display = showOnDisplayOption
end

---Declarative configuration for creating a Visor window out of a Terminal app.
---This is not currently well documented as the API is not stable, but reverse engineering
---what's going on shouldn't be too bad. The primary use-case right now is to be called by
---`Visor.configureForKitty`
---@see Visor.configureForKitty
---@param term table Declarative description of the terminal app and how to manipulate it to make a Visor window
---@param opts table key-value options/parameters that can be set by the user. While there's no good API for it now, these aren't the same as the declarative terminal templates as they could be tweaked at any time and are often general amongst terminal apps.
---@return Visor self returns self on method call
function M:configure(term, opts)
  log.v("Configuring Visor.spoon with terminal template:" .. inspect(term))
  assert(type(term) == "table", "Argument `term` to Visor:setTerminalApp must be a table")
  term.opts = setmetatable(opts, defaultOpts)
  self.terminal = mtUtils.makeTerminal(term)
  return self
end

---Calls `Visor:configure` with a `term` argument configured for the Kitty terminal app and the provided `opts` table.
---@see Visor.configure
---@param opts table user configured options
---@return Visor self returns self on method call
function M:configureForKitty(opts)
  log.i("Configuring Visor.spoon for Kitty integration")
  local kitty = dofile(hs.spoons.resourcePath("kitty/init.lua"))
  local windowIdentifier = "KITTY_HOTKEY_WINDOW"
  local profilePath = hs.spoons.resourcePath("kitty/visor_window.conf")
  opts = opts or {}
  opts.kitten = opts.kitten or "/Applications/kitty.app/Contents/MacOS/kitten"

  local kittyTemplate = kitty.fromTemplate {
    macApp = "kitty.app",
    bundleId = "net.kovidgoyal.kitty",
    windowIdentifier = windowIdentifier,
    executableName = "kitty",
    profilePath = profilePath,
    launchCmdLine = {
      executable = "kitty",
      nohup = true,
      background = true,
      args = {
        "-d",
        "$HOME",
        "-1",
        "--instance-group",
        windowIdentifier,
        "-T",
        windowIdentifier,
        "--listen-on",
        "unix:" .. kitty.socket,
        "-c",
        profilePath,
        "false"
      }
    }
  }
  return self:configure(kittyTemplate, opts)
end

---Primary `action` for the Spoon. Hides or reveals the terminal window.
function M:toggleTerminal()
  log.v("Toggle terminal called")
  if type(self.terminal) ~= "table" then
    log.e("Terminal toggle binding triggered with no terminal configured")
    return
  end

  local termApp, visorWindow = self.terminal:getTerminalAppAndVisor()
  local display = _get_display(self)
  if termApp == nil or termApp:bundleID() ~= self.terminal.bundleId then
    log.v("termApp" ..
      self.terminal.macApp .. "for bundleId" .. self.terminal.bundleId .. " not running, starting visor window")
    self.terminal:startVisorWindow(display):focus()
    return
  end
  if visorWindow == nil then
    log.v("Visor window with identifier " .. self.terminal.windowIdentifier .. " not open, creating visor window")
    self.terminal:startVisorWindow(display):focus()
    return
  end
  if visorWindow:isVisible() then
    if not visorWindow:application():isFrontmost() then
      log.v("Visor window visible but not focused, focusing")
      visorWindow:focus()
    else
      log.v("Hiding visor window")
      self.terminal:hideVisorWindow(visorWindow)
    end
  else
    log.v("Showing visor window")
    self.terminal:showVisorWindow(visorWindow, display)
  end
end

return M
