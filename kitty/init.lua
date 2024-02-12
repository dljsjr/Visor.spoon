local kittyVisorDir = hs.spoons.scriptPath()

local kitty = {
  socket = kittyVisorDir .. "socket",
  daemon_stdout = kittyVisorDir .. "kitty_daemon.out",
  daemon_stderr = kittyVisorDir .. "kitty_daemon.err",
}

local function _cleanup_logs()
  local ret_code, delete_err = os.remove(kitty.daemon_stdout)
  if not ret_code then
    log.w("Couldn't clean up daemon output logs, reason: " .. tostring(delete_err))
  end
  ret_code, delete_err = os.remove(kitty.daemon_stderr)
  if not ret_code then
    log.w("Couldn't clean up daemon error logs, reason: " .. tostring(delete_err))
  end
end

local function _get_daemon_pid(self)
  -- We don't error on status here because an error
  -- indicates a failure to lookup the PID which is part of
  -- what we're trying to figure out (does the PID exist)
  local pid, status = hs.execute(string.format([[pgrep -f -n %s 2>&1]], self.windowIdentifier))
  log.df("status: %s, pid: %s", tostring(status), tostring(pid))
  return (status and pid) or nil
end

local function _getVisorWindow(self, kitty_pid)
  local visorWindow = nil
  local pid = kitty_pid or _get_daemon_pid(self)
  local termApp = (pid and hs.application.applicationForPID(tonumber(pid))) or nil
  if termApp then
    log.df("Term app found: %s", hs.inspect(termApp))
    visorWindow = termApp and termApp:getWindow(self.windowIdentifier)
    if visorWindow then
      log.d("Found visor window. App name:" .. tostring(termApp:name()) .. ", bundleId: " .. tostring(termApp:bundleID()))
    end
  else
    log.w("No Kitty app instance while trying to find existing visor window.")
  end
  return visorWindow
end

local function _kitty_ls(self)
  return hs.execute(string.format([[%s @ --to unix:%s ls 2>&1]], self.opts.kitten, self.socket))
end

local function _spawn_kitty_daemon_cmd(self)
  local kittyCmd = self.launchCmdLine.executable
  for _, v in ipairs(self.launchCmdLine.args) do
    kittyCmd = kittyCmd .. " " .. tostring(v)
  end
  return string.format(
    "%s%s%s%s",
    (self.launchCmdLine.background and string.format("1>%s 2>%s ", kitty.daemon_stdout, kitty.daemon_stderr)) or "",
    (self.launchCmdLine.nohup and "nohup ") or "",
    kittyCmd,
    (self.launchCmdLine.background and " &") or ""
  )
end

local function _create_visor_window_cmd(self)
  return string.format(
    [[%s @ --to unix:%s launch --no-response 2>&1]],
    self.opts.kitten,
    self.socket,
    self.windowIdentifier,
    self.daemon_stdout,
    self.daemon_stderr
  )
end

local function _cleanup_socket(self)
  local test, err, code = os.rename(self.socket, self.socket)
  if not test then
    if code ~= 13 then
      return true
    else
      return test, err, code
    end
  end
  log.d("Cleaning up stale Unix sockets")
  return os.remove(self.socket)
end

local function _get_opacity(self)
  local pid = _get_daemon_pid(self)
  if not pid then
    _cleanup_socket(self)
    return
  end

  local visorWindow = _getVisorWindow(self)
  if not visorWindow then
    return
  end

  local kitty_json, status, err_type, ret_code = _kitty_ls(self)
  if not status then
    log.ef("Error querying kitty window details: %s %s %s ", err_type, ret_code, kitty_json)
    return nil
  end

  return hs.json.decode(kitty_json)[1].background_opacity
end

local function _set_opacity(self, desired_opacity)
  local kittenCmd = string.format(
    "%s @ --to unix:%s set-background-opacity --all %s 2>&1",
    self.opts.kitten,
    self.socket,
    desired_opacity
  )
  local out, success, exit_type, ret_code = hs.execute(kittenCmd)
  if not success then
    log.w(string.format(
      [[
      Problem setting opacity using kitten: %s %s
      output: %s
    ]], exit_type, ret_code, out
    ))
  else
    kitty.currentOpacity = desired_opacity
  end
end

local function _launch_visor_window(self)
  local out, status, err_type, ret_code = hs.execute(_create_visor_window_cmd(self))
  if not status then
    log.wf("Error creating visor window: %s %s %s", err_type, ret_code, out)
  end
end

local function _do_spawn(self)
  local pid = _get_daemon_pid(self)
  local kittyCmd = (pid and _create_visor_window_cmd(self)) or (_cleanup_socket(self) and _spawn_kitty_daemon_cmd(self))
  if not kittyCmd then
    log.ef("Couldn't construct kitty start command from %s", hs.inspect(self.launchCmdLine))
    return nil
  end
  if pid then
    log.d("Creating Visor window for kitty daemon")
  else
    log.d("Spawning kitty daemon")
  end
  -- If we background the terminal this should always be true so we're
  -- going to need an additional check to make sure the command spawned
  -- correctly later.
  log.df("Executing kitty cmd %q", kittyCmd)
  local status, err_type, ret_code = os.execute(kittyCmd)
  if not status then
    log.ef("Error creating visor window: %s %s", err_type, ret_code)
  end

  if pid then return pid end

  -- Did a fresh spawn, so update the PID. We need to check this again
  -- before we try to poll for a window.
  pid = _get_daemon_pid(self)
  if not pid then
    -- files used by background spawn command
    local stdout, out_open_err = io.open(kitty.daemon_stdout, "r")
    local stderr, err_open_err = io.open(kitty.daemon_stderr, "r")

    if stdout then stdout:flush() end
    if stderr then stderr:flush() end

    local output_string = stdout and stdout:read("*a") or
      ("Error opening file: " .. tostring(out_open_err or "Unknown Error"))
    local err_string = stderr and stderr:read("*a") or
      ("Error opening file: " .. tostring(err_open_err or "Unknown Error"))

    log.ef(
      [[
      Could not locate PID of Kitty daemon; checking output files.
      stdout: %s
      stderr: %s
    ]], output_string, err_string)

    if stdout then stdout:close() end
    if stderr then stderr:close() end
  end

  return pid
end

function kitty:startVisorWindow(display)
  local visorWindow = nil
  local pid = _do_spawn(self)

  if not pid then
    log.e("Couldn't start Kitty daemon, can't start and show Visor window.")
    return
  end

  repeat
    log.df("Passing PID to visor window: %s", pid)
    visorWindow = _getVisorWindow(self, pid)
    if not visorWindow then _launch_visor_window(self) end
  until visorWindow ~= nil

  local screenFrame = display:fullFrame()
  local currentSize = visorWindow:size()
  visorWindow:setFrame({ x = screenFrame.x, y = screenFrame.y, w = currentSize.w, h = currentSize.h }, 0)

  kitty.currentOpacity = _get_opacity(self)

  local appPID = pid or (visorWindow and visorWindow:application():pid()) or nil
  if not appPID then
    error("Failed to get kitty app PID for attaching watcher")
  end
  hs.application.watcher.new(function(app_name, event_type, app)
    if app:pid() == appPID and event_type == hs.application.watcher.terminated then
      _cleanup_socket(self)
    end
  end)

  return self:showVisorWindow(visorWindow, display)
end

function kitty:isShowing(visorWindow)
  local win = visorWindow or _getVisorWindow(self)
  return win and win:isVisible() and win:frame().h > 1
end

function kitty:hideVisorWindow(visorWindow, display)
  local focusTarget = hs.window.orderedWindows()[1] or hs.window.desktop()
  local screenFrame = display:fullFrame()
  -- First we shrink the window verticall as much as the app and the OS
  -- will allow. This is also the part that's animated.
  visorWindow:setFrame(
    hs.geometry {
      x = screenFrame.x,
      y = screenFrame.y,
      w = screenFrame.w,
      h = 0
    },
    self.opts.animationDuration
  )
  -- I don't completely understand the `...WithWorkarounds` function's explanation,
  -- but I do know that using it lets us create a window with an "illegal" size and position.
  -- So we use this to move the window offscreen and make it tiny.
  hs.timer.doAfter(self.opts.animationDuration, function()
    visorWindow:setFrameWithWorkarounds(
      hs.geometry {
        x = screenFrame.x,
        y = screenFrame.y - 24,
        w = screenFrame.w,
        h = -1
      },
      0
    )
    focusTarget:focus()
  end)
  return visorWindow
end

function kitty:showVisorWindow(visorWindow, display)
  local focusedWindow = hs.window.focusedWindow()
  local screenFrame
  if focusedWindow and focusedWindow:isFullScreen() then
    screenFrame = display:fullFrame()
  else
    screenFrame = display:frame()
  end
  visorWindow:move(
    hs.geometry {
      x = screenFrame.x,
      y = screenFrame.y,
      w = screenFrame.w,
      h = screenFrame.h *
        self.opts.height
    },
    self.opts.animationDuration
  )
  if self.opts.opacity ~= self.currentOpacity then
    _set_opacity(self, self.opts.opacity)
  end
  visorWindow:focus()
  return visorWindow
end

function kitty:getTerminalAppAndVisor(maybeVisorWindow)
  local visorWindow = maybeVisorWindow or _getVisorWindow(self)
  local termApp = (visorWindow and visorWindow:application())
  return termApp, visorWindow
end

function kitty:init(display)
  _cleanup_logs()
  local args = self.launchCmdLine.args
  local width = display:fullFrame().w
  -- we use these "-o" overrides no matter what other args are in the
  -- command line table. This is so that we can exert some control over
  -- the terminal startup flicker.
  self.launchCmdLine.args = {
    "-o",
    "background_opacity=0",
    "-o",
    "initial_window_height=1",
    "-o",
    string.format("initial_window_width=%s", math.floor(width)),
    table.unpack(args)
  }
  local pid = _get_daemon_pid(self)
  log.df("PID in kitty:init(): %s", tostring(pid))
  if not pid then
    _do_spawn(self)
    return
  end

  local visorWindow = _getVisorWindow(self)
  if not visorWindow then
    return
  end

  _set_opacity(self, self.opts.opacity)
end

kitty.__index = kitty

function kitty.fromTemplate(template)
  return setmetatable(template, kitty)
end

return kitty
