local kittyDir = hs.spoons.scriptPath()

local kitty = {
  socket = kittyDir .. "socket",
}

local function _getVisorWindow(self)
  local visorWindow = nil
  for _, termApp in pairs(hs.application.applicationsForBundleID(self.bundleId)) do
    visorWindow = termApp and termApp:getWindow(self.windowIdentifier)
    if visorWindow then
      log.v("Found visor window. App name:" .. termApp:name() .. ", bundleId: " .. termApp:bundleID())
      break
    end
  end

  return visorWindow
end

local function _spawn_kitty_daemon_cmd(self)
  local kittyCmd = ((self.launchCmdLine.nohup and "nohup ") or "") .. self.launchCmdLine.executable
  for _, v in ipairs(self.launchCmdLine.args) do
    kittyCmd = kittyCmd .. " " .. tostring(v)
  end
  if self.launchCmdLine.background then
    kittyCmd = kittyCmd .. " &"
  end

  return kittyCmd
end

local function _create_visor_window_cmd(self)
  return string.format([[%s @ --to unix:%s launch --dont-take-focus]], self.opts.kitten, self.socket)
end

local function _cleanup_socket(self)
  log.v("Cleaning up stale Unix sockets")
  local cleanupSocket = string.format(
    [[rm -rf %s 2>&1]],
    self.socket
  )
  local out, success, exit_type, ret_code = hs.execute(cleanupSocket)
  if not success then
    log.w(string.format(
      [[
            Problem cleaning up old Unix socket: %s %s
            output: %s
          ]], exit_type, ret_code, out
    ))
  end
end

function kitty:startVisorWindow(display)
  local pid, status = hs.execute(string.format([[pgrep -f %s 2>&1]], self.windowIdentifier))
  pid = (status and pid) or nil
  local kittyCmd = (pid and _create_visor_window_cmd(self)) or _spawn_kitty_daemon_cmd(self)
  if not pid then
    _cleanup_socket(self)
  end
  log.v("Starting kitty window with command" .. kittyCmd)
  os.execute(kittyCmd)
  local visorWindow = nil
  repeat
    visorWindow = _getVisorWindow(self)
  until visorWindow ~= nil

  local appPID = pid or visorWindow:application():pid()
  hs.application.watcher.new(function(app_name, event_type, app)
    if app:pid() == appPID and event_type == hs.application.watcher.terminated then
      _cleanup_socket(self)
    end
  end)

  return self:showVisorWindow(visorWindow, display)
end

function kitty:hideVisorWindow(visorWindow)
  visorWindow:application():hide()
  return visorWindow
end

function kitty:showVisorWindow(visorWindow, display)
  if self.opts.opacity ~= self.currentOpacity then
    local kittenCmd = string.format(
      "%s @ --to unix:%s set-background-opacity --all %s 2>&1",
      self.opts.kitten,
      self.socket,
      self.opts.opacity
    )
    log.v("Setting opacity with: " .. kittenCmd)
    local out, success, exit_type, ret_code = hs.execute(kittenCmd)
    if not success then
      log.w(string.format(
        [[
        Problem setting opacity using kitten: %s %s
        output: %s
      ]], exit_type, ret_code, out
      ))
    else
      kitty.currentOpacity = self.opts.opacity
    end
  end
  local screenFrame = display:fullFrame()
  local windowFrame = visorWindow:frame()
  windowFrame.w = screenFrame.w
  windowFrame.h = screenFrame.h * self.opts.height
  windowFrame.y = screenFrame.y
  windowFrame.x = screenFrame.x
  visorWindow:setFrame(windowFrame, 0)
  visorWindow:move(hs.geometry({ x = 0, y = 0 }))
  visorWindow:unminimize()
  visorWindow:application():unhide()
  visorWindow:focus()
  return visorWindow
end

function kitty:getTerminalAppAndVisor(maybeVisorWindow)
  local visorWindow = maybeVisorWindow or _getVisorWindow(self)
  local termApp = (visorWindow and visorWindow:application())
  return termApp, visorWindow
end

kitty.__index = kitty

function kitty.fromTemplate(template)
  return setmetatable(template, kitty)
end

return kitty
